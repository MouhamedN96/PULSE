use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};
use std::ffi::{CStr, CString};
use std::future::Future;
use std::os::raw::c_char;
use std::ptr;
use std::sync::Arc;
use tokio::sync::RwLock;

pub mod agent;
pub mod models;
pub mod recommendations;
pub mod social;
pub mod sqlite_store;

use models::*;
use recommendations::RecommendationEngine;
use social::SocialGraph;
use sqlite_store::SqliteStore;

/// Core STROLL engine that powers the app
pub struct StrollCore {
    recommendation_engine: Arc<RwLock<RecommendationEngine>>,
    social_graph: Arc<RwLock<SocialGraph>>,
    current_user: Arc<RwLock<Option<User>>>,
    sqlite_store: Option<Arc<SqliteStore>>,
}

impl StrollCore {
    #[frb(sync)]
    pub fn new() -> Self {
        Self::with_store(None)
    }

    #[frb(sync)]
    pub fn new_with_db_path(db_path: String) -> Self {
        Self::with_store(Some(Arc::new(SqliteStore::new(db_path))))
    }

    fn with_store(sqlite_store: Option<Arc<SqliteStore>>) -> Self {
        Self {
            recommendation_engine: Arc::new(RwLock::new(RecommendationEngine::new())),
            social_graph: Arc::new(RwLock::new(SocialGraph::new())),
            current_user: Arc::new(RwLock::new(None)),
            sqlite_store,
        }
    }

    /// Initialize with mock data for demo
    #[frb(sync)]
    pub fn init_with_mock_data(&self) -> Result<(), StrollError> {
        block_on_sync(self.init_with_mock_data_async())?
    }

    pub async fn init_with_mock_data_async(&self) -> Result<(), StrollError> {
        if let Some(store) = self.sqlite_store.clone() {
            let state = tokio::task::spawn_blocking(move || {
                store.init_schema()?;
                store.seed_if_empty()?;
                store.load_state()
            })
            .await
            .map_err(db_task_error)??;

            let mut engine = self.recommendation_engine.write().await;
            engine
                .replace_state(state.activities, state.saved_activity_ids)
                .await;

            let mut social = self.social_graph.write().await;
            social
                .replace_state(
                    state.users,
                    state.posts,
                    state.requests,
                    state.following_user_ids,
                )
                .await;

            let mut user = self.current_user.write().await;
            *user = Some(User::mock_current_user());

            return Ok(());
        }

        let mut engine = self.recommendation_engine.write().await;
        engine.replace_state(mock_activities(), Vec::new()).await;

        let mut social = self.social_graph.write().await;
        social
            .replace_state(
                mock_users(),
                mock_posts(),
                mock_network_requests(),
                Vec::new(),
            )
            .await;

        let mut user = self.current_user.write().await;
        *user = Some(User::mock_current_user());

        Ok(())
    }

    /// Process a voice query with optional image and location
    #[frb]
    pub async fn process_voice_query(
        &self,
        query: String,
        location: Option<GeoLocation>,
        _image_analysis: Option<String>,
    ) -> Result<AgentResponse, StrollError> {
        let engine = self.recommendation_engine.read().await;
        let user = self.current_user.read().await;

        let user_prefs = user
            .as_ref()
            .map(|u| u.preferences.clone())
            .unwrap_or_default();

        // Parse the query to extract intent and filters
        let intent = agent::parse_query_intent(&query);

        // Get activities based on location and filters
        let activities = engine
            .find_activities(
                location.as_ref(),
                &intent.categories,
                &intent.subcategories,
                10,
            )
            .await;

        // Generate AI summary
        let summary = agent::generate_summary(&query, &activities, &user_prefs);

        // Get relevant filters
        let filters = engine.get_available_filters(&activities).await;

        Ok(AgentResponse {
            summary,
            activities,
            filters,
            query: VoiceQuery {
                text: query,
                location,
                timestamp: chrono::Utc::now().to_rfc3339(),
            },
        })
    }

    /// Get personalized feed for current user
    #[frb]
    pub async fn get_personalized_feed(&self) -> Result<FeedResponse, StrollError> {
        let engine = self.recommendation_engine.read().await;
        let social = self.social_graph.read().await;
        let user = self.current_user.read().await;

        let user_prefs = user
            .as_ref()
            .map(|u| u.preferences.clone())
            .unwrap_or_default();

        // Get recommended activities
        let recommendations = engine
            .get_personalized_recommendations(&user_prefs, 8)
            .await;

        // Get network posts
        let posts = social.get_network_posts(10).await;

        Ok(FeedResponse {
            recommendations,
            posts,
            trending_tags: engine.get_trending_tags(),
        })
    }

