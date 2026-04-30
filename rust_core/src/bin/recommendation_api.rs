use axum::{
    extract::{Query, State},
    http::StatusCode,
    response::{IntoResponse, Response},
    routing::{get, post},
    Json, Router,
};
use reqwest::Client;
use serde::{Deserialize, Serialize};
use serde_json::{json, Value};
use std::{net::SocketAddr, sync::Arc};
use stroll_core::{
    models::{
        Activity, ActivityCategory, AgentResponse, FeedResponse, FilterOption, GeoLocation,
        Location, NetworkResponse, VoiceQuery,
    },
    StrollCore, StrollError,
};
use tower_http::cors::{Any, CorsLayer};
use tower_http::services::{ServeDir, ServeFile};

#[derive(Debug, Deserialize)]
struct RecommendationRequest {
    query: String,
    lat: Option<f64>,
    lng: Option<f64>,
    provider: Option<String>,
}

#[derive(Debug, Deserialize)]
struct TrendingQuery {
    category: Option<String>,
}

#[derive(Debug, Deserialize)]
struct SaveActivityRequest {
    activity_id: String,
}

#[derive(Debug, Deserialize)]
struct FollowUserRequest {
    user_id: String,
}

#[derive(Debug, Serialize)]
struct ApiErrorPayload {
    code: String,
    message: String,
}

#[derive(Debug)]
struct ApiError {
    status: StatusCode,
    payload: ApiErrorPayload,
}

impl ApiError {
    fn bad_request(message: impl Into<String>) -> Self {
        Self {
            status: StatusCode::BAD_REQUEST,
            payload: ApiErrorPayload {
                code: "INVALID_REQUEST".to_string(),
                message: message.into(),
            },
        }
    }

    fn provider_error(message: impl Into<String>) -> Self {
        Self {
            status: StatusCode::BAD_REQUEST,
            payload: ApiErrorPayload {
                code: "PROVIDER_ERROR".to_string(),
                message: message.into(),
            },
        }
    }

    fn upstream_error(message: impl Into<String>) -> Self {
        Self {
            status: StatusCode::BAD_GATEWAY,
            payload: ApiErrorPayload {
                code: "UPSTREAM_ERROR".to_string(),
                message: message.into(),
            },
        }
    }
}

impl From<StrollError> for ApiError {
    fn from(error: StrollError) -> Self {
        Self {
            status: StatusCode::INTERNAL_SERVER_ERROR,
            payload: ApiErrorPayload {
                code: error.code,
                message: error.message,
            },
        }
    }
}

impl IntoResponse for ApiError {
    fn into_response(self) -> Response {
        (self.status, Json(self.payload)).into_response()
    }
}

#[derive(Debug, Clone, Copy, PartialEq, Eq)]
enum ProviderKind {
    Local,
    OpenRouter,
    HuggingFace,
    Gemini,
}

impl ProviderKind {
    fn parse(raw: &str) -> Option<Self> {
        match raw.trim().to_lowercase().as_str() {
            "local" => Some(Self::Local),
            "openrouter" => Some(Self::OpenRouter),
            "huggingface" => Some(Self::HuggingFace),
            "gemini" => Some(Self::Gemini),
            _ => None,
        }
    }
}

#[derive(Debug, Clone)]
struct OpenRouterConfig {
    api_key: String,
    model: String,
}

#[derive(Debug, Clone)]
struct HuggingFaceConfig {
    api_key: String,
    model: String,
    endpoint: Option<String>,
}

#[derive(Debug, Clone)]
struct GeminiConfig {
    api_key: String,
    model: String,
    endpoint: Option<String>,
}

#[derive(Clone)]
struct AppState {
    core: Arc<StrollCore>,
    http_client: Client,
    default_provider: ProviderKind,
    openrouter: Option<OpenRouterConfig>,
    huggingface: Option<HuggingFaceConfig>,
    gemini: Option<GeminiConfig>,
    google_places_api_key: Option<String>,
    openweathermap_api_key: Option<String>,
    fixture_activities: Arc<Vec<Activity>>,
}

