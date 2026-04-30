import * as THREE from 'https://cdn.jsdelivr.net/npm/three@0.181.1/build/three.webgpu.js';

import { rankPlaces } from './ai.js';
import {
  buildClusterLabel,
  chooseClusterCount,
  kMeans,
  mergeProfiles,
  normalizePosition,
  titleCase,
} from './world-math.js';

const STORAGE_KEY = 'pulse-discover-world-profile-v1';

function supportsWebGpu() {
  return typeof navigator !== 'undefined' && !!navigator.gpu;
}

function categoryColor(category) {
  switch ((category || '').toLowerCase()) {
    case 'food':
      return 0xff8c66;
    case 'wellness':
      return 0x84f3d5;
    case 'nightlife':
      return 0xff67c4;
    case 'culture':
      return 0x90a8ff;
    case 'shopping':
      return 0xffd76b;
    default:
      return 0xb39ddb;
  }
}

function loadStoredProfile() {
  try {
    const raw = globalThis.localStorage?.getItem(STORAGE_KEY);
    return raw ? JSON.parse(raw) : {};
  } catch (_) {
    return {};
  }
}

function saveStoredProfile(profile) {
  try {
    globalThis.localStorage?.setItem(STORAGE_KEY, JSON.stringify(profile));
  } catch (_) {}
}

function createSceneState() {
  return {
    container: null,
    renderer: null,
    scene: null,
    camera: null,
    rootGroup: null,
    districtGroup: null,
    buildingGroup: null,
    hoverPlane: null,
    resizeObserver: null,
    raycaster: new THREE.Raycaster(),
    pointer: new THREE.Vector2(),
    placeMeshes: new Map(),
    districtMeshes: new Map(),
    focusedPlaceId: null,
    hoveredPlaceId: null,
    orbitAngle: 0,
    focusTarget: null,
    currentPayload: null,
    profile: loadStoredProfile(),
  };
}

const api = globalThis.pulseDiscoverWorld || {};
const state = createSceneState();

function emit(name, payload) {
  const handler = api[name];
  if (typeof handler === 'function') {
    handler(payload);
  }
}

function clearGroup(group) {
  if (!group) {
    return;
  }

  while (group.children.length) {
    const child = group.children[group.children.length - 1];
    if (!child) {
      continue;
    }
    group.remove(child);
    if (child.geometry) {
      child.geometry.dispose?.();
    }
    if (child.material) {
      if (Array.isArray(child.material)) {
        child.material.forEach((material) => material.dispose?.());
      } else {
        child.material.dispose?.();
      }
    }
  }
}

function focusCameraOn(position, height = 6) {
  state.focusTarget = {
    eye: new THREE.Vector3(position.x + 6.5, height + 4, position.z + 8.5),
    lookAt: new THREE.Vector3(position.x, height * 0.4, position.z),
  };
}

function updateFocusAnimation() {
  if (!state.focusTarget || !state.camera) {
    return;
  }

  state.camera.position.lerp(state.focusTarget.eye, 0.08);
  const target = state.camera.userData.lookAtTarget;
  target.lerp(state.focusTarget.lookAt, 0.08);
  state.camera.lookAt(target);

  if (state.camera.position.distanceTo(state.focusTarget.eye) < 0.12) {
    state.camera.position.copy(state.focusTarget.eye);
    target.copy(state.focusTarget.lookAt);
    state.camera.lookAt(target);
    state.focusTarget = null;
    emit('onCameraSettled', {
      placeId: state.focusedPlaceId,
    });
  }
}

function setFocusedPlace(placeId) {
  state.focusedPlaceId = placeId;
  for (const [id, mesh] of state.placeMeshes.entries()) {
    const emissive = mesh.material.emissive;
    if (id === placeId) {
      emissive.setHex(0xffffff);
      focusCameraOn(mesh.position, mesh.scale.y * 0.7);
    } else {
      emissive.setHex(0x111111);
    }
  }
}

function attachPointerEvents() {
  const canvas = state.renderer?.domElement;
  if (!canvas) {
    return;
  }

  canvas.addEventListener('pointermove', (event) => {
    const rect = canvas.getBoundingClientRect();
    state.pointer.x = ((event.clientX - rect.left) / rect.width) * 2 - 1;
    state.pointer.y = -((event.clientY - rect.top) / rect.height) * 2 + 1;
  });

  canvas.addEventListener('click', () => {
    if (!state.camera || !state.scene) {
      return;
    }

    state.raycaster.setFromCamera(state.pointer, state.camera);
    const hits = state.raycaster.intersectObjects([...state.placeMeshes.values()]);
    if (!hits.length) {
      return;
    }

    const placeId = hits[0].object.userData.placeId;
    const clusterId = hits[0].object.userData.clusterId;
    setFocusedPlace(placeId);
    emit('onPlaceSelected', { placeId, clusterId });
  });
}

