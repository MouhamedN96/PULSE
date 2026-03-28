use flutter_rust_bridge::frb;
use serde::{Deserialize, Serialize};

#[frb]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Activity {
    pub id: String,
    pub name: String,
    pub description: String,
    pub category: ActivityCategory,
    pub subcategories: Vec<FoodSubcategory>,
    pub location: Location,
    pub rating: f32,
    pub review_count: i32,
    pub price_level: i32,
    pub images: Vec<String>,
    pub open_hours: String,
    pub phone: Option<String>,
    pub website: Option<String>,
    pub tags: Vec<String>,
    pub distance: Option<String>,
    pub is_open: bool,
    pub ai_summary: Option<String>,
    pub why_recommended: Option<String>,
}

#[frb]
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum ActivityCategory {
    Food,
    Wellness,
    Fun,
    Culture,
    Nature,
    Nightlife,
    Shopping,
}

impl std::fmt::Display for ActivityCategory {
    fn fmt(&self, f: &mut std::fmt::Formatter<'_>) -> std::fmt::Result {
        match self {
            ActivityCategory::Food => write!(f, "food"),
            ActivityCategory::Wellness => write!(f, "wellness"),
            ActivityCategory::Fun => write!(f, "fun"),
            ActivityCategory::Culture => write!(f, "culture"),
            ActivityCategory::Nature => write!(f, "nature"),
            ActivityCategory::Nightlife => write!(f, "nightlife"),
            ActivityCategory::Shopping => write!(f, "shopping"),
        }
    }
}

#[frb]
#[derive(Debug, Clone, PartialEq, Eq, Hash, Serialize, Deserialize)]
pub enum FoodSubcategory {
    Italian,
    French,
    Japanese,
    Chinese,
    Spanish,
    Brunch,
    Breakfast,
    Dinner,
    Coffee,
    Dessert,
}

#[frb]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Location {
    pub lat: f64,
    pub lng: f64,
    pub address: String,
    pub neighborhood: String,
    pub city: String,
}

#[frb]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GeoLocation {
    pub lat: f64,
    pub lng: f64,
}

#[frb]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct User {
    pub id: String,
    pub name: String,
    pub avatar: String,
    pub bio: String,
    pub location: String,
    pub followers: i32,
    pub following: i32,
    pub checkins: i32,
    pub preferences: Vec<ActivityCategory>,
    pub is_following: Option<bool>,
}

impl User {
    pub fn mock_current_user() -> Self {
        Self {
            id: "user-1".to_string(),
            name: "Alex Chen".to_string(),
            avatar: "https://images.unsplash.com/photo-1507003211169-0a1dd7228f2d?w=150&h=150&fit=crop&crop=face".to_string(),
            bio: "Foodie, traveler, and adventure seeker. Always looking for the next great experience!".to_string(),
            location: "Shanghai, China".to_string(),
            followers: 342,
            following: 128,
            checkins: 89,
            preferences: vec![ActivityCategory::Food, ActivityCategory::Wellness, ActivityCategory::Culture],
            is_following: None,
        }
    }
}

#[frb]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Post {
    pub id: String,
    pub user: User,
    pub activity: Activity,
    pub image: String,
    pub caption: String,
    pub likes: i32,
    pub comments: i32,
    pub timestamp: String,
    pub is_liked: Option<bool>,
}

#[frb]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NetworkRequest {
    pub id: String,
    pub user: User,
    pub message: String,
    pub timestamp: String,
    pub status: RequestStatus,
}

#[frb]
#[derive(Debug, Clone, PartialEq, Eq, Serialize, Deserialize)]
pub enum RequestStatus {
    Pending,
    Accepted,
    Declined,
}

#[frb]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FilterOption {
    pub id: String,
    pub label: String,
    pub icon: Option<String>,
    pub category: Option<ActivityCategory>,
}

#[frb]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct VoiceQuery {
    pub text: String,
    pub location: Option<GeoLocation>,
    pub timestamp: String,
}

#[frb]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AgentResponse {
    pub summary: String,
    pub activities: Vec<Activity>,
    pub filters: Vec<FilterOption>,
    pub query: VoiceQuery,
}

#[frb]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct FeedResponse {
    pub recommendations: Vec<Activity>,
    pub posts: Vec<Post>,
    pub trending_tags: Vec<String>,
}

#[frb]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct NetworkResponse {
    pub following: Vec<User>,
    pub suggested: Vec<User>,
    pub requests: Vec<NetworkRequest>,
}

#[frb]
#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct QueryIntent {
    pub categories: Vec<ActivityCategory>,
    pub subcategories: Vec<FoodSubcategory>,
    pub keywords: Vec<String>,
    pub time_context: Option<String>,
}

