use crate::models::*;

/// Parse a natural language query to extract intent
pub fn parse_query_intent(query: &str) -> QueryIntent {
    let query_lower = query.to_lowercase();

    let mut categories = Vec::new();
    let mut subcategories = Vec::new();
    let mut keywords = Vec::new();
    let mut time_context = None;

    // Parse categories
    if query_lower.contains("food")
        || query_lower.contains("eat")
        || query_lower.contains("restaurant")
        || query_lower.contains("dining")
    {
        categories.push(ActivityCategory::Food);
    }

    if query_lower.contains("yoga")
        || query_lower.contains("spa")
        || query_lower.contains("wellness")
        || query_lower.contains("gym")
    {
        categories.push(ActivityCategory::Wellness);
    }

    if query_lower.contains("bar")
        || query_lower.contains("drink")
        || query_lower.contains("cocktail")
        || query_lower.contains("nightlife")
    {
        categories.push(ActivityCategory::Nightlife);
    }

    if query_lower.contains("museum")
        || query_lower.contains("art")
        || query_lower.contains("gallery")
        || query_lower.contains("exhibition")
    {
        categories.push(ActivityCategory::Culture);
    }

    if query_lower.contains("shop")
        || query_lower.contains("shopping")
        || query_lower.contains("mall")
    {
        categories.push(ActivityCategory::Shopping);
    }

    if query_lower.contains("fun")
        || query_lower.contains("game")
        || query_lower.contains("entertainment")
    {
        categories.push(ActivityCategory::Fun);
    }

    // Parse food subcategories
    if query_lower.contains("italian")
        || query_lower.contains("pizza")
        || query_lower.contains("pasta")
    {
        subcategories.push(FoodSubcategory::Italian);
        if !categories.contains(&ActivityCategory::Food) {
            categories.push(ActivityCategory::Food);
        }
    }

    if query_lower.contains("french") || query_lower.contains("croissant") {
        subcategories.push(FoodSubcategory::French);
        if !categories.contains(&ActivityCategory::Food) {
            categories.push(ActivityCategory::Food);
        }
    }

    if query_lower.contains("japanese")
        || query_lower.contains("sushi")
        || query_lower.contains("ramen")
    {
        subcategories.push(FoodSubcategory::Japanese);
        if !categories.contains(&ActivityCategory::Food) {
            categories.push(ActivityCategory::Food);
        }
    }

    if query_lower.contains("brunch") {
        subcategories.push(FoodSubcategory::Brunch);
        if !categories.contains(&ActivityCategory::Food) {
            categories.push(ActivityCategory::Food);
        }
    }

    if query_lower.contains("breakfast") {
        subcategories.push(FoodSubcategory::Breakfast);
        if !categories.contains(&ActivityCategory::Food) {
            categories.push(ActivityCategory::Food);
        }
    }

    if query_lower.contains("coffee") || query_lower.contains("cafe") {
        subcategories.push(FoodSubcategory::Coffee);
        if !categories.contains(&ActivityCategory::Food) {
            categories.push(ActivityCategory::Food);
        }
    }

    if query_lower.contains("spanish") || query_lower.contains("tapas") {
        subcategories.push(FoodSubcategory::Spanish);
        if !categories.contains(&ActivityCategory::Food) {
            categories.push(ActivityCategory::Food);
        }
    }

    // Parse time context
    if query_lower.contains("weekend") {
        time_context = Some("weekend".to_string());
    } else if query_lower.contains("tonight") || query_lower.contains("today") {
        time_context = Some("today".to_string());
    } else if query_lower.contains("tomorrow") {
        time_context = Some("tomorrow".to_string());
    }

    // Extract keywords
    let stop_words = [
        "find", "me", "a", "the", "in", "near", "nearby", "looking", "for", "want", "to", "some",
        "good", "great", "best", "top",
    ];
    for word in query_lower.split_whitespace() {
        let clean = word.trim_matches(|c: char| !c.is_alphanumeric());
        if clean.len() > 2 && !stop_words.contains(&clean) {
            keywords.push(clean.to_string());
        }
    }

    // Default to all categories if none specified
    if categories.is_empty() {
        categories = vec![
            ActivityCategory::Food,
            ActivityCategory::Wellness,
            ActivityCategory::Culture,
            ActivityCategory::Nightlife,
            ActivityCategory::Fun,
        ];
    }

    QueryIntent {
        categories,
        subcategories,
        keywords,
        time_context,
    }
}