function updateHover() {
  if (!state.camera) {
    return;
  }

  state.raycaster.setFromCamera(state.pointer, state.camera);
  const hits = state.raycaster.intersectObjects([...state.placeMeshes.values()]);
  const hoveredId = hits[0]?.object?.userData?.placeId ?? null;
  if (hoveredId === state.hoveredPlaceId) {
    return;
  }

  state.hoveredPlaceId = hoveredId;
  if (hoveredId) {
    emit('onPlaceHovered', {
      placeId: hoveredId,
      clusterId: hits[0].object.userData.clusterId,
    });
  }
}

function renderLoop() {
  if (!state.renderer || !state.scene || !state.camera) {
    return;
  }

  state.orbitAngle += 0.0015;
  if (!state.focusTarget) {
    const radius = 22;
    state.camera.position.x = Math.cos(state.orbitAngle) * radius;
    state.camera.position.z = Math.sin(state.orbitAngle) * radius;
    state.camera.position.y = 14;
    state.camera.userData.lookAtTarget.lerp(new THREE.Vector3(0, 1.6, 0), 0.04);
    state.camera.lookAt(state.camera.userData.lookAtTarget);
  } else {
    updateFocusAnimation();
  }

  for (const mesh of state.placeMeshes.values()) {
    const pulse = mesh.userData.placeId === state.focusedPlaceId ? 1.05 : 1.0;
    mesh.scale.y += ((mesh.userData.height * pulse) - mesh.scale.y) * 0.12;
    mesh.position.y = mesh.scale.y * 0.5;
  }

  updateHover();
  state.renderer.render(state.scene, state.camera);
}

async function initWorld(containerId, config = {}) {
  if (!supportsWebGpu()) {
    throw new Error('WebGPU is unavailable');
  }

  const container = document.getElementById(containerId);
  if (!container) {
    throw new Error(`World container "${containerId}" was not found`);
  }

  state.container = container;
  state.scene = new THREE.Scene();
  state.scene.background = new THREE.Color(0x0d0912);
  state.scene.fog = new THREE.Fog(0x0d0912, 12, 46);

  state.camera = new THREE.PerspectiveCamera(
    50,
    container.clientWidth / Math.max(container.clientHeight, 1),
    0.1,
    120,
  );
  state.camera.position.set(18, 14, 18);
  state.camera.userData.lookAtTarget = new THREE.Vector3(0, 1.6, 0);
  state.camera.lookAt(state.camera.userData.lookAtTarget);

  state.renderer = new THREE.WebGPURenderer({
    antialias: true,
    alpha: true,
  });
  await state.renderer.init();
  state.renderer.setPixelRatio(Math.min(globalThis.devicePixelRatio || 1, 2));
  state.renderer.setSize(container.clientWidth, container.clientHeight);
  container.innerHTML = '';
  container.appendChild(state.renderer.domElement);

  state.rootGroup = new THREE.Group();
  state.districtGroup = new THREE.Group();
  state.buildingGroup = new THREE.Group();
  state.rootGroup.add(state.districtGroup);
  state.rootGroup.add(state.buildingGroup);
  state.scene.add(state.rootGroup);

  const ambient = new THREE.AmbientLight(0xffffff, 0.85);
  const key = new THREE.DirectionalLight(0x9fd0ff, 1.1);
  key.position.set(12, 20, 10);
  const rim = new THREE.DirectionalLight(0xff7ad9, 0.75);
  rim.position.set(-10, 12, -8);
  state.scene.add(ambient, key, rim);

  const base = new THREE.Mesh(
    new THREE.CylinderGeometry(16, 18, 0.8, 8),
    new THREE.MeshStandardMaterial({
      color: 0x15101c,
      roughness: 0.85,
      metalness: 0.1,
    }),
  );
  base.position.y = -0.45;
  state.scene.add(base);

  const stars = new THREE.Points(
    new THREE.BufferGeometry(),
    new THREE.PointsMaterial({ color: 0xffffff, size: 0.08 }),
  );
  const starPositions = [];
  for (let index = 0; index < 300; index += 1) {
    starPositions.push(
      (Math.random() - 0.5) * 120,
      Math.random() * 40 + 10,
      (Math.random() - 0.5) * 120,
    );
  }
  stars.geometry.setAttribute('position', new THREE.Float32BufferAttribute(starPositions, 3));
  state.scene.add(stars);

  attachPointerEvents();
  state.renderer.setAnimationLoop(renderLoop);

  state.resizeObserver = new ResizeObserver(() => {
    if (!state.container || !state.renderer || !state.camera) {
      return;
    }
    state.camera.aspect = state.container.clientWidth / Math.max(state.container.clientHeight, 1);
    state.camera.updateProjectionMatrix();
    state.renderer.setSize(state.container.clientWidth, state.container.clientHeight);
  });
  state.resizeObserver.observe(container);

  emit('onCameraSettled', { mode: config.default_camera || 'overview' });
}