#[tokio::main]
async fn main() -> Result<(), Box<dyn std::error::Error>> {
    // Load .env file (silently skip if not found)
    let _ = dotenvy::dotenv();

    let port = std::env::var("PORT")
        .or_else(|_| std::env::var("PULSE_API_PORT"))
        .or_else(|_| std::env::var("STROLL_API_PORT"))
        .ok()
        .and_then(|raw| raw.parse::<u16>().ok())
        .unwrap_or(8787);
    let db_path = std::env::var("PULSE_DB_PATH")
        .or_else(|_| std::env::var("STROLL_DB_PATH"))
        .unwrap_or_else(|_| "pulse_v1.sqlite".to_string());

    let core = if db_path.trim().is_empty() {
        StrollCore::new()
    } else {
        StrollCore::new_with_db_path(db_path)
    };
    core.init_with_mock_data_async().await?;

    let fixture_activities = Arc::new(load_fixture_activities());
    println!(
        "[FIXTURE] Loaded {} cached NYC venues from seed file",
        fixture_activities.len()
    );

    let state = AppState {
        core: Arc::new(core),
        http_client: Client::new(),
        default_provider: default_provider_from_env(),
        openrouter: load_openrouter_config(),
        huggingface: load_huggingface_config(),
        gemini: load_gemini_config(),
        google_places_api_key: std::env::var("GOOGLE_PLACES_API_KEY").ok(),
        openweathermap_api_key: std::env::var("OPENWEATHER_API_KEY").ok(),
        fixture_activities,
    };

    let app = app_router(state);
    let cors = CorsLayer::new()
        .allow_origin(Any)
        .allow_methods(Any)
        .allow_headers(Any);
    let app = app.layer(cors);
    let address = SocketAddr::from(([0, 0, 0, 0], port));
    let listener = tokio::net::TcpListener::bind(address).await?;

    println!("PULSE API listening on http://{address}");
    axum::serve(listener, app).await?;

    Ok(())
}

fn app_router(state: AppState) -> Router {
    Router::new()
        .route("/health", get(health))
        .route("/api/health", get(health))
        .route("/api/recommend", post(recommend))
        .route("/api/feed", get(feed_handler))
        .route("/api/network", get(network_handler))
        .route("/api/trending", get(trending_handler))
        .route("/api/activities/saved", get(saved_activities_handler))
        .route("/api/activities/save", post(save_activity_handler))
        .route("/api/users/follow", post(follow_user_handler))
        .route("/api/places/search", post(places_search_handler))
        .with_state(state)
        .fallback_service(
            ServeDir::new("static").not_found_service(ServeFile::new("static/index.html")),
        )
}

async fn health() -> &'static str {
    "ok"
}

async fn recommend(
    State(state): State<AppState>,
    Json(request): Json<RecommendationRequest>,
) -> Result<Json<AgentResponse>, ApiError> {
    if request.query.trim().is_empty() {
        return Err(ApiError::bad_request("query is required"));
    }

    let location = parse_location(&request)?;
    let provider = resolve_provider(request.provider.as_deref(), state.default_provider)?;
    let provider_was_explicit = request.provider.is_some();

    // Try fetching LIVE places from Google Places API first
    let live_activities = if let (Some(loc), Some(api_key)) =
        (&location, &state.google_places_api_key)
    {
        match fetch_google_places(&state.http_client, api_key, loc, &request.query).await {
            Ok(places) if !places.is_empty() => {
                println!(
                    "[PLACES] Fetched {} live venues from Google Places API",
                    places.len()
                );
                Some(places)
            }
            Ok(_) => {
                eprintln!("[PLACES] Google Places returned 0 results, falling back to local data");
                None
            }
            Err(e) => {
                eprintln!(
                    "[PLACES] Google Places API error: {}, falling back to local data",
                    e.payload.message
                );
                None
            }
        }
    } else {
        None
    };

    // Build the response: live Places > fixture cache > legacy 4-venue mock
    let mut response = if let Some(activities) = live_activities {
        let filters = activities
            .iter()
            .map(|a| a.category.to_string())
            .collect::<std::collections::HashSet<_>>()
            .into_iter()
            .map(|cat| FilterOption {
                id: format!("filter-{}", cat),
                label: cat.clone(),
                icon: None,
                category: Some(guess_category(&cat)),
            })
            .collect::<Vec<_>>();

        AgentResponse {
            summary: format!(
                "Found {} places near you matching '{}'",
                activities.len(),
                request.query
            ),
            activities,
            filters,
            query: VoiceQuery {
                text: request.query.clone(),
                location: location.clone(),
                timestamp: chrono::Utc::now().to_rfc3339(),
            },
        }
    } else if !state.fixture_activities.is_empty() {
        let activities = search_fixture(&state.fixture_activities, &request.query);
        let filters = activities
            .iter()
            .map(|a| a.category.to_string())
            .collect::<std::collections::HashSet<_>>()
            .into_iter()
            .map(|cat| FilterOption {
                id: format!("filter-{}", cat),
                label: cat.clone(),
                icon: None,
                category: Some(guess_category(&cat)),
            })
            .collect::<Vec<_>>();
        println!(
            "[FIXTURE] Serving {} venues from fixture for '{}'",
            activities.len(),
            request.query
        );
        AgentResponse {
            summary: format!(
                "Found {} places near you matching '{}'",
                activities.len(),
                request.query
            ),
            activities,
            filters,
            query: VoiceQuery {
                text: request.query.clone(),
                location: location.clone(),
                timestamp: chrono::Utc::now().to_rfc3339(),
            },
        }
    } else {
        state
            .core
            .process_voice_query(request.query.clone(), location.clone(), None)
            .await
            .map_err(ApiError::from)?
    };

    // Enhance the summary with LLM if configured
    match maybe_enhance_summary(
        &state,
        provider,
        location,
        &request.query,
        &response.activities,
    )
    .await
    {
        Ok(Some(summary)) => {
            response.summary = summary;
        }
        Ok(None) => {}
        Err(error) => {
            if provider_was_explicit {
                return Err(error);
            }
            eprintln!(
                "Provider fallback to local summary: {} ({})",
                error.payload.code, error.payload.message
            );
        }
    }

    Ok(Json(response))
}