    /// Get user's social network
    #[frb]
    pub async fn get_network(&self) -> Result<NetworkResponse, StrollError> {
        let social = self.social_graph.read().await;

        let following = social.get_following().await;
        let suggested = social.get_suggested_users(5).await;
        let requests = social.get_pending_requests().await;

        Ok(NetworkResponse {
            following,
            suggested,
            requests,
        })
    }

    /// Follow a user
    #[frb]
    pub async fn follow_user(&self, user_id: String) -> Result<(), StrollError> {
        {
            let mut social = self.social_graph.write().await;
            social.follow_user(user_id.clone()).await?;
        }

        if let Some(store) = self.sqlite_store.clone() {
            persist_follow(store, user_id).await?;
        }

        Ok(())
    }

    /// Get trending activities
    #[frb]
    pub async fn get_trending(
        &self,
        category: Option<String>,
    ) -> Result<Vec<Activity>, StrollError> {
        let engine = self.recommendation_engine.read().await;
        Ok(engine.get_trending(category.as_deref(), 8).await)
    }

    /// Save an activity
    #[frb]
    pub async fn save_activity(&self, activity_id: String) -> Result<(), StrollError> {
        {
            let mut engine = self.recommendation_engine.write().await;
            engine.save_activity(activity_id.clone()).await?;
        }

        if let Some(store) = self.sqlite_store.clone() {
            persist_saved_activity(store, activity_id).await?;
        }

        Ok(())
    }

    /// Get saved activities
    #[frb]
    pub async fn get_saved_activities(&self) -> Result<Vec<Activity>, StrollError> {
        let engine = self.recommendation_engine.read().await;
        Ok(engine.get_saved_activities().await)
    }
}

async fn persist_follow(store: Arc<SqliteStore>, user_id: String) -> Result<(), StrollError> {
    tokio::task::spawn_blocking(move || store.follow_user(&user_id))
        .await
        .map_err(db_task_error)?
}

async fn persist_saved_activity(
    store: Arc<SqliteStore>,
    activity_id: String,
) -> Result<(), StrollError> {
    tokio::task::spawn_blocking(move || store.save_activity(&activity_id))
        .await
        .map_err(db_task_error)?
}

fn db_task_error(error: tokio::task::JoinError) -> StrollError {
    StrollError {
        code: "DB_QUERY_ERROR".to_string(),
        message: format!("Database task failed: {error}"),
    }
}

// FFI bridge functions for Flutter Rust bridge.
#[frb]
pub fn create_stroll_core() -> StrollCore {
    StrollCore::new()
}

#[frb]
pub fn create_stroll_core_with_db_path(db_path: String) -> StrollCore {
    StrollCore::new_with_db_path(db_path)
}

#[frb]
pub fn init_mock_data(core: &StrollCore) -> Result<(), StrollError> {
    core.init_with_mock_data()
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct StrollError {
    pub code: String,
    pub message: String,
}

impl std::fmt::Display for StrollError {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        write!(f, "{}: {}", self.code, self.message)
    }
}

impl std::error::Error for StrollError {}

impl From<reqwest::Error> for StrollError {
    fn from(e: reqwest::Error) -> Self {
        Self {
            code: "NETWORK_ERROR".to_string(),
            message: e.to_string(),
        }
    }
}

impl From<serde_json::Error> for StrollError {
    fn from(e: serde_json::Error) -> Self {
        Self {
            code: "SERDE_ERROR".to_string(),
            message: e.to_string(),
        }
    }
}

#[derive(Debug, Serialize)]
struct FfiEnvelope<T: Serialize> {
    ok: bool,
    data: Option<T>,
    error: Option<StrollError>,
}

fn runtime_error(e: std::io::Error) -> StrollError {
    StrollError {
        code: "RUNTIME_ERROR".to_string(),
        message: e.to_string(),
    }
}

fn block_on_sync<T>(future: impl Future<Output = T>) -> Result<T, StrollError> {
    if tokio::runtime::Handle::try_current().is_ok() {
        return Err(StrollError {
            code: "RUNTIME_ERROR".to_string(),
            message: "init_with_mock_data() cannot run inside an async runtime".to_string(),
        });
    }

    let runtime = tokio::runtime::Runtime::new().map_err(runtime_error)?;
    Ok(runtime.block_on(future))
}

fn core_pointer_error() -> StrollError {
    StrollError {
        code: "NULL_CORE".to_string(),
        message: "Core pointer was null".to_string(),
    }
}

fn invalid_input_error(message: String) -> StrollError {
    StrollError {
        code: "INVALID_INPUT".to_string(),
        message,
    }
}