// Mock data generators
pub fn mock_activities() -> Vec<Activity> {
    vec![
        Activity {
            id: "act-1".to_string(),
            name: "The Commune Social".to_string(),
            description: "Modern tapas restaurant with industrial-chic decor".to_string(),
            category: ActivityCategory::Food,
            subcategories: vec![FoodSubcategory::Spanish, FoodSubcategory::Dinner],
            location: Location {
                lat: 31.2304,
                lng: 121.4737,
                address: "511 Jiangning Rd, Jingan".to_string(),
                neighborhood: "Jingan".to_string(),
                city: "Shanghai".to_string(),
            },
            rating: 4.6,
            review_count: 1243,
            price_level: 3,
            images: vec![
                "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=400&h=300&fit=crop"
                    .to_string(),
            ],
            open_hours: "11:30 AM - 10:30 PM".to_string(),
            phone: Some("+86 21 6047 7638".to_string()),
            website: None,
            tags: vec![
                "tapas".to_string(),
                "spanish".to_string(),
                "date-night".to_string(),
            ],
            distance: Some("0.8 km".to_string()),
            is_open: true,
            ai_summary: Some("A trendy spot for sharing plates with friends.".to_string()),
            why_recommended: Some("Based on your love for Spanish cuisine.".to_string()),
        },
        Activity {
            id: "act-2".to_string(),
            name: "Brewdog Shanghai".to_string(),
            description: "Scottish craft brewery with massive beer selection".to_string(),
            category: ActivityCategory::Nightlife,
            subcategories: vec![],
            location: Location {
                lat: 31.2354,
                lng: 121.4527,
                address: "376 Wukang Rd, Xuhui".to_string(),
                neighborhood: "Xuhui".to_string(),
                city: "Shanghai".to_string(),
            },
            rating: 4.4,
            review_count: 892,
            price_level: 2,
            images: vec![
                "https://images.unsplash.com/photo-1575444758702-4a6b9222336e?w=400&h=300&fit=crop"
                    .to_string(),
            ],
            open_hours: "12:00 PM - 2:00 AM".to_string(),
            phone: Some("+86 21 6431 1234".to_string()),
            website: None,
            tags: vec![
                "craft-beer".to_string(),
                "pub".to_string(),
                "happy-hour".to_string(),
            ],
            distance: Some("1.2 km".to_string()),
            is_open: true,
            ai_summary: Some("Perfect for beer enthusiasts with 30+ taps.".to_string()),
            why_recommended: Some("Your network friend Mike checked in here.".to_string()),
        },
        Activity {
            id: "act-3".to_string(),
            name: "Pure Yoga".to_string(),
            description: "Premium yoga studio offering various classes".to_string(),
            category: ActivityCategory::Wellness,
            subcategories: vec![],
            location: Location {
                lat: 31.2284,
                lng: 121.4637,
                address: "Shanghai Centre, 1376 Nanjing West Rd".to_string(),
                neighborhood: "Jingan".to_string(),
                city: "Shanghai".to_string(),
            },
            rating: 4.8,
            review_count: 567,
            price_level: 4,
            images: vec![
                "https://images.unsplash.com/photo-1544367567-0f2fcb009e0b?w=400&h=300&fit=crop"
                    .to_string(),
            ],
            open_hours: "6:00 AM - 10:00 PM".to_string(),
            phone: Some("+86 21 6279 8778".to_string()),
            website: None,
            tags: vec![
                "yoga".to_string(),
                "meditation".to_string(),
                "wellness".to_string(),
            ],
            distance: Some("0.5 km".to_string()),
            is_open: true,
            ai_summary: Some("Luxury yoga experience with top instructors.".to_string()),
            why_recommended: Some("Matches your wellness preferences.".to_string()),
        },
        Activity {
            id: "act-4".to_string(),
            name: "Museum of Contemporary Art".to_string(),
            description: "Cutting-edge contemporary art exhibitions".to_string(),
            category: ActivityCategory::Culture,
            subcategories: vec![],
            location: Location {
                lat: 31.2404,
                lng: 121.4937,
                address: "231 Nanbei Suzhou Rd, Huangpu".to_string(),
                neighborhood: "Huangpu".to_string(),
                city: "Shanghai".to_string(),
            },
            rating: 4.5,
            review_count: 2103,
            price_level: 2,
            images: vec![
                "https://images.unsplash.com/photo-1518998053901-5348d3961a04?w=400&h=300&fit=crop"
                    .to_string(),
            ],
            open_hours: "10:00 AM - 6:00 PM".to_string(),
            phone: Some("+86 21 6327 9900".to_string()),
            website: None,
            tags: vec![
                "art".to_string(),
                "museum".to_string(),
                "exhibition".to_string(),
            ],
            distance: Some("2.1 km".to_string()),
            is_open: true,
            ai_summary: Some(
                "Currently featuring an immersive digital art exhibition.".to_string(),
            ),
            why_recommended: Some("New exhibition opening this week.".to_string()),
        },
    ]
}