#[derive(Debug, Deserialize)]
struct FeedQuery {
    lat: Option<f64>,
    lng: Option<f64>,
    q: Option<String>,
}

async fn feed_handler(
    State(state): State<AppState>,
    Query(params): Query<FeedQuery>,
) -> Result<Json<FeedResponse>, ApiError> {
    // If location provided and we have a Places API key, fetch live venues
    let live_recs = match (params.lat, params.lng, &state.google_places_api_key) {
        (Some(lat), Some(lng), Some(api_key)) => {
            let loc = GeoLocation { lat, lng };
            let query = params
                .q
                .as_deref()
                .unwrap_or("popular restaurants bars cafes things to do");
            match fetch_google_places(&state.http_client, api_key, &loc, query).await {
                Ok(places) if !places.is_empty() => {
                    println!(
                        "[FEED] Fetched {} live venues from Google Places",
                        places.len()
                    );
                    Some(places)
                }
                Ok(_) => {
                    eprintln!("[FEED] Google Places returned 0 results for feed");
                    None
                }
                Err(e) => {
                    eprintln!("[FEED] Google Places error for feed: {}", e.payload.message);
                    None
                }
            }
        }
        _ => None,
    };

    if let Some(recs) = live_recs {
        // Return live data with empty posts (no social data from Google Places)
        let trending: Vec<String> = recs
            .iter()
            .flat_map(|a| a.tags.iter().take(1).cloned())
            .take(5)
            .map(|t| format!("#{}", t))
            .collect();

        Ok(Json(FeedResponse {
            recommendations: recs,
            posts: vec![],
            trending_tags: trending,
        }))
    } else {
        // Fixture fallback > legacy mock
        if !state.fixture_activities.is_empty() {
            let recs = search_fixture(
                &state.fixture_activities,
                params.q.as_deref().unwrap_or("popular things to do"),
            );
            let trending: Vec<String> = recs
                .iter()
                .flat_map(|a| a.tags.iter().take(1).cloned())
                .take(5)
                .map(|t| format!("#{}", t))
                .collect();
            return Ok(Json(FeedResponse {
                recommendations: recs,
                posts: vec![],
                trending_tags: trending,
            }));
        }
        let response = state
            .core
            .get_personalized_feed()
            .await
            .map_err(ApiError::from)?;
        Ok(Json(response))
    }
}

async fn network_handler(State(state): State<AppState>) -> Result<Json<NetworkResponse>, ApiError> {
    let response = state.core.get_network().await.map_err(ApiError::from)?;
    Ok(Json(response))
}

async fn trending_handler(
    State(state): State<AppState>,
    Query(query): Query<TrendingQuery>,
) -> Result<Json<Vec<Activity>>, ApiError> {
    let response = state
        .core
        .get_trending(query.category)
        .await
        .map_err(ApiError::from)?;
    Ok(Json(response))
}

async fn saved_activities_handler(
    State(state): State<AppState>,
) -> Result<Json<Vec<Activity>>, ApiError> {
    let response = state
        .core
        .get_saved_activities()
        .await
        .map_err(ApiError::from)?;
    Ok(Json(response))
}

async fn save_activity_handler(
    State(state): State<AppState>,
    Json(request): Json<SaveActivityRequest>,
) -> Result<Response, ApiError> {
    if request.activity_id.trim().is_empty() {
        return Err(ApiError::bad_request("activity_id is required"));
    }
    state
        .core
        .save_activity(request.activity_id)
        .await
        .map_err(ApiError::from)?;
    Ok((StatusCode::OK, Json(json!({"ok": true}))).into_response())
}

async fn follow_user_handler(
    State(state): State<AppState>,
    Json(request): Json<FollowUserRequest>,
) -> Result<Response, ApiError> {
    if request.user_id.trim().is_empty() {
        return Err(ApiError::bad_request("user_id is required"));
    }
    state
        .core
        .follow_user(request.user_id)
        .await
        .map_err(ApiError::from)?;
    Ok((StatusCode::OK, Json(json!({"ok": true}))).into_response())
}

// ── Google Places API (Nearby Search v1) ─────────────────────────────

#[derive(Debug, Deserialize)]
#[serde(rename_all = "camelCase")]
struct PlacesSearchQuery {
    query: String,
    lat: f64,
    lng: f64,
}

async fn places_search_handler(
    State(state): State<AppState>,
    Json(request): Json<PlacesSearchQuery>,
) -> Result<Json<Vec<Activity>>, ApiError> {
    let api_key = state.google_places_api_key.as_ref().ok_or_else(|| {
        ApiError::provider_error("Google Places API key not configured. Set GOOGLE_PLACES_API_KEY.")
    })?;
    let loc = GeoLocation {
        lat: request.lat,
        lng: request.lng,
    };
    let activities = fetch_google_places(&state.http_client, api_key, &loc, &request.query).await?;
    Ok(Json(activities))
}

