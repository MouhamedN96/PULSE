use stroll_core::StrollCore;
use tempfile::tempdir;

#[tokio::test]
async fn sqlite_bootstrap_is_idempotent() {
    let temp_dir = tempdir().expect("tempdir should be created");
    let db_path = temp_dir.path().join("stroll.sqlite");
    let db_path = db_path.to_string_lossy().to_string();

    let core = StrollCore::new_with_db_path(db_path.clone());
    core.init_with_mock_data_async()
        .await
        .expect("first bootstrap should succeed");
    core.init_with_mock_data_async()
        .await
        .expect("second bootstrap should also succeed");

    let feed = core
        .get_personalized_feed()
        .await
        .expect("feed should be available after bootstrap");
    assert!(!feed.recommendations.is_empty());

    let network = core
        .get_network()
        .await
        .expect("network should be available after bootstrap");
    assert!(!network.following.is_empty());
    assert!(!network.requests.is_empty());
}

#[tokio::test]
async fn sqlite_persists_saved_activities_across_restart() {
    let temp_dir = tempdir().expect("tempdir should be created");
    let db_path = temp_dir.path().join("stroll.sqlite");
    let db_path = db_path.to_string_lossy().to_string();

    let core = StrollCore::new_with_db_path(db_path.clone());
    core.init_with_mock_data_async()
        .await
        .expect("bootstrap should succeed");

    let feed = core
        .get_personalized_feed()
        .await
        .expect("feed should load");
    let activity_id = feed.recommendations[0].id.clone();

    core.save_activity(activity_id.clone())
        .await
        .expect("saving activity should succeed");

    let restarted_core = StrollCore::new_with_db_path(db_path);
    restarted_core
        .init_with_mock_data_async()
        .await
        .expect("restarted bootstrap should succeed");

    let saved = restarted_core
        .get_saved_activities()
        .await
        .expect("saved activities should load");
    assert!(saved.iter().any(|activity| activity.id == activity_id));
}

#[tokio::test]
async fn sqlite_persists_follows_across_restart() {
    let temp_dir = tempdir().expect("tempdir should be created");
    let db_path = temp_dir.path().join("stroll.sqlite");
    let db_path = db_path.to_string_lossy().to_string();

    let core = StrollCore::new_with_db_path(db_path.clone());
    core.init_with_mock_data_async()
        .await
        .expect("bootstrap should succeed");

    let before = core.get_network().await.expect("network should load");
    let user_id = before.suggested[0].id.clone();

    core.follow_user(user_id.clone())
        .await
        .expect("follow should succeed");

    let restarted_core = StrollCore::new_with_db_path(db_path);
    restarted_core
        .init_with_mock_data_async()
        .await
        .expect("restarted bootstrap should succeed");

    let after = restarted_core
        .get_network()
        .await
        .expect("network should load after restart");
    assert!(after.following.iter().any(|user| user.id == user_id));
}

#[test]
fn sqlite_invalid_path_maps_to_db_init_error() {
    let core = StrollCore::new_with_db_path(String::new());
    let error = core
        .init_with_mock_data()
        .expect_err("empty path must fail initialization");

    assert_eq!(error.code, "DB_INIT_ERROR");
}