fn ffi_response<T: Serialize>(payload: FfiEnvelope<T>) -> *mut c_char {
    let json = match serde_json::to_string(&payload) {
        Ok(serialized) => serialized,
        Err(e) => format!(
            "{{\"ok\":false,\"data\":null,\"error\":{{\"code\":\"SERDE_ERROR\",\"message\":\"{}\"}}}}",
            e
        ),
    };

    match CString::new(json) {
        Ok(c_string) => c_string.into_raw(),
        Err(_) => CString::new(
            "{\"ok\":false,\"data\":null,\"error\":{\"code\":\"SERDE_ERROR\",\"message\":\"Failed to encode UTF-8 response\"}}",
        )
        .expect("hardcoded JSON does not include interior null bytes")
        .into_raw(),
    }
}

fn ffi_ok<T: Serialize>(data: T) -> *mut c_char {
    ffi_response(FfiEnvelope {
        ok: true,
        data: Some(data),
        error: None,
    })
}

fn ffi_ok_empty() -> *mut c_char {
    ffi_response(FfiEnvelope::<serde_json::Value> {
        ok: true,
        data: Some(serde_json::Value::Null),
        error: None,
    })
}

fn ffi_err(error: StrollError) -> *mut c_char {
    ffi_response(FfiEnvelope::<serde_json::Value> {
        ok: false,
        data: None,
        error: Some(error),
    })
}

fn read_required_string(input: *const c_char, field_name: &str) -> Result<String, StrollError> {
    if input.is_null() {
        return Err(invalid_input_error(format!(
            "{field_name} pointer was null"
        )));
    }

    let c_string = unsafe {
        // SAFETY: `input` is checked for null above and is expected to be valid, NUL-terminated C string.
        CStr::from_ptr(input)
    };

    let value = c_string
        .to_str()
        .map_err(|e| invalid_input_error(format!("Failed to read {field_name}: {e}")))?;

    Ok(value.to_string())
}

fn read_required_non_empty_string(
    input: *const c_char,
    field_name: &str,
) -> Result<String, StrollError> {
    let value = read_required_string(input, field_name)?;
    if value.trim().is_empty() {
        return Err(invalid_input_error(format!("{field_name} cannot be empty")));
    }

    Ok(value)
}

fn read_optional_string(input: *const c_char) -> Result<Option<String>, StrollError> {
    if input.is_null() {
        return Ok(None);
    }

    let c_string = unsafe {
        // SAFETY: `input` is checked for null above and is expected to be valid, NUL-terminated C string.
        CStr::from_ptr(input)
    };

    let value = c_string
        .to_str()
        .map_err(|e| invalid_input_error(format!("Failed to read optional string: {e}")))?;

    if value.trim().is_empty() {
        Ok(None)
    } else {
        Ok(Some(value.to_string()))
    }
}

fn read_optional_location(
    location_json: *const c_char,
) -> Result<Option<GeoLocation>, StrollError> {
    let location_raw = read_optional_string(location_json)?;
    let Some(raw_json) = location_raw else {
        return Ok(None);
    };

    let parsed = serde_json::from_str::<GeoLocation>(&raw_json)?;
    Ok(Some(parsed))
}

fn core_ref<'a>(core: *mut StrollCore) -> Result<&'a StrollCore, StrollError> {
    if core.is_null() {
        return Err(core_pointer_error());
    }

    let value = unsafe {
        // SAFETY: pointer ownership is controlled by `stroll_create_core`/`stroll_dispose_core`.
        &*core
    };
    Ok(value)
}

#[no_mangle]
pub extern "C" fn stroll_create_core() -> *mut StrollCore {
    Box::into_raw(Box::new(StrollCore::new()))
}

#[no_mangle]
pub extern "C" fn stroll_create_core_with_db_path(db_path: *const c_char) -> *mut StrollCore {
    let result = (|| -> Result<*mut StrollCore, StrollError> {
        let db_path = read_required_non_empty_string(db_path, "db_path")?;
        Ok(Box::into_raw(Box::new(StrollCore::new_with_db_path(
            db_path,
        ))))
    })();

    match result {
        Ok(core) => core,
        Err(_) => ptr::null_mut(),
    }
}

#[no_mangle]
#[allow(clippy::not_unsafe_ptr_arg_deref)]
pub extern "C" fn stroll_dispose_core(core: *mut StrollCore) {
    if core.is_null() {
        return;
    }

    unsafe {
        // SAFETY: pointer originated from `Box::into_raw` in `stroll_create_core`.
        drop(Box::from_raw(core));
    }
}