/// Haversine formula: returns distance in miles between two lat/lng points
fn haversine_miles(lat1: f64, lng1: f64, lat2: f64, lng2: f64) -> f64 {
    let r = 3958.8; // Earth radius in miles
    let d_lat = (lat2 - lat1).to_radians();
    let d_lng = (lng2 - lng1).to_radians();
    let a = (d_lat / 2.0).sin().powi(2)
        + lat1.to_radians().cos() * lat2.to_radians().cos() * (d_lng / 2.0).sin().powi(2);
    let c = 2.0 * a.sqrt().asin();
    r * c
}

async fn fetch_google_places(
    client: &Client,
    api_key: &str,
    location: &GeoLocation,
    text_query: &str,
) -> Result<Vec<Activity>, ApiError> {
    // Use the Google Places Text Search (New) API
    let url = "https://places.googleapis.com/v1/places:searchText";

    let body = json!({
        "textQuery": text_query,
        "locationBias": {
            "circle": {
                "center": {
                    "latitude": location.lat,
                    "longitude": location.lng
                },
                "radius": 5000.0
            }
        },
        "maxResultCount": 10,
        "languageCode": "en"
    });

    let response = client
        .post(url)
        .header("Content-Type", "application/json")
        .header("X-Goog-Api-Key", api_key)
        .header(
            "X-Goog-FieldMask",
            "places.id,places.displayName,places.formattedAddress,places.location,places.rating,places.userRatingCount,places.priceLevel,places.types,places.photos,places.currentOpeningHours,places.nationalPhoneNumber,places.websiteUri,places.editorialSummary",
        )
        .json(&body)
        .send()
        .await
        .map_err(|e| ApiError::upstream_error(format!("Google Places request failed: {e}")))?;

    let status = response.status();
    let response_body = response.text().await.map_err(|e| {
        ApiError::upstream_error(format!("Google Places response read failed: {e}"))
    })?;

    if !status.is_success() {
        return Err(ApiError::upstream_error(format!(
            "Google Places returned {status}: {response_body}"
        )));
    }

    let parsed: Value = serde_json::from_str(&response_body)
        .map_err(|e| ApiError::upstream_error(format!("Google Places JSON invalid: {e}")))?;

    let places = parsed["places"].as_array().cloned().unwrap_or_default();

    let activities: Vec<Activity> = places
        .iter()
        .enumerate()
        .map(|(idx, place)| {
            let name = place["displayName"]["text"]
                .as_str()
                .unwrap_or("Unknown Venue")
                .to_string();
            let address = place["formattedAddress"]
                .as_str()
                .unwrap_or("")
                .to_string();
            let lat = place["location"]["latitude"].as_f64().unwrap_or(location.lat);
            let lng = place["location"]["longitude"].as_f64().unwrap_or(location.lng);
            let rating = place["rating"].as_f64().unwrap_or(0.0) as f32;
            let review_count = place["userRatingCount"].as_i64().unwrap_or(0) as i32;

            let price_level = match place["priceLevel"].as_str() {
                Some("PRICE_LEVEL_FREE") => 0,
                Some("PRICE_LEVEL_INEXPENSIVE") => 1,
                Some("PRICE_LEVEL_MODERATE") => 2,
                Some("PRICE_LEVEL_EXPENSIVE") => 3,
                Some("PRICE_LEVEL_VERY_EXPENSIVE") => 4,
                _ => 2,
            };

            let types: Vec<String> = place["types"]
                .as_array()
                .map(|arr| {
                    arr.iter()
                        .filter_map(|v| v.as_str().map(String::from))
                        .collect()
                })
                .unwrap_or_default();

            let category = guess_category_from_types(&types);

            let description = place["editorialSummary"]["text"]
                .as_str()
                .unwrap_or(&format!("A {} venue located at {}", category, address))
                .to_string();

            let open_hours = place["currentOpeningHours"]["weekdayDescriptions"]
                .as_array()
                .and_then(|arr| arr.first())
                .and_then(|v| v.as_str())
                .unwrap_or("Hours not available")
                .to_string();

            let place_id = place["id"].as_str().unwrap_or("").to_string();

            // Calculate distance from user to venue (Haversine)
            let dist_miles = haversine_miles(location.lat, location.lng, lat, lng);
            let distance_str = if dist_miles < 0.1 {
                "Nearby".to_string()
            } else if dist_miles < 10.0 {
                format!("{:.1} mi", dist_miles)
            } else {
                format!("{:.0} mi", dist_miles)
            };

            // Extract photo reference for the image URL
            let images: Vec<String> = place["photos"]
                .as_array()
                .map(|photos| {
                    photos
                        .iter()
                        .take(3)
                        .filter_map(|photo| {
                            photo["name"].as_str().map(|photo_name| {
                                format!(
                                    "https://places.googleapis.com/v1/{}/media?maxHeightPx=800&maxWidthPx=800&key={}",
                                    photo_name, api_key
                                )
                            })
                        })
                        .collect()
                })
                .unwrap_or_default();

            Activity {
                id: if place_id.is_empty() { format!("gp-{}", idx) } else { place_id },
                name,
                description,
                category,
                subcategories: vec![],
                location: Location {
                    lat,
                    lng,
                    address: address.clone(),
                    neighborhood: String::new(),
                    city: address
                        .split(',')
                        .next_back()
                        .unwrap_or("")
                        .trim()
                        .to_string(),
                },
                rating,
                review_count,
                price_level,
                images,
                open_hours,
                phone: place["nationalPhoneNumber"].as_str().map(String::from),
                website: place["websiteUri"].as_str().map(String::from),
                tags: types.into_iter().take(5).collect(),
                distance: Some(distance_str),
                is_open: place["currentOpeningHours"]["openNow"].as_bool().unwrap_or(true),
                ai_summary: None,
                why_recommended: Some(format!("Live result from Google Places for '{}'", text_query)),
            }
        })
        .collect();

    Ok(activities)
}

