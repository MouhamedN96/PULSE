use crate::models::*;
use std::collections::HashMap;
use std::future::Future;
use std::sync::Arc;
use tokio::sync::RwLock;

pub struct SocialGraph {
    users: Arc<RwLock<HashMap<String, User>>>,
    following: Arc<RwLock<Vec<String>>>,
    posts: Arc<RwLock<Vec<Post>>>,
    requests: Arc<RwLock<Vec<NetworkRequest>>>,
}

impl Default for SocialGraph {
    fn default() -> Self {
        Self::new()
    }
}

impl SocialGraph {
    pub fn new() -> Self {
        Self {
            users: Arc::new(RwLock::new(HashMap::new())),
            following: Arc::new(RwLock::new(Vec::new())),
            posts: Arc::new(RwLock::new(Vec::new())),
            requests: Arc::new(RwLock::new(Vec::new())),
        }
    }

    pub fn load_mock_users(&mut self) {
        block_on_future(self.replace_state(
            mock_users(),
            mock_posts(),
            mock_network_requests(),
            Vec::new(),
        ));
    }

    pub async fn replace_state(
        &mut self,
        users: Vec<User>,
        posts: Vec<Post>,
        requests: Vec<NetworkRequest>,
        following_ids: Vec<String>,
    ) {
        let mut map = HashMap::new();
        let mut merged_following = following_ids;

        for user in users {
            if user.is_following == Some(true) && !merged_following.contains(&user.id) {
                merged_following.push(user.id.clone());
            }
            map.insert(user.id.clone(), user);
        }

        let mut u = self.users.write().await;
        *u = map;

        let mut f = self.following.write().await;
        *f = merged_following;

        let mut p = self.posts.write().await;
        *p = posts;

        let mut r = self.requests.write().await;
        *r = requests;
    }

    pub async fn get_following(&self) -> Vec<User> {
        let users = self.users.read().await;
        let following = self.following.read().await;

        following
            .iter()
            .filter_map(|id| users.get(id).cloned())
            .collect()
    }

    pub async fn get_suggested_users(&self, limit: usize) -> Vec<User> {
        let users = self.users.read().await;
        let following = self.following.read().await;

        users
            .values()
            .filter(|u| !following.contains(&u.id) && u.is_following != Some(true))
            .take(limit)
            .cloned()
            .collect()
    }

    pub async fn get_pending_requests(&self) -> Vec<NetworkRequest> {
        let requests = self.requests.read().await;
        requests.clone()
    }

    pub async fn get_network_posts(&self, limit: usize) -> Vec<Post> {
        let posts = self.posts.read().await;
        posts.iter().take(limit).cloned().collect()
    }

    pub async fn follow_user(&mut self, user_id: String) -> Result<(), crate::StrollError> {
        let mut following = self.following.write().await;
        if !following.contains(&user_id) {
            following.push(user_id);
        }
        Ok(())
    }

    pub async fn unfollow_user(&mut self, user_id: String) -> Result<(), crate::StrollError> {
        let mut following = self.following.write().await;
        following.retain(|id| id != &user_id);
        Ok(())
    }
}

fn mock_users() -> Vec<User> {
    crate::models::mock_users()
}

fn mock_posts() -> Vec<Post> {
    crate::models::mock_posts()
}

fn mock_network_requests() -> Vec<NetworkRequest> {
    crate::models::mock_network_requests()
}

fn block_on_future(future: impl Future<Output = ()>) {
    if let Ok(handle) = tokio::runtime::Handle::try_current() {
        tokio::task::block_in_place(|| handle.block_on(future));
    } else {
        tokio::runtime::Runtime::new()
            .expect("runtime creation should succeed")
            .block_on(future);
    }
}
