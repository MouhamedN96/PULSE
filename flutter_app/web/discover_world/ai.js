import {
  buildActivityText,
  buildSceneScore,
  normalizeVector,
  scorePopularity,
} from './world-math.js';

const EMBED_MODEL = 'mixedbread-ai/mxbai-embed-xsmall-v1';
const RERANK_MODEL = 'mixedbread-ai/mxbai-rerank-large-v1';

let transformersPromise;
let embedderPromise;
let rerankerModelPromise;
let rerankerTokenizerPromise;
let rerankerDisabled = false;
const embeddingCache = new Map();

async function loadTransformers() {
  if (!transformersPromise) {
    transformersPromise = import('https://cdn.jsdelivr.net/npm/@huggingface/transformers@3.8.0').then((module) => {
      if (module.env) {
        module.env.allowRemoteModels = true;
        module.env.useBrowserCache = true;
      }
      return module;
    });
  }
  return transformersPromise;
}

async function getEmbedder() {
  if (!embedderPromise) {
    embedderPromise = loadTransformers().then(({ pipeline }) =>
      pipeline('feature-extraction', EMBED_MODEL, {
        device: 'webgpu',
      }),
    );
  }
  return embedderPromise;
}

async function getReranker() {
  if (rerankerDisabled) {
    return null;
  }

  if (!rerankerModelPromise || !rerankerTokenizerPromise) {
    const { AutoTokenizer, AutoModelForSequenceClassification } = await loadTransformers();
    rerankerTokenizerPromise = AutoTokenizer.from_pretrained(RERANK_MODEL);
    rerankerModelPromise = AutoModelForSequenceClassification.from_pretrained(RERANK_MODEL, {
      device: 'webgpu',
      dtype: 'q8',
    }).catch((error) => {
      rerankerDisabled = true;
      console.warn('[discover-world] reranker unavailable', error);
      return null;
    });
  }

  const [tokenizer, model] = await Promise.all([rerankerTokenizerPromise, rerankerModelPromise]);
  if (!tokenizer || !model) {
    return null;
  }

  return { tokenizer, model };
}

async function embedText(text) {
  const normalizedText = text.trim();
  if (!normalizedText) {
    return [];
  }

  const cached = embeddingCache.get(normalizedText);
  if (cached) {
    return cached;
  }

  const embedder = await getEmbedder();
  const output = await embedder(normalizedText, {
    pooling: 'mean',
    normalize: true,
  });
  const vector = normalizeVector(Array.from(output?.data || []));
  embeddingCache.set(normalizedText, vector);
  return vector;
}

async function rerankTopPlaces(query, places) {
  if (!query.trim() || !places.length) {
    return new Map();
  }

  const reranker = await getReranker();
  if (!reranker) {
    return new Map();
  }

  const scores = new Map();
  for (const place of places) {
    try {
      const inputs = await reranker.tokenizer(query, buildActivityText(place), {
        truncation: true,
        max_length: 512,
      });
      const output = await reranker.model(inputs);
      const logits = Array.from(output?.logits?.data || []);
      const score = logits.length > 1 ? logits[1] : logits[0] ?? 0;
      scores.set(place.id, score);
    } catch (error) {
      console.warn('[discover-world] reranker score failed', place.id, error);
      scores.set(place.id, 0);
    }
  }
  return scores;
}

function buildQueryText(query, profile) {
  const preferredCategories = profile.preferred_categories || [];
  const preferredTags = profile.preferred_tags || [];
  const suffix = [...preferredCategories.slice(0, 4), ...preferredTags.slice(0, 4)].join(' ');
  return [query, suffix].filter(Boolean).join(' ').trim() || 'popular places near me';
}

export async function rankPlaces({ places, query = '', profile = {} }) {
  const mergedQuery = buildQueryText(query, profile);
  const queryVector = await embedText(mergedQuery);

  const placeVectors = await Promise.all(
    places.map(async (place) => ({
      place,
      vector: await embedText(buildActivityText(place)),
    })),
  );

  const semanticRanked = placeVectors.map(({ place, vector }) => {
    const semantic = queryVector.length && vector.length
      ? vector.reduce((sum, value, index) => sum + value * (queryVector[index] || 0), 0)
      : 0;
    const popularity = scorePopularity(place);
    const saved = (profile.saved_activity_ids || []).includes(place.id);
    const personalized = (profile.preferred_categories || []).includes(place.category) ||
      (place.tags || []).some((tag) => (profile.preferred_tags || []).includes(tag.toLowerCase()));

    return {
      place,
      vector,
      semantic,
      popularity,
      saved,
      personalized,
    };
  });

  semanticRanked.sort((left, right) => right.semantic - left.semantic);
  const rerankCandidates = semanticRanked.slice(0, Math.min(12, semanticRanked.length)).map((entry) => entry.place);
  const rerankScores = await rerankTopPlaces(query, rerankCandidates);

  const rerankValues = [...rerankScores.values()];
  const rerankMin = rerankValues.length ? Math.min(...rerankValues) : 0;
  const rerankMax = rerankValues.length ? Math.max(...rerankValues) : 0;

  const ranked = semanticRanked.map((entry) => {
    const rerankRaw = rerankScores.get(entry.place.id) ?? 0;
    const rerank = rerankMax > rerankMin ? (rerankRaw - rerankMin) / (rerankMax - rerankMin) : 0;
    const finalScore = buildSceneScore(entry.place, {
      semantic: entry.semantic,
      rerank,
      popularity: entry.popularity,
      saved: entry.saved,
      personalized: entry.personalized,
    });

    return {
      ...entry,
      rerank,
      finalScore,
    };
  });

  ranked.sort((left, right) => right.finalScore - left.finalScore);
  return ranked;
}