fn guess_category_from_types(types: &[String]) -> ActivityCategory {
    for t in types {
        let lower = t.to_lowercase();
        if lower.contains("restaurant")
            || lower.contains("food")
            || lower.contains("cafe")
            || lower.contains("bakery")
            || lower.contains("coffee")
        {
            return ActivityCategory::Food;
        }
        if lower.contains("bar") || lower.contains("night_club") || lower.contains("nightlife") {
            return ActivityCategory::Nightlife;
        }
        if lower.contains("gym")
            || lower.contains("spa")
            || lower.contains("wellness")
            || lower.contains("yoga")
        {
            return ActivityCategory::Wellness;
        }
        if lower.contains("museum")
            || lower.contains("art")
            || lower.contains("theater")
            || lower.contains("library")
        {
            return ActivityCategory::Culture;
        }
        if lower.contains("park") || lower.contains("garden") || lower.contains("nature") {
            return ActivityCategory::Nature;
        }
        if lower.contains("store") || lower.contains("shop") || lower.contains("mall") {
            return ActivityCategory::Shopping;
        }
        if lower.contains("amusement")
            || lower.contains("bowling")
            || lower.contains("cinema")
            || lower.contains("entertainment")
        {
            return ActivityCategory::Fun;
        }
    }
    ActivityCategory::Fun
}

fn guess_category(label: &str) -> ActivityCategory {
    match label.to_lowercase().as_str() {
        "food" => ActivityCategory::Food,
        "nightlife" => ActivityCategory::Nightlife,
        "wellness" => ActivityCategory::Wellness,
        "culture" => ActivityCategory::Culture,
        "nature" => ActivityCategory::Nature,
        "shopping" => ActivityCategory::Shopping,
        _ => ActivityCategory::Fun,
    }
}

fn parse_location(request: &RecommendationRequest) -> Result<Option<GeoLocation>, ApiError> {
    match (request.lat, request.lng) {
        (Some(lat), Some(lng)) => Ok(Some(GeoLocation { lat, lng })),
        (None, None) => Ok(None),
        _ => Err(ApiError::bad_request(
            "lat and lng must both be provided when location is set",
        )),
    }
}

fn resolve_provider(
    request_provider: Option<&str>,
    default_provider: ProviderKind,
) -> Result<ProviderKind, ApiError> {
    if let Some(raw) = request_provider {
        return ProviderKind::parse(raw).ok_or_else(|| {
            ApiError::bad_request("provider must be one of: local, openrouter, huggingface, gemini")
        });
    }

    Ok(default_provider)
}

async fn maybe_enhance_summary(
    state: &AppState,
    provider: ProviderKind,
    location: Option<GeoLocation>,
    query: &str,
    activities: &[Activity],
) -> Result<Option<String>, ApiError> {
    let mut context_str = String::new();
    if let (Some(loc), Some(key)) = (&location, &state.openweathermap_api_key) {
        let url = format!(
            "https://api.openweathermap.org/data/2.5/weather?lat={}&lon={}&appid={}&units=metric",
            loc.lat, loc.lng, key
        );
        if let Ok(resp) = state.http_client.get(&url).send().await {
            if let Ok(json) = resp.json::<Value>().await {
                if let (Some(temp), Some(desc)) = (
                    json["main"]["temp"].as_f64(),
                    json["weather"][0]["description"].as_str(),
                ) {
                    context_str = format!("Weather at location: {}, {}°C.", desc, temp);
                }
            }
        }
    }

    match provider {
        ProviderKind::Local => Ok(None),
        ProviderKind::OpenRouter => {
            let config = state.openrouter.as_ref().ok_or_else(|| {
                ApiError::provider_error("OpenRouter is not configured. Set OPENROUTER_API_KEY.")
            })?;

            let summary = generate_openrouter_summary(
                &state.http_client,
                config,
                query,
                activities,
                &context_str,
            )
            .await?;
            Ok(Some(summary))
        }
        ProviderKind::HuggingFace => {
            let config = state.huggingface.as_ref().ok_or_else(|| {
                ApiError::provider_error("HuggingFace is not configured. Set HUGGINGFACE_API_KEY.")
            })?;

            let summary = generate_huggingface_summary(
                &state.http_client,
                config,
                query,
                activities,
                &context_str,
            )
            .await?;
            Ok(Some(summary))
        }
        ProviderKind::Gemini => {
            let config = state.gemini.as_ref().ok_or_else(|| {
                ApiError::provider_error("Gemini is not configured. Set GEMINI_API_KEY.")
            })?;

            let summary = generate_gemini_summary(
                &state.http_client,
                config,
                query,
                activities,
                &context_str,
            )
            .await?;
            Ok(Some(summary))
        }
    }
}

