use crate::models::{
    mock_activities, mock_network_requests, mock_posts, mock_users, Activity, NetworkRequest, Post,
    User,
};
use crate::StrollError;
use rusqlite::{params, Connection};
use serde::de::DeserializeOwned;
use std::fs;
use std::path::{Path, PathBuf};

#[derive(Debug, Clone)]
pub struct PersistedState {
    pub activities: Vec<Activity>,
    pub users: Vec<User>,
    pub posts: Vec<Post>,
    pub requests: Vec<NetworkRequest>,
    pub following_user_ids: Vec<String>,
    pub saved_activity_ids: Vec<String>,
}

#[derive(Debug, Clone)]
pub struct SqliteStore {
    db_path: PathBuf,
}

impl SqliteStore {
    pub fn new<P: Into<PathBuf>>(db_path: P) -> Self {
        Self {
            db_path: db_path.into(),
        }
    }

    pub fn db_path(&self) -> &Path {
        &self.db_path
    }

    pub fn init_schema(&self) -> Result<(), StrollError> {
        let conn = self.open_connection()?;
        conn.execute_batch(
            "
            PRAGMA user_version = 1;

            CREATE TABLE IF NOT EXISTS activities (
                id TEXT PRIMARY KEY,
                payload_json TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS users (
                id TEXT PRIMARY KEY,
                payload_json TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS posts (
                id TEXT PRIMARY KEY,
                payload_json TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS network_requests (
                id TEXT PRIMARY KEY,
                payload_json TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS following (
                user_id TEXT PRIMARY KEY,
                followed_at TEXT NOT NULL
            );

            CREATE TABLE IF NOT EXISTS saved_activities (
                activity_id TEXT PRIMARY KEY,
                saved_at TEXT NOT NULL
            );
            ",
        )
        .map_err(db_query_error)?;

        Ok(())
    }

    pub fn seed_if_empty(&self) -> Result<(), StrollError> {
        let mut conn = self.open_connection()?;
        let activities_count: i64 = conn
            .query_row("SELECT COUNT(1) FROM activities", [], |row| row.get(0))
            .map_err(db_query_error)?;

        if activities_count > 0 {
            return Ok(());
        }

        let transaction = conn.transaction().map_err(db_query_error)?;

        for activity in mock_activities() {
            let payload_json = serde_json::to_string(&activity).map_err(db_serialization_error)?;
            transaction
                .execute(
                    "INSERT OR IGNORE INTO activities(id, payload_json) VALUES (?1, ?2)",
                    params![activity.id, payload_json],
                )
                .map_err(db_query_error)?;
        }

        let followed_at = chrono::Utc::now().to_rfc3339();
        for user in mock_users() {
            let payload_json = serde_json::to_string(&user).map_err(db_serialization_error)?;
            let user_id = user.id.clone();
            let is_following = user.is_following == Some(true);

            transaction
                .execute(
                    "INSERT OR IGNORE INTO users(id, payload_json) VALUES (?1, ?2)",
                    params![user_id, payload_json],
                )
                .map_err(db_query_error)?;

            if is_following {
                transaction
                    .execute(
                        "INSERT OR IGNORE INTO following(user_id, followed_at) VALUES (?1, ?2)",
                        params![user.id, followed_at],
                    )
                    .map_err(db_query_error)?;
            }
        }

        for post in mock_posts() {
            let payload_json = serde_json::to_string(&post).map_err(db_serialization_error)?;
            transaction
                .execute(
                    "INSERT OR IGNORE INTO posts(id, payload_json) VALUES (?1, ?2)",
                    params![post.id, payload_json],
                )
                .map_err(db_query_error)?;
        }

        for request in mock_network_requests() {
            let payload_json = serde_json::to_string(&request).map_err(db_serialization_error)?;
            transaction
                .execute(
                    "INSERT OR IGNORE INTO network_requests(id, payload_json) VALUES (?1, ?2)",
                    params![request.id, payload_json],
                )
                .map_err(db_query_error)?;
        }

        transaction.commit().map_err(db_query_error)?;
        Ok(())
    }

    pub fn load_state(&self) -> Result<PersistedState, StrollError> {
        let conn = self.open_connection()?;
        let activities =
            load_payloads::<Activity>(&conn, "SELECT payload_json FROM activities ORDER BY rowid")?;
        let users = load_payloads::<User>(&conn, "SELECT payload_json FROM users ORDER BY rowid")?;
        let posts = load_payloads::<Post>(&conn, "SELECT payload_json FROM posts ORDER BY rowid")?;
        let requests = load_payloads::<NetworkRequest>(
            &conn,
            "SELECT payload_json FROM network_requests ORDER BY rowid",
        )?;

        let following_user_ids = load_ids(
            &conn,
            "SELECT user_id FROM following ORDER BY followed_at, rowid",
        )?;
        let saved_activity_ids = load_ids(
            &conn,
            "SELECT activity_id FROM saved_activities ORDER BY saved_at, rowid",
        )?;

        Ok(PersistedState {
            activities,
            users,
            posts,
            requests,
            following_user_ids,
            saved_activity_ids,
        })
    }

    pub fn save_activity(&self, activity_id: &str) -> Result<(), StrollError> {
        let conn = self.open_connection()?;
        conn.execute(
            "INSERT OR IGNORE INTO saved_activities(activity_id, saved_at) VALUES (?1, ?2)",
            params![activity_id, chrono::Utc::now().to_rfc3339()],
        )
        .map_err(db_query_error)?;
        Ok(())
    }

    pub fn follow_user(&self, user_id: &str) -> Result<(), StrollError> {
        let conn = self.open_connection()?;
        conn.execute(
            "INSERT OR IGNORE INTO following(user_id, followed_at) VALUES (?1, ?2)",
            params![user_id, chrono::Utc::now().to_rfc3339()],
        )
        .map_err(db_query_error)?;
        Ok(())
    }

    fn open_connection(&self) -> Result<Connection, StrollError> {
        if self.db_path.as_os_str().is_empty() {
            return Err(db_init_error("Database path cannot be empty"));
        }

        if let Some(parent) = self.db_path.parent() {
            if !parent.as_os_str().is_empty() {
                fs::create_dir_all(parent).map_err(db_init_error)?;
            }
        }

        Connection::open(&self.db_path).map_err(db_init_error)
    }
}

fn load_payloads<T: DeserializeOwned>(
    conn: &Connection,
    query: &str,
) -> Result<Vec<T>, StrollError> {
    let mut statement = conn.prepare(query).map_err(db_query_error)?;
    let rows = statement
        .query_map([], |row| row.get::<_, String>(0))
        .map_err(db_query_error)?;

    let mut values = Vec::new();
    for payload in rows {
        let payload = payload.map_err(db_query_error)?;
        let value = serde_json::from_str::<T>(&payload).map_err(db_serialization_error)?;
        values.push(value);
    }

    Ok(values)
}

fn load_ids(conn: &Connection, query: &str) -> Result<Vec<String>, StrollError> {
    let mut statement = conn.prepare(query).map_err(db_query_error)?;
    let rows = statement
        .query_map([], |row| row.get::<_, String>(0))
        .map_err(db_query_error)?;

    let mut values = Vec::new();
    for value in rows {
        values.push(value.map_err(db_query_error)?);
    }

    Ok(values)
}

fn db_init_error(error: impl ToString) -> StrollError {
    StrollError {
        code: "DB_INIT_ERROR".to_string(),
        message: error.to_string(),
    }
}

fn db_query_error(error: impl ToString) -> StrollError {
    StrollError {
        code: "DB_QUERY_ERROR".to_string(),
        message: error.to_string(),
    }
}

fn db_serialization_error(error: impl ToString) -> StrollError {
    StrollError {
        code: "DB_SERIALIZATION_ERROR".to_string(),
        message: error.to_string(),
    }
}
