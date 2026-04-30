import 'package:flutter_test/flutter_test.dart';
import 'package:stroll/presentation/discover_world/discover_world_controller.dart';

import '../test_helpers/fake_repository.dart';

void main() {
  test('load derives activities and clusters from repository data', () async {
    final controller =
        DiscoverWorldController(repository: FakeStrollRepository());

    await controller.load();

    expect(controller.state.activities, isNotEmpty);
    expect(controller.state.clusters, isNotEmpty);
    expect(controller.state.personalization.savedActivityIds, isNotEmpty);
  });

  test('submitText records query history and updates the summary state',
      () async {
    final controller =
        DiscoverWorldController(repository: FakeStrollRepository());

    await controller.load();
    await controller.submitText('late night ramen');

    expect(controller.state.query?.text, 'late night ramen');
    expect(controller.state.personalization.queryHistory, isNotEmpty);
    expect(controller.state.query?.summary, isNotNull);
  });

  test('saveActivity promotes the place into saved personalization signals',
      () async {
    final controller =
        DiscoverWorldController(repository: FakeStrollRepository());

    await controller.load();
    await controller.saveActivity('act-2');

    expect(
        controller.state.personalization.savedActivityIds, contains('act-2'));
    expect(controller.state.selectedActivityId, 'act-2');
  });
}