async fn generate_openrouter_summary(
    client: &Client,
    config: &OpenRouterConfig,
    query: &str,
    activities: &[Activity],
    context: &str,
) -> Result<String, ApiError> {
    let prompt = build_summary_prompt(query, activities, context);
    let response = client
        .post("https://openrouter.ai/api/v1/chat/completions")
        .bearer_auth(&config.api_key)
        .header("HTTP-Referer", "https://stroll.local")
        .header("X-Title", "STROLL Local Test")
        .json(&json!({
            "model": config.model,
            "messages": [
                {
                    "role": "system",
                    "content": "You summarize recommendations in 2 short sentences with practical tone."
                },
                {
                    "role": "user",
                    "content": prompt
                }
            ],
            "temperature": 0.3,
            "max_tokens": 120
        }))
        .send()
        .await
        .map_err(|error| {
            ApiError::upstream_error(format!("OpenRouter request failed: {error}"))
        })?;

    let status = response.status();
    let body = response.text().await.map_err(|error| {
        ApiError::upstream_error(format!("OpenRouter response read failed: {error}"))
    })?;

    if !status.is_success() {
        return Err(ApiError::upstream_error(format!(
            "OpenRouter returned {status}: {body}"
        )));
    }

    let parsed: Value = serde_json::from_str(&body).map_err(|error| {
        ApiError::upstream_error(format!("OpenRouter response JSON invalid: {error}"))
    })?;

    let summary = parsed
        .get("choices")
        .and_then(Value::as_array)
        .and_then(|choices| choices.first())
        .and_then(|choice| choice.get("message"))
        .and_then(|message| message.get("content"))
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .ok_or_else(|| ApiError::upstream_error("OpenRouter response missing content"))?;

    Ok(summary.to_string())
}

async fn generate_huggingface_summary(
    client: &Client,
    config: &HuggingFaceConfig,
    query: &str,
    activities: &[Activity],
    context: &str,
) -> Result<String, ApiError> {
    let prompt = build_summary_prompt(query, activities, context);
    let endpoint = config.endpoint.clone().unwrap_or_else(|| {
        format!(
            "https://api-inference.huggingface.co/models/{}",
            config.model
        )
    });

    let response = client
        .post(endpoint)
        .bearer_auth(&config.api_key)
        .json(&json!({
            "inputs": prompt,
            "parameters": {
                "max_new_tokens": 120,
                "temperature": 0.3,
                "return_full_text": false
            }
        }))
        .send()
        .await
        .map_err(|error| {
            ApiError::upstream_error(format!("HuggingFace request failed: {error}"))
        })?;

    let status = response.status();
    let body = response.text().await.map_err(|error| {
        ApiError::upstream_error(format!("HuggingFace response read failed: {error}"))
    })?;

    if !status.is_success() {
        return Err(ApiError::upstream_error(format!(
            "HuggingFace returned {status}: {body}"
        )));
    }

    let parsed: Value = serde_json::from_str(&body).map_err(|error| {
        ApiError::upstream_error(format!("HuggingFace response JSON invalid: {error}"))
    })?;

    let summary = extract_huggingface_text(&parsed)
        .ok_or_else(|| ApiError::upstream_error("HuggingFace response missing generated_text"))?;

    Ok(summary)
}

fn extract_huggingface_text(value: &Value) -> Option<String> {
    if let Some(text) = value
        .as_array()
        .and_then(|items| items.first())
        .and_then(|item| item.get("generated_text"))
        .and_then(Value::as_str)
    {
        let trimmed = text.trim();
        if !trimmed.is_empty() {
            return Some(trimmed.to_string());
        }
    }

    if let Some(text) = value
        .get("generated_text")
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|text| !text.is_empty())
    {
        return Some(text.to_string());
    }

    None
}