pub fn mock_users() -> Vec<User> {
    vec![
        User {
            id: "user-2".to_string(),
            name: "Sarah Kim".to_string(),
            avatar: "https://images.unsplash.com/photo-1494790108377-be9c29b29330?w=150&h=150&fit=crop&crop=face".to_string(),
            bio: "Fashion blogger & coffee addict ☕️".to_string(),
            location: "Shanghai, China".to_string(),
            followers: 1250,
            following: 340,
            checkins: 234,
            preferences: vec![ActivityCategory::Shopping, ActivityCategory::Food, ActivityCategory::Culture],
            is_following: Some(true),
        },
        User {
            id: "user-3".to_string(),
            name: "Mike Johnson".to_string(),
            avatar: "https://images.unsplash.com/photo-1500648767791-00dcc994a43e?w=150&h=150&fit=crop&crop=face".to_string(),
            bio: "Craft beer enthusiast 🍺 | Traveler".to_string(),
            location: "Shanghai, China".to_string(),
            followers: 567,
            following: 289,
            checkins: 156,
            preferences: vec![ActivityCategory::Nightlife, ActivityCategory::Food, ActivityCategory::Fun],
            is_following: Some(true),
        },
        User {
            id: "user-4".to_string(),
            name: "Nina Patel".to_string(),
            avatar: "https://images.unsplash.com/photo-1544005313-94ddf0286df2?w=150&h=150&fit=crop&crop=face".to_string(),
            bio: "Weekend explorer and brunch hunter".to_string(),
            location: "Shanghai, China".to_string(),
            followers: 312,
            following: 221,
            checkins: 98,
            preferences: vec![ActivityCategory::Food, ActivityCategory::Culture, ActivityCategory::Nature],
            is_following: Some(false),
        },
    ]
}

pub fn mock_posts() -> Vec<Post> {
    let activities = mock_activities();
    let users = mock_users();

    vec![
        Post {
            id: "post-1".to_string(),
            user: users[0].clone(),
            activity: activities[0].clone(),
            image:
                "https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=400&h=400&fit=crop"
                    .to_string(),
            caption:
                "Amazing tapas night! The octopus was 🔥 Highly recommend the gin & tonic too 🍸"
                    .to_string(),
            likes: 45,
            comments: 8,
            timestamp: "2 hours ago".to_string(),
            is_liked: Some(true),
        },
        Post {
            id: "post-2".to_string(),
            user: users[1].clone(),
            activity: activities[1].clone(),
            image:
                "https://images.unsplash.com/photo-1575444758702-4a6b9222336e?w=400&h=400&fit=crop"
                    .to_string(),
            caption: "Great selection of craft beers here! Happy hour until 7pm 🍺".to_string(),
            likes: 32,
            comments: 5,
            timestamp: "5 hours ago".to_string(),
            is_liked: Some(false),
        },
    ]
}

pub fn mock_network_requests() -> Vec<NetworkRequest> {
    vec![
        NetworkRequest {
            id: "req-1".to_string(),
            user: User {
                id: "user-6".to_string(),
                name: "Lisa Zhang".to_string(),
                avatar: "https://images.unsplash.com/photo-1534528741775-53994a69daeb?w=150&h=150&fit=crop&crop=face".to_string(),
                bio: "Art lover 🎨 | Museum hopper".to_string(),
                location: "Shanghai, China".to_string(),
                followers: 890,
                following: 567,
                checkins: 189,
                preferences: vec![ActivityCategory::Culture, ActivityCategory::Shopping, ActivityCategory::Food],
                is_following: Some(false),
            },
            message: "Hey! I noticed we have similar taste in art and food. Would love to connect!".to_string(),
            timestamp: "2 hours ago".to_string(),
            status: RequestStatus::Pending,
        },
        NetworkRequest {
            id: "req-2".to_string(),
            user: User {
                id: "user-7".to_string(),
                name: "Tom Liu".to_string(),
                avatar: "https://images.unsplash.com/photo-1506794778202-cad84cf45f1d?w=150&h=150&fit=crop&crop=face".to_string(),
                bio: "Coffee enthusiast & weekend explorer".to_string(),
                location: "Shanghai, China".to_string(),
                followers: 234,
                following: 189,
                checkins: 67,
                preferences: vec![ActivityCategory::Food, ActivityCategory::Culture],
                is_following: Some(false),
            },
            message: "Saw your post about The Commune Social! Let's grab coffee sometime ☕️".to_string(),
            timestamp: "1 day ago".to_string(),
            status: RequestStatus::Pending,
        },
    ]
}