/// Generate an AI summary based on the query and results
pub fn generate_summary(
    query: &str,
    activities: &[Activity],
    user_prefs: &[ActivityCategory],
) -> String {
    let count = activities.len();

    if count == 0 {
        return "I couldn't find any activities matching your request. Try broadening your search!"
            .to_string();
    }

    let intent = parse_query_intent(query);

    // Build category mention
    let category_text = if intent.categories.len() == 1 {
        format!("{} ", intent.categories[0])
    } else if intent.categories.len() <= 3 {
        let cats: Vec<String> = intent.categories.iter().map(|c| c.to_string()).collect();
        format!("{} ", cats.join(", "))
    } else {
        "".to_string()
    };

    // Build highlight mentions
    let mut highlights = Vec::new();

    // Mention highest rated
    if let Some(best) = activities
        .iter()
        .max_by(|a, b| a.rating.partial_cmp(&b.rating).unwrap())
    {
        if best.rating >= 4.5 {
            highlights.push(format!(
                "{} stands out with a {} rating",
                best.name, best.rating
            ));
        }
    }

    // Mention closest
    if let Some(closest) = activities.iter().find(|a| a.distance.is_some()) {
        highlights.push(format!(
            "{} is just {}",
            closest.name,
            closest.distance.as_ref().unwrap()
        ));
    }

    // Build the summary
    let mut summary = format!("I found {} amazing {category_text}spots near you! ", count);

    if !highlights.is_empty() {
        summary.push_str(&format!("{}.", highlights.join(", and ")));
    }

    // Add personalized touch based on preferences
    let matching_prefs: Vec<_> = activities
        .iter()
        .filter(|a| user_prefs.contains(&a.category))
        .collect();

    if !matching_prefs.is_empty() {
        summary.push_str(&format!(
            " {} of them match your interest in {}.",
            matching_prefs.len(),
            user_prefs
                .iter()
                .map(|p| p.to_string())
                .collect::<Vec<_>>()
                .join(", ")
        ));
    }

    summary
}

/// Generate filter options based on activities
pub fn generate_filters(activities: &[Activity]) -> Vec<FilterOption> {
    let mut filters = vec![FilterOption {
        id: "all".to_string(),
        label: "All".to_string(),
        icon: Some("Sparkles".to_string()),
        category: None,
    }];

    // Collect unique categories
    let mut categories: Vec<_> = activities
        .iter()
        .map(|a| &a.category)
        .collect::<std::collections::HashSet<_>>()
        .into_iter()
        .cloned()
        .collect();

    categories.sort_by(|a, b| {
        let count_a = activities.iter().filter(|act| act.category == *a).count();
        let count_b = activities.iter().filter(|act| act.category == *b).count();
        count_b.cmp(&count_a)
    });

    for category in categories {
        let (label, icon) = match category {
            ActivityCategory::Food => ("Food", "UtensilsCrossed"),
            ActivityCategory::Wellness => ("Wellness", "Heart"),
            ActivityCategory::Fun => ("Fun", "PartyPopper"),
            ActivityCategory::Culture => ("Culture", "Palette"),
            ActivityCategory::Nature => ("Nature", "TreePine"),
            ActivityCategory::Nightlife => ("Nightlife", "Wine"),
            ActivityCategory::Shopping => ("Shopping", "ShoppingBag"),
        };

        filters.push(FilterOption {
            id: label.to_lowercase(),
            label: label.to_string(),
            icon: Some(icon.to_string()),
            category: Some(category),
        });
    }

    filters
}

#[cfg(test)]
mod tests {
    use super::*;
    use crate::models::{mock_activities, ActivityCategory, FoodSubcategory};

    #[test]
    fn parses_food_subcategories_from_query() {
        let intent = parse_query_intent("Find Italian brunch nearby");

        assert!(intent.categories.contains(&ActivityCategory::Food));
        assert!(intent.subcategories.contains(&FoodSubcategory::Italian));
        assert!(intent.subcategories.contains(&FoodSubcategory::Brunch));
    }

    #[test]
    fn falls_back_to_default_categories_when_no_match() {
        let intent = parse_query_intent("something completely unrelated");

        assert!(!intent.categories.is_empty());
        assert!(intent.categories.contains(&ActivityCategory::Food));
    }

    #[test]
    fn generates_filters_with_all_first() {
        let activities = mock_activities();
        let filters = generate_filters(&activities);

        assert!(!filters.is_empty());
        assert_eq!(filters[0].id, "all");
    }

    #[test]
    fn summary_handles_empty_results() {
        let summary = generate_summary("find me food", &[], &[ActivityCategory::Food]);
        assert!(summary.contains("couldn't find"));
    }
}