async fn generate_gemini_summary(
    client: &Client,
    config: &GeminiConfig,
    query: &str,
    activities: &[Activity],
    context: &str,
) -> Result<String, ApiError> {
    let prompt = build_summary_prompt(query, activities, context);
    let endpoint = config.endpoint.clone().unwrap_or_else(|| {
        format!(
            "https://generativelanguage.googleapis.com/v1beta/models/{}:generateContent",
            config.model
        )
    });

    let response = client
        .post(endpoint)
        .query(&[("key", config.api_key.as_str())])
        .json(&json!({
            "system_instruction": {
                "parts": [
                    {
                        "text": "You summarize recommendations in 2 short sentences with practical tone."
                    }
                ]
            },
            "contents": [
                {
                    "parts": [
                        {
                            "text": prompt
                        }
                    ]
                }
            ],
            "generationConfig": {
                "temperature": 0.3,
                "maxOutputTokens": 120
            }
        }))
        .send()
        .await
        .map_err(|error| ApiError::upstream_error(format!("Gemini request failed: {error}")))?;

    let status = response.status();
    let body = response.text().await.map_err(|error| {
        ApiError::upstream_error(format!("Gemini response read failed: {error}"))
    })?;

    if !status.is_success() {
        return Err(ApiError::upstream_error(format!(
            "Gemini returned {status}: {body}"
        )));
    }

    let parsed: Value = serde_json::from_str(&body).map_err(|error| {
        ApiError::upstream_error(format!("Gemini response JSON invalid: {error}"))
    })?;

    let summary = parsed
        .get("candidates")
        .and_then(Value::as_array)
        .and_then(|candidates| candidates.first())
        .and_then(|candidate| candidate.get("content"))
        .and_then(|content| content.get("parts"))
        .and_then(Value::as_array)
        .and_then(|parts| parts.first())
        .and_then(|part| part.get("text"))
        .and_then(Value::as_str)
        .map(str::trim)
        .filter(|value| !value.is_empty())
        .ok_or_else(|| ApiError::upstream_error("Gemini response missing text"))?;

    Ok(summary.to_string())
}

fn build_summary_prompt(query: &str, activities: &[Activity], context: &str) -> String {
    let activity_lines = activities
        .iter()
        .take(5)
        .enumerate()
        .map(|(index, activity)| {
            format!("{}. {} ({})", index + 1, activity.name, activity.category)
        })
        .collect::<Vec<_>>()
        .join("\n");

    let context_prefix = if context.is_empty() {
        "".to_string()
    } else {
        format!("Current Context: {}\n", context)
    };

    format!(
        "{}User query: {query}\nTop activities:\n{activity_lines}\nWrite a concise recommendation summary.", 
        context_prefix
    )
}

// ── Fixture / seed data ───────────────────────────────────────────────────────

fn load_fixture_activities() -> Vec<Activity> {
    // Search order: next to binary, then relative to cwd (dev), then sibling dirs
    let candidates = [
        std::path::PathBuf::from("data/nyc_seed.json"),
        std::path::PathBuf::from("rust_core/data/nyc_seed.json"),
        std::path::PathBuf::from("../rust_core/data/nyc_seed.json"),
    ];
    for path in &candidates {
        if path.exists() {
            match std::fs::read_to_string(path) {
                Ok(text) => match serde_json::from_str::<Vec<Activity>>(&text) {
                    Ok(acts) => {
                        println!("[FIXTURE] Loaded {} venues from {}", acts.len(), path.display());
                        return acts;
                    }
                    Err(e) => {
                        eprintln!("[FIXTURE] Parse error in {}: {}", path.display(), e);
                    }
                },
                Err(e) => {
                    eprintln!("[FIXTURE] Read error for {}: {}", path.display(), e);
                }
            }
        }
    }
    eprintln!("[FIXTURE] data/nyc_seed.json not found — using legacy 4-venue mock");
    vec![]
}

