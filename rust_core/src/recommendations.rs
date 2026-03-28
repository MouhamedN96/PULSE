use crate::agent::generate_filters;
use crate::models::*;
use std::collections::HashMap;
use std::future::Future;
use std::sync::Arc;
use tokio::sync::RwLock;

pub struct RecommendationEngine {
    activities: Arc<RwLock<HashMap<String, Activity>>>,
    saved_activities: Arc<RwLock<Vec<String>>>,
    trending: Arc<RwLock<Vec<String>>>,
}

impl Default for RecommendationEngine {
    fn default() -> Self {
        Self::new()
    }
}

impl RecommendationEngine {
    pub fn new() -> Self {
        Self {
            activities: Arc::new(RwLock::new(HashMap::new())),
            saved_activities: Arc::new(RwLock::new(Vec::new())),
            trending: Arc::new(RwLock::new(Vec::new())),
        }
    }

    pub fn load_mock_activities(&mut self) {
        block_on_future(self.replace_state(mock_activities(), Vec::new()));
    }

    pub async fn replace_state(
        &mut self,
        activities: Vec<Activity>,
        saved_activity_ids: Vec<String>,
    ) {
        let mut map = HashMap::new();
        let mut trending = Vec::new();

        for activity in activities {
            trending.push(activity.id.clone());
            map.insert(activity.id.clone(), activity);
        }

        let mut acts = self.activities.write().await;
        *acts = map;

        let mut trend = self.trending.write().await;
        *trend = trending;

        let mut saved = self.saved_activities.write().await;
        *saved = saved_activity_ids;
    }

    pub async fn find_activities(
        &self,
        _location: Option<&GeoLocation>,
        categories: &[ActivityCategory],
        subcategories: &[FoodSubcategory],
        limit: usize,
    ) -> Vec<Activity> {
        let activities = self.activities.read().await;

        let mut results: Vec<_> = activities
            .values()
            .filter(|a| {
                // Filter by category
                let category_match = categories.is_empty() || categories.contains(&a.category);

                // Filter by subcategory (for food)
                let subcategory_match = subcategories.is_empty()
                    || a.subcategories.iter().any(|s| subcategories.contains(s));

                category_match && subcategory_match
            })
            .cloned()
            .collect();

        // Sort by rating (descending)
        results.sort_by(|a, b| b.rating.partial_cmp(&a.rating).unwrap());

        // Limit results
        results.truncate(limit);

        results
    }

    pub async fn get_personalized_recommendations(
        &self,
        preferences: &[ActivityCategory],
        limit: usize,
    ) -> Vec<Activity> {
        let activities = self.activities.read().await;

        let mut results: Vec<_> = activities
            .values()
            .filter(|a| preferences.contains(&a.category))
            .cloned()
            .collect();

        // Sort by rating
        results.sort_by(|a, b| b.rating.partial_cmp(&a.rating).unwrap());

        results.truncate(limit);
        results
    }

    pub async fn get_trending(&self, category: Option<&str>, limit: usize) -> Vec<Activity> {
        let activities = self.activities.read().await;
        let trending = self.trending.read().await;

        let mut results = Vec::new();

        for id in trending.iter() {
            if let Some(activity) = activities.get(id) {
                if let Some(cat) = category {
                    if activity.category.to_string() != cat {
                        continue;
                    }
                }
                results.push(activity.clone());
            }
        }

        results.truncate(limit);
        results
    }

    pub async fn get_available_filters(&self, activities: &[Activity]) -> Vec<FilterOption> {
        generate_filters(activities)
    }

    pub async fn save_activity(&mut self, activity_id: String) -> Result<(), crate::StrollError> {
        let mut saved = self.saved_activities.write().await;
        if !saved.contains(&activity_id) {
            saved.push(activity_id);
        }
        Ok(())
    }

    pub async fn get_saved_activities(&self) -> Vec<Activity> {
        let activities = self.activities.read().await;
        let saved = self.saved_activities.read().await;

        saved
            .iter()
            .filter_map(|id| activities.get(id).cloned())
            .collect()
    }

    pub fn get_trending_tags(&self) -> Vec<String> {
        vec![
            "#WeekendBrunch".to_string(),
            "#ShanghaiEats".to_string(),
            "#HiddenGems".to_string(),
            "#DateNight".to_string(),
            "#YogaLife".to_string(),
            "#CraftBeer".to_string(),
            "#ArtExhibition".to_string(),
            "#RooftopViews".to_string(),
        ]
    }
}

fn mock_activities() -> Vec<Activity> {
    crate::models::mock_activities()
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

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::{ActivityCategory, FoodSubcategory, GeoLocation};

    #[tokio::test]
    async fn find_activities_filters_and_sorts() {
        let mut engine = RecommendationEngine::new();
        engine.replace_state(mock_activities(), Vec::new()).await;

        let activities = engine
            .find_activities(
                Some(&GeoLocation {
                    lat: 31.23,
                    lng: 121.47,
                }),
                &[ActivityCategory::Food],
                &[FoodSubcategory::Spanish],
                10,
            )
            .await;

        assert!(!activities.is_empty());
        assert!(activities.iter().all(|activity| {
            activity.category == ActivityCategory::Food
                && activity.subcategories.contains(&FoodSubcategory::Spanish)
        }));
        assert!(activities
            .windows(2)
            .all(|window| window[0].rating >= window[1].rating));
    }

    #[tokio::test]
    async fn save_activity_round_trip() {
        let mut engine = RecommendationEngine::new();
        engine.replace_state(mock_activities(), Vec::new()).await;

        engine
            .save_activity("act-1".to_string())
            .await
            .expect("saving known activity should succeed");
        let saved = engine.get_saved_activities().await;

        assert_eq!(saved.len(), 1);
        assert_eq!(saved[0].id, "act-1");
    }
}
