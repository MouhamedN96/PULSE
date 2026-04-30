export function buildActivityText(place) {
  return [
    place.name,
    place.description,
    place.category,
    ...(place.tags || []),
    place.ai_summary || place.aiSummary,
    place.location?.neighborhood,
  ]
    .filter(Boolean)
    .join(' ');
}

export function normalizeVector(vector) {
  const length = Math.sqrt(vector.reduce((sum, value) => sum + value * value, 0));
  if (!length) {
    return vector.map(() => 0);
  }
  return vector.map((value) => value / length);
}

export function cosineSimilarity(a, b) {
  if (!a || !b || a.length !== b.length || a.length === 0) {
    return 0;
  }

  let dot = 0;
  let magA = 0;
  let magB = 0;
  for (let index = 0; index < a.length; index += 1) {
    dot += a[index] * b[index];
    magA += a[index] * a[index];
    magB += b[index] * b[index];
  }

  if (!magA || !magB) {
    return 0;
  }

  return dot / (Math.sqrt(magA) * Math.sqrt(magB));
}

export function chooseClusterCount(count) {
  if (count <= 4) return 1;
  if (count <= 8) return 2;
  if (count <= 12) return 3;
  if (count <= 18) return 4;
  if (count <= 24) return 5;
  return 6;
}

function euclideanDistance(a, b) {
  let sum = 0;
  for (let index = 0; index < a.length; index += 1) {
    const delta = a[index] - b[index];
    sum += delta * delta;
  }
  return Math.sqrt(sum);
}

function meanVector(vectors) {
  if (!vectors.length) {
    return [];
  }

  const totals = new Array(vectors[0].length).fill(0);
  for (const vector of vectors) {
    for (let index = 0; index < vector.length; index += 1) {
      totals[index] += vector[index];
    }
  }

  return totals.map((value) => value / vectors.length);
}

export function kMeans(points, requestedK) {
  if (!points.length) {
    return [];
  }

  const k = Math.max(1, Math.min(requestedK, points.length));
  const centroids = points.slice(0, k).map((point) => point.vector.slice());
  let assignments = new Array(points.length).fill(0);

  for (let iteration = 0; iteration < 8; iteration += 1) {
    assignments = points.map((point) => {
      let bestIndex = 0;
      let bestDistance = Number.POSITIVE_INFINITY;

      for (let index = 0; index < centroids.length; index += 1) {
        const distance = euclideanDistance(point.vector, centroids[index]);
        if (distance < bestDistance) {
          bestDistance = distance;
          bestIndex = index;
        }
      }

      return bestIndex;
    });

    for (let clusterIndex = 0; clusterIndex < centroids.length; clusterIndex += 1) {
      const members = points
        .filter((_, pointIndex) => assignments[pointIndex] === clusterIndex)
        .map((point) => point.vector);

      if (members.length) {
        centroids[clusterIndex] = meanVector(members);
      }
    }
  }

  return centroids.map((centroid, clusterIndex) => ({
    centroid,
    points: points.filter((_, pointIndex) => assignments[pointIndex] === clusterIndex),
  }));
}

function dominantValue(values, fallback) {
  if (!values.length) {
    return fallback;
  }

  const counts = new Map();
  for (const value of values) {
    counts.set(value, (counts.get(value) || 0) + 1);
  }

  return [...counts.entries()].sort((left, right) => right[1] - left[1])[0][0];
}

export function buildClusterLabel(places) {
  const categories = places.map((place) => titleCase(place.category || 'discover'));
  const neighborhoods = places
    .map((place) => place.location?.neighborhood || place.location?.city)
    .filter(Boolean);

  const category = dominantValue(categories, 'Discover');
  const neighborhood = dominantValue(neighborhoods, 'Citywide');
  return `${category} in ${neighborhood}`;
}

export function buildSceneScore(place, score) {
  const rerank = score.rerank ?? 0;
  const semantic = score.semantic ?? 0;
  const popularity = score.popularity ?? 0;
  const openNow = place.is_open ?? place.isOpen ? 1 : 0.2;
  const saved = score.saved ? 1 : 0;
  const personalized = score.personalized ? 1 : 0;

  return clamp01(
    semantic * 0.34 +
      rerank * 0.22 +
      popularity * 0.14 +
      openNow * 0.14 +
      saved * 0.08 +
      personalized * 0.08,
  );
}

export function scorePopularity(place) {
  const rating = Number(place.rating || 0);
  const reviews = Number(place.review_count || place.reviewCount || 0);
  const ratingScore = clamp01((rating - 3) / 2);
  const reviewScore = clamp01(Math.log(reviews + 1) / Math.log(2000));
  return clamp01(ratingScore * 0.65 + reviewScore * 0.35);
}

export function mergeProfiles(baseProfile = {}, runtimeProfile = {}) {
  return {
    preferred_categories: uniq([
      ...(baseProfile.preferred_categories?.items || []),
      ...(runtimeProfile.preferred_categories || []),
    ]),
    preferred_tags: uniq([
      ...(baseProfile.preferred_tags?.items || []),
      ...(runtimeProfile.preferred_tags || []),
    ]),
    saved_activity_ids: uniq([
      ...(baseProfile.saved_activity_ids || []),
      ...(runtimeProfile.saved_activity_ids || []),
    ]),
    seen_activity_ids: uniq([
      ...(baseProfile.seen_activity_ids || []),
      ...(runtimeProfile.seen_activity_ids || []),
    ]),
    query_history: [...(baseProfile.query_history || []), ...(runtimeProfile.query_history || [])],
  };
}

export function normalizePosition(value, min, max) {
  if (max <= min) {
    return 0.5;
  }
  return clamp01((value - min) / (max - min));
}

export function clamp01(value) {
  return Math.max(0, Math.min(1, value));
}

export function titleCase(value = '') {
  return value
    .split(/[_\-\s]+/)
    .filter(Boolean)
    .map((part) => `${part.slice(0, 1).toUpperCase()}${part.slice(1)}`)
    .join(' ');
}

export function uniq(values) {
  return [...new Set(values.filter(Boolean))];
}