fn search_fixture(activities: &[Activity], query: &str) -> Vec<Activity> {
    let q = query.to_lowercase();

    let category_keywords: &[(&str, ActivityCategory)] = &[
        ("restaurant", ActivityCategory::Food),
        ("dinner", ActivityCategory::Food),
        ("lunch", ActivityCategory::Food),
        ("brunch", ActivityCategory::Food),
        ("breakfast", ActivityCategory::Food),
        ("tapas", ActivityCategory::Food),
        ("italian", ActivityCategory::Food),
        ("japanese", ActivityCategory::Food),
        ("ramen", ActivityCategory::Food),
        ("coffee", ActivityCategory::Food),
        ("cafe", ActivityCategory::Food),
        ("bakery", ActivityCategory::Food),
        ("french", ActivityCategory::Food),
        ("hidden gem", ActivityCategory::Food),
        ("food", ActivityCategory::Food),
        ("eat", ActivityCategory::Food),
        ("rooftop bar", ActivityCategory::Nightlife),
        ("nightlife", ActivityCategory::Nightlife),
        ("late night", ActivityCategory::Nightlife),
        ("cocktail", ActivityCategory::Nightlife),
        ("craft beer", ActivityCategory::Nightlife),
        ("pub", ActivityCategory::Nightlife),
        ("bar", ActivityCategory::Nightlife),
        ("yoga", ActivityCategory::Wellness),
        ("wellness", ActivityCategory::Wellness),
        ("spa", ActivityCategory::Wellness),
        ("gym", ActivityCategory::Wellness),
        ("fitness", ActivityCategory::Wellness),
        ("meditation", ActivityCategory::Wellness),
        ("museum", ActivityCategory::Culture),
        ("art", ActivityCategory::Culture),
        ("gallery", ActivityCategory::Culture),
        ("culture", ActivityCategory::Culture),
        ("exhibition", ActivityCategory::Culture),
        ("park", ActivityCategory::Nature),
        ("nature", ActivityCategory::Nature),
        ("garden", ActivityCategory::Nature),
        ("outdoor", ActivityCategory::Nature),
        ("trail", ActivityCategory::Nature),
        ("riverside", ActivityCategory::Nature),
        ("vintage", ActivityCategory::Shopping),
        ("bookshop", ActivityCategory::Shopping),
        ("market", ActivityCategory::Shopping),
        ("boutique", ActivityCategory::Shopping),
        ("shopping", ActivityCategory::Shopping),
        ("store", ActivityCategory::Shopping),
        ("design store", ActivityCategory::Shopping),
        ("escape room", ActivityCategory::Fun),
        ("climbing", ActivityCategory::Fun),
        ("game", ActivityCategory::Fun),
        ("entertainment", ActivityCategory::Fun),
        ("fun", ActivityCategory::Fun),
        ("something fun", ActivityCategory::Fun),
    ];

    // Longest matching keyword wins (most specific intent)
    let target_cat: Option<ActivityCategory> = category_keywords
        .iter()
        .filter(|(kw, _)| q.contains(*kw))
        .max_by_key(|(kw, _)| kw.len())
        .map(|(_, cat)| cat.clone());

    let mut scored: Vec<(f32, Activity)> = activities
        .iter()
        .filter_map(|a| {
            let mut score = 0.0f32;

            if let Some(ref cat) = target_cat {
                if &a.category == cat {
                    score += 3.0;
                }
            }

            for tag in &a.tags {
                let tag_lower = tag.replace('_', " ").to_lowercase();
                for word in q.split_whitespace() {
                    if word.len() > 3 && (tag_lower.contains(word) || word.contains(tag_lower.as_str())) {
                        score += 0.5;
                    }
                }
            }

            let name_lower = a.name.to_lowercase();
            for word in q.split_whitespace() {
                if word.len() > 3 && name_lower.contains(word) {
                    score += 0.3;
                }
            }

            if score > 0.0 {
                Some((score * a.rating, a.clone()))
            } else {
                None
            }
        })
        .collect();

    // If no keyword match, return top-rated overall
    if scored.is_empty() {
        scored = activities
            .iter()
            .map(|a| (a.rating, a.clone()))
            .collect();
    }

    scored.sort_by(|a, b| b.0.partial_cmp(&a.0).unwrap_or(std::cmp::Ordering::Equal));
    scored.into_iter().take(10).map(|(_, a)| a).collect()
}

fn default_provider_from_env() -> ProviderKind {
    std::env::var("PULSE_AGENT_PROVIDER")
        .or_else(|_| std::env::var("STROLL_AGENT_PROVIDER"))
        .ok()
        .as_deref()
        .and_then(ProviderKind::parse)
        .unwrap_or(ProviderKind::Local)
}

fn load_openrouter_config() -> Option<OpenRouterConfig> {
    let api_key = std::env::var("OPENROUTER_API_KEY").ok()?;
    let model = std::env::var("OPENROUTER_MODEL")
        .ok()
        .filter(|value| !value.trim().is_empty())
        .unwrap_or_else(|| "liquid/lfm-2.5-1.2b-instruct:free".to_string());

    Some(OpenRouterConfig { api_key, model })
}

fn load_huggingface_config() -> Option<HuggingFaceConfig> {
    let api_key = std::env::var("HUGGINGFACE_API_KEY").ok()?;
    let model = std::env::var("HUGGINGFACE_MODEL")
        .ok()
        .filter(|value| !value.trim().is_empty())
        .unwrap_or_else(|| "mistralai/Mistral-7B-Instruct-v0.2".to_string());
    let endpoint = std::env::var("HUGGINGFACE_ENDPOINT")
        .ok()
        .filter(|value| !value.trim().is_empty());

    Some(HuggingFaceConfig {
        api_key,
        model,
        endpoint,
    })
}

fn load_gemini_config() -> Option<GeminiConfig> {
    let api_key = std::env::var("GEMINI_API_KEY").ok()?;
    let model = std::env::var("GEMINI_MODEL")
        .ok()
        .filter(|value| !value.trim().is_empty())
        .unwrap_or_else(|| "gemini-2.0-flash".to_string());
    let endpoint = std::env::var("GEMINI_ENDPOINT")
        .ok()
        .filter(|value| !value.trim().is_empty());

    Some(GeminiConfig {
        api_key,
        model,
        endpoint,
    })
}