#[no_mangle]
pub extern "C" fn stroll_init_mock_data(core: *mut StrollCore) -> *mut c_char {
    match core_ref(core) {
        Ok(core) => match core.init_with_mock_data() {
            Ok(()) => ffi_ok_empty(),
            Err(error) => ffi_err(error),
        },
        Err(error) => ffi_err(error),
    }
}

#[no_mangle]
pub extern "C" fn stroll_process_voice_query(
    core: *mut StrollCore,
    query: *const c_char,
    location_json: *const c_char,
    image_analysis: *const c_char,
) -> *mut c_char {
    let result = (|| -> Result<AgentResponse, StrollError> {
        let core = core_ref(core)?;
        let query = read_required_string(query, "query")?;
        let location = read_optional_location(location_json)?;
        let image_analysis = read_optional_string(image_analysis)?;

        let runtime = tokio::runtime::Runtime::new().map_err(runtime_error)?;
        runtime.block_on(core.process_voice_query(query, location, image_analysis))
    })();

    match result {
        Ok(response) => ffi_ok(response),
        Err(error) => ffi_err(error),
    }
}

#[no_mangle]
pub extern "C" fn stroll_get_personalized_feed(core: *mut StrollCore) -> *mut c_char {
    let result = (|| -> Result<FeedResponse, StrollError> {
        let core = core_ref(core)?;
        let runtime = tokio::runtime::Runtime::new().map_err(runtime_error)?;
        runtime.block_on(core.get_personalized_feed())
    })();

    match result {
        Ok(response) => ffi_ok(response),
        Err(error) => ffi_err(error),
    }
}

#[no_mangle]
pub extern "C" fn stroll_get_network(core: *mut StrollCore) -> *mut c_char {
    let result = (|| -> Result<NetworkResponse, StrollError> {
        let core = core_ref(core)?;
        let runtime = tokio::runtime::Runtime::new().map_err(runtime_error)?;
        runtime.block_on(core.get_network())
    })();

    match result {
        Ok(response) => ffi_ok(response),
        Err(error) => ffi_err(error),
    }
}

#[no_mangle]
pub extern "C" fn stroll_follow_user(core: *mut StrollCore, user_id: *const c_char) -> *mut c_char {
    let result = (|| -> Result<(), StrollError> {
        let core = core_ref(core)?;
        let user_id = read_required_non_empty_string(user_id, "user_id")?;

        let runtime = tokio::runtime::Runtime::new().map_err(runtime_error)?;
        runtime.block_on(core.follow_user(user_id))
    })();

    match result {
        Ok(_) => ffi_ok_empty(),
        Err(error) => ffi_err(error),
    }
}

#[no_mangle]
pub extern "C" fn stroll_get_trending(
    core: *mut StrollCore,
    category: *const c_char,
) -> *mut c_char {
    let result = (|| -> Result<Vec<Activity>, StrollError> {
        let core = core_ref(core)?;
        let category = read_optional_string(category)?;

        let runtime = tokio::runtime::Runtime::new().map_err(runtime_error)?;
        runtime.block_on(core.get_trending(category))
    })();

    match result {
        Ok(response) => ffi_ok(response),
        Err(error) => ffi_err(error),
    }
}

#[no_mangle]
pub extern "C" fn stroll_save_activity(
    core: *mut StrollCore,
    activity_id: *const c_char,
) -> *mut c_char {
    let result = (|| -> Result<(), StrollError> {
        let core = core_ref(core)?;
        let activity_id = read_required_non_empty_string(activity_id, "activity_id")?;

        let runtime = tokio::runtime::Runtime::new().map_err(runtime_error)?;
        runtime.block_on(core.save_activity(activity_id))
    })();

    match result {
        Ok(_) => ffi_ok_empty(),
        Err(error) => ffi_err(error),
    }
}

#[no_mangle]
pub extern "C" fn stroll_get_saved_activities(core: *mut StrollCore) -> *mut c_char {
    let result = (|| -> Result<Vec<Activity>, StrollError> {
        let core = core_ref(core)?;
        let runtime = tokio::runtime::Runtime::new().map_err(runtime_error)?;
        runtime.block_on(core.get_saved_activities())
    })();

    match result {
        Ok(response) => ffi_ok(response),
        Err(error) => ffi_err(error),
    }
}

#[no_mangle]
#[allow(clippy::not_unsafe_ptr_arg_deref)]
pub extern "C" fn stroll_free_string(value: *mut c_char) {
    if value.is_null() {
        return;
    }

    unsafe {
        // SAFETY: this pointer must be returned by CString::into_raw in this crate.
        let _ = CString::from_raw(value);
    }
}