function computeDistricts(rankedPlaces) {
  if (!rankedPlaces.length) {
    return [];
  }

  const clustered = kMeans(
    rankedPlaces.map((entry) => ({
      id: entry.place.id,
      vector: entry.vector.length ? entry.vector : [entry.finalScore, entry.popularity, entry.semantic],
      entry,
    })),
    chooseClusterCount(rankedPlaces.length),
  );

  return clustered.map((cluster, index) => {
    const places = cluster.points.map((point) => point.entry.place);
    return {
      id: `district-${index + 1}`,
      label: buildClusterLabel(places),
      places: cluster.points.map((point) => point.entry),
      category: places[0]?.category || 'discover',
    };
  });
}

function drawWorld(rankedPlaces, districts) {
  clearGroup(state.districtGroup);
  clearGroup(state.buildingGroup);
  state.placeMeshes.clear();
  state.districtMeshes.clear();

  const sortedDistricts = districts.sort((left, right) => right.places.length - left.places.length);
  const ringRadius = Math.max(6, 4 + sortedDistricts.length * 1.35);

  sortedDistricts.forEach((district, districtIndex) => {
    const angle = (districtIndex / Math.max(sortedDistricts.length, 1)) * Math.PI * 2;
    const districtCenter = new THREE.Vector3(
      Math.cos(angle) * ringRadius,
      0,
      Math.sin(angle) * ringRadius,
    );
    const districtMesh = new THREE.Mesh(
      new THREE.CylinderGeometry(2.8, 3.2, 0.35, 6),
      new THREE.MeshStandardMaterial({
        color: categoryColor(district.category),
        roughness: 0.75,
        metalness: 0.2,
        transparent: true,
        opacity: 0.5,
      }),
    );
    districtMesh.position.copy(districtCenter);
    districtMesh.userData.clusterId = district.id;
    state.districtGroup.add(districtMesh);
    state.districtMeshes.set(district.id, districtMesh);

    district.places.forEach((entry, placeIndex) => {
      const placeAngle = angle + (placeIndex / Math.max(district.places.length, 1)) * Math.PI * 2;
      const localRadius = 1.2 + (placeIndex % 3) * 0.75;
      const x = districtCenter.x + Math.cos(placeAngle) * localRadius;
      const z = districtCenter.z + Math.sin(placeAngle) * localRadius;
      const height = 1 + entry.finalScore * 8.5;
      const building = new THREE.Mesh(
        new THREE.BoxGeometry(0.85, height, 0.85),
        new THREE.MeshStandardMaterial({
          color: categoryColor(entry.place.category),
          emissive: new THREE.Color(entry.saved ? 0x84f3d5 : 0x111111),
          roughness: 0.35,
          metalness: 0.15,
        }),
      );
      building.position.set(x, height / 2, z);
      building.userData.placeId = entry.place.id;
      building.userData.clusterId = district.id;
      building.userData.height = height;
      state.buildingGroup.add(building);
      state.placeMeshes.set(entry.place.id, building);
    });
  });

  if (rankedPlaces.length) {
    setFocusedPlace(rankedPlaces[0].place.id);
  }
}

async function setWorldData(payload) {
  state.currentPayload = payload;
  const rawPlaces = payload.activities || [];
  if (!rawPlaces.length) {
    return;
  }

  state.profile = mergeProfiles(payload.personalization || {}, state.profile);
  saveStoredProfile(state.profile);

  const rankedPlaces = await rankPlaces({
    places: rawPlaces,
    query: payload.query?.text || '',
    profile: state.profile,
  });
  const districts = computeDistricts(rankedPlaces);
  drawWorld(rankedPlaces, districts);

  if (payload.selected_activity_id) {
    setFocusedPlace(payload.selected_activity_id);
  }
}

async function focusPlace(placeId) {
  if (!placeId || !state.placeMeshes.has(placeId)) {
    return;
  }
  setFocusedPlace(placeId);
}

async function updateCamera(mode) {
  if (mode === 'overview') {
    state.focusTarget = {
      eye: new THREE.Vector3(18, 14, 18),
      lookAt: new THREE.Vector3(0, 1.6, 0),
    };
    return;
  }

  const byId = state.placeMeshes.get(mode);
  if (byId) {
    focusCameraOn(byId.position, byId.scale.y * 0.7);
  }
}

async function disposeWorld() {
  state.resizeObserver?.disconnect();
  state.resizeObserver = null;

  if (state.renderer) {
    state.renderer.setAnimationLoop(null);
    state.renderer.dispose?.();
  }

  if (state.container) {
    state.container.innerHTML = '';
  }

  state.placeMeshes.clear();
  state.districtMeshes.clear();
}

api.supportsWebGpu = supportsWebGpu;
api.initWorld = initWorld;
api.setWorldData = setWorldData;
api.focusPlace = focusPlace;
api.updateCamera = updateCamera;
api.disposeWorld = disposeWorld;
api.onPlaceSelected = null;
api.onPlaceHovered = null;
api.onCameraSettled = null;
api.onWorldInitFailed = null;

globalThis.pulseDiscoverWorld = api;
