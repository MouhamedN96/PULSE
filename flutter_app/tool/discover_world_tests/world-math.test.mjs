import assert from 'node:assert/strict';
import test from 'node:test';

import {
  buildActivityText,
  buildClusterLabel,
  buildSceneScore,
  chooseClusterCount,
  cosineSimilarity,
  kMeans,
  mergeProfiles,
} from '../../web/discover_world/world-math.js';

test('buildActivityText composes place context', () => {
  const text = buildActivityText({
    name: 'Night Owl',
    description: 'Late-night ramen',
    category: 'food',
    tags: ['ramen', 'late'],
    ai_summary: 'Popular after midnight',
    location: { neighborhood: 'SoHo' },
  });

  assert.match(text, /Night Owl/);
  assert.match(text, /ramen/);
  assert.match(text, /SoHo/);
});

test('chooseClusterCount stays bounded', () => {
  assert.equal(chooseClusterCount(3), 1);
  assert.equal(chooseClusterCount(10), 3);
  assert.equal(chooseClusterCount(40), 6);
});

test('cosineSimilarity handles identical vectors', () => {
  assert.equal(cosineSimilarity([1, 0], [1, 0]), 1);
});

test('kMeans groups nearby points', () => {
  const clusters = kMeans(
    [
      { id: 'a', vector: [0, 0] },
      { id: 'b', vector: [0.1, 0.1] },
      { id: 'c', vector: [5, 5] },
      { id: 'd', vector: [5.2, 5.1] },
    ],
    2,
  );

  assert.equal(clusters.length, 2);
  assert.equal(clusters[0].points.length + clusters[1].points.length, 4);
});

test('buildClusterLabel uses dominant category and neighborhood', () => {
  const label = buildClusterLabel([
    { category: 'food', location: { neighborhood: 'Tribeca' } },
    { category: 'food', location: { neighborhood: 'Tribeca' } },
    { category: 'nightlife', location: { neighborhood: 'Tribeca' } },
  ]);

  assert.equal(label, 'Food in Tribeca');
});

test('buildSceneScore rewards semantic and rerank inputs', () => {
  const score = buildSceneScore(
    { is_open: true, rating: 4.8, review_count: 1200 },
    {
      semantic: 0.8,
      rerank: 0.75,
      popularity: 0.7,
      saved: true,
      personalized: true,
    },
  );

  assert.ok(score > 0.7);
});

test('mergeProfiles keeps unique saved and seen ids', () => {
  const profile = mergeProfiles(
    {
      saved_activity_ids: ['a'],
      seen_activity_ids: ['b'],
      preferred_categories: { items: ['food'] },
      preferred_tags: { items: ['ramen'] },
      query_history: [],
    },
    {
      saved_activity_ids: ['a', 'c'],
      seen_activity_ids: ['b', 'd'],
      preferred_categories: ['food', 'nightlife'],
      preferred_tags: ['ramen', 'cocktails'],
      query_history: [{ text: 'late food' }],
    },
  );

  assert.deepEqual(profile.saved_activity_ids, ['a', 'c']);
  assert.deepEqual(profile.seen_activity_ids, ['b', 'd']);
  assert.deepEqual(profile.preferred_categories, ['food', 'nightlife']);
});
