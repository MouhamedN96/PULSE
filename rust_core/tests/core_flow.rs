use stroll_core::StrollCore;

#[tokio::test]
async fn end_to_end_core_flow() {
    let core = StrollCore::new();
    core.init_with_mock_data_async()
        .await
        .expect("mock data should initialize");

    let feed = core
        .get_personalized_feed()
        .await
        .expect("feed should load from mock data");
    assert!(!feed.recommendations.is_empty());

    let agent_response = core
        .process_voice_query("Find Spanish dinner nearby".to_string(), None, None)
        .await
        .expect("voice query should return results");
    assert!(!agent_response.activities.is_empty());

    let network_before = core
        .get_network()
        .await
        .expect("network should load from mock data");
    assert!(!network_before.suggested.is_empty());

    let user_id = network_before.suggested[0].id.clone();
    core.follow_user(user_id.clone())
        .await
        .expect("follow should succeed");

    let network_after = core
        .get_network()
        .await
        .expect("network should load after follow");
    assert!(network_after
        .following
        .iter()
        .any(|user| user.id == user_id));

    let activity_id = feed.recommendations[0].id.clone();
    core.save_activity(activity_id.clone())
        .await
        .expect("save activity should succeed");

    let saved = core
        .get_saved_activities()
        .await
        .expect("saved activities should load");
    assert!(saved.iter().any(|activity| activity.id == activity_id));
}
