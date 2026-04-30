import 'dart:async';

import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../data/stroll_repository.dart';
import '../discover_world/discover_world_bridge.dart';
import '../discover_world/discover_world_controller.dart';
import '../discover_world/discover_world_models.dart';
import '../discover_world/discover_world_platform_view.dart';
import 'feed_screen.dart';

enum _WorldProviderOption {
  local('local', 'Local'),
  openrouter('openrouter', 'OpenRouter'),
  huggingface('huggingface', 'HuggingFace'),
  gemini('gemini', 'Gemini Flash');

  const _WorldProviderOption(this.wireValue, this.label);

  final String wireValue;
  final String label;
}

class DiscoverWorldScreen extends StatefulWidget {
  const DiscoverWorldScreen({
    super.key,
    required this.repository,
    this.bridge,
  });

  final StrollRepository repository;
  final DiscoverWorldBridge? bridge;

  @override
  State<DiscoverWorldScreen> createState() => _DiscoverWorldScreenState();
}

class _DiscoverWorldScreenState extends State<DiscoverWorldScreen> {
  static const String _viewType = 'pulse-discover-world-view';
  static const String _containerId = 'pulse-discover-world-container';

  final SpeechToText _speech = SpeechToText();
  final TextEditingController _searchController = TextEditingController();

  late final DiscoverWorldController _controller;
  late final DiscoverWorldBridge _bridge;

  bool _speechAvailable = false;
  bool _isListening = false;
  bool _worldSupported = false;
  bool _worldInitialized = false;
  bool _worldInitFailed = false;
  bool _manualListMode = false;
  String? _worldError;
  _WorldProviderOption _selectedProvider = _WorldProviderOption.local;

  @override
  void initState() {
    super.initState();
    _controller = DiscoverWorldController(repository: widget.repository)
      ..addListener(_handleControllerUpdated);
    _bridge = widget.bridge ?? createDiscoverWorldBridge();
    _bridge.attachCallbacks(
      onPlaceSelected: _handlePlaceSelected,
      onPlaceHovered: _handlePlaceHovered,
      onCameraSettled: _handleCameraSettled,
      onWorldInitFailed: _handleWorldInitFailed,
    );
    _worldSupported = _bridge.supportsWebGpu();

    unawaited(_controller.load());
    unawaited(_initSpeech());

    if (_worldSupported) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        unawaited(_initializeWorld());
      });
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_handleControllerUpdated);
    _controller.dispose();
    _searchController.dispose();
    unawaited(_speech.cancel());
    unawaited(_bridge.disposeWorld());
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      final available = await _speech.initialize();
      if (!mounted) {
        return;
      }
      setState(() {
        _speechAvailable = available;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _speechAvailable = false;
      });
    }
  }

  Future<void> _initializeWorld() async {
    if (!_worldSupported || _worldInitialized || _manualListMode) {
      return;
    }

    try {
      await _bridge.initWorld(
        containerId: _containerId,
        config: const <String, dynamic>{
          'theme': 'pixel-city',
          'camera_mode': 'guided',
          'default_camera': 'overview',
        },
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _worldInitialized = true;
        _worldInitFailed = false;
        _worldError = null;
      });
      await _syncWorldData();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _worldInitFailed = true;
        _worldError = error.toString();
      });
    }
  }

  bool get _shows2dFallback =>
      !_worldSupported || _worldInitFailed || _manualListMode;

  void _handleControllerUpdated() {
    if (!mounted) {
      return;
    }

    if (_worldInitialized && !_shows2dFallback) {
      unawaited(_syncWorldData());
      final selectedActivityId = _controller.state.selectedActivityId;
      if (selectedActivityId != null) {
        unawaited(_bridge.focusPlace(selectedActivityId));
      }
    }

    setState(() {});
  }

  Future<void> _syncWorldData() async {
    try {
      await _bridge.setWorldData(_controller.toBridgeJson());
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _worldInitFailed = true;
        _worldError = error.toString();
      });
    }
  }

  void _handlePlaceSelected(Map<String, dynamic> payload) {
    final activityId = payload['placeId']?.toString() ??
        payload['activityId']?.toString() ??
        payload['id']?.toString();
    final clusterId = payload['clusterId']?.toString();

    if (activityId != null && activityId.isNotEmpty) {
      _controller.selectActivity(activityId);
    }
    if (clusterId != null && clusterId.isNotEmpty) {
      _controller.selectCluster(clusterId);
    }
  }

  void _handlePlaceHovered(Map<String, dynamic> payload) {
    final activityId =
        payload['placeId']?.toString() ?? payload['activityId']?.toString();
    if (activityId != null && activityId.isNotEmpty) {
      _controller.selectActivity(activityId);
    }
  }

  void _handleCameraSettled(Map<String, dynamic> payload) {}

  void _handleWorldInitFailed(Map<String, dynamic> payload) {
    if (!mounted) {
      return;
    }

    setState(() {
      _worldInitFailed = true;
      _worldError =
          payload['message']?.toString() ?? 'World initialization failed';
    });
  }

  Future<void> _submitSearch() async {
    final query = _searchController.text.trim();
    if (query.isEmpty) {
      return;
    }

    await _controller.submitText(
      query,
      provider: _selectedProvider.wireValue,
    );
  }

  Future<void> _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      if (!mounted) {
        return;
      }
      setState(() {
        _isListening = false;
      });
      return;
    }

    if (!_speechAvailable) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('Voice input is unavailable on this device.')),
      );
      return;
    }

    setState(() {
      _isListening = true;
    });

    await _speech.listen(
      onResult: (result) {
        _searchController.text = result.recognizedWords;
        _searchController.selection = TextSelection.fromPosition(
          TextPosition(offset: _searchController.text.length),
        );

        if (result.finalResult) {
          unawaited(
            _controller.submitVoice(
              result.recognizedWords,
              provider: _selectedProvider.wireValue,
            ),
          );
          if (mounted) {
            setState(() {
              _isListening = false;
            });
          }
        }
      },
    );
  }

  Widget _buildFallback() {
    return Stack(
      children: [
        FeedScreen(repository: widget.repository),
        if (_worldSupported)
          Positioned(
            top: 20,
            right: 20,
            child: FilledButton.icon(
              key: const Key('discover-world-return-to-world'),
              onPressed: () {
                setState(() {
                  _manualListMode = false;
                });
                unawaited(_initializeWorld());
              },
              icon: const Icon(Icons.view_in_ar_rounded),
              label: const Text('Back to World'),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    if (_shows2dFallback) {
      return _buildFallback();
    }

    final state = _controller.state;
    final selectedActivity = state.selectedActivity;

    return Scaffold(
      backgroundColor: const Color(0xFF0D0912),
      body: Stack(
        children: [
          const Positioned.fill(
            child: DiscoverWorldPlatformView(
              viewType: _viewType,
              containerId: _containerId,
            ),
          ),
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.black.withOpacity(0.45),
                      Colors.transparent,
                      Colors.black.withOpacity(0.55),
                    ],
                  ),
                ),
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(state),
                  const SizedBox(height: 16),
                  _buildSearchBar(state),
                  if (state.query?.summary != null ||
                      state.errorMessage != null ||
                      _worldError != null) ...[
                    const SizedBox(height: 14),
                    _buildSummaryCard(state),
                  ],
                  const SizedBox(height: 12),
                  _buildMetaRow(state),
                  if (state.clusters.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    _buildClusterStrip(state),
                  ],
                  const Spacer(),
                  if (!_worldInitialized || state.isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.only(bottom: 12),
                        child:
                            CircularProgressIndicator(color: Color(0xFF84F3D5)),
                      ),
                    ),
                  if (selectedActivity != null)
                    _buildSelectedCard(selectedActivity),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader(DiscoverWorldState state) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'PULSE CITY',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Local AI ranks, clusters, and personalizes your city in real time.',
                style: TextStyle(
                  color: Colors.white.withOpacity(0.78),
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 12),
        FilledButton.tonalIcon(
          key: const Key('discover-world-switch-to-list'),
          onPressed: () {
            setState(() {
              _manualListMode = true;
            });
          },
          icon: const Icon(Icons.view_list_rounded),
          label: const Text('List'),
        ),
      ],
    );
  }

  Widget _buildSearchBar(DiscoverWorldState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1224).withOpacity(0.92),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFF84F3D5).withOpacity(0.24)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  key: const Key('discover-world-search-field'),
                  controller: _searchController,
                  onSubmitted: (_) => unawaited(_submitSearch()),
                  style: const TextStyle(color: Colors.white),
                  decoration: const InputDecoration(
                    hintText:
                        'Ask the city: rooftop drinks, cozy ramen, quiet study spots...',
                    hintStyle:
                        TextStyle(color: Color(0xFFA89BB7), fontSize: 14),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                ),
              ),
              IconButton(
                onPressed: state.isLoading || state.isRefreshing
                    ? null
                    : _submitSearch,
                icon: const Icon(Icons.send_rounded, color: Color(0xFF84F3D5)),
              ),
              IconButton(
                key: const Key('discover-world-mic-button'),
                onPressed: _toggleListening,
                icon: Icon(
                  _isListening ? Icons.stop_circle_rounded : Icons.mic_rounded,
                  color: _speechAvailable
                      ? const Color(0xFFFF8CC6)
                      : const Color(0xFF756A86),
                ),
              ),
            ],
          ),
          Row(
            children: [
              _buildBackendBadge(state),
              const SizedBox(width: 10),
              PopupMenuButton<_WorldProviderOption>(
                onSelected: (option) {
                  setState(() {
                    _selectedProvider = option;
                  });
                },
                color: const Color(0xFF22182E),
                itemBuilder: (context) {
                  return _WorldProviderOption.values
                      .map(
                        (option) => PopupMenuItem<_WorldProviderOption>(
                          value: option,
                          child: Text(option.label),
                        ),
                      )
                      .toList(growable: false);
                },
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2A1D39),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    _selectedProvider.label,
                    style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                        fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const Spacer(),
              if (_isListening)
                const Text(
                  'Listening...',
                  style: TextStyle(
                      color: Color(0xFFFF8CC6), fontWeight: FontWeight.w600),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBackendBadge(DiscoverWorldState state) {
    final detail = state.backendDetail;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1D39),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(
        detail == null || detail.isEmpty
            ? state.backendLabel
            : '${state.backendLabel} · $detail',
        style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildSummaryCard(DiscoverWorldState state) {
    final summary =
        state.errorMessage ?? _worldError ?? state.query?.summary ?? '';
    final hasError = state.errorMessage != null || _worldError != null;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: hasError ? const Color(0xFF3B1720) : const Color(0xFF1A2733),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: hasError
              ? const Color(0xFFFF8CC6).withOpacity(0.45)
              : const Color(0xFF84F3D5).withOpacity(0.24),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hasError ? Icons.warning_amber_rounded : Icons.auto_awesome_rounded,
            color: hasError ? const Color(0xFFFF8CC6) : const Color(0xFF84F3D5),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              summary,
              style: const TextStyle(color: Colors.white, height: 1.45),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetaRow(DiscoverWorldState state) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        _pill('${state.activityCount} places'),
        _pill('${state.clusterCount} districts'),
        if (state.personalization.savedActivityIds.isNotEmpty)
          _pill('${state.personalization.savedActivityIds.length} saved'),
        if (state.personalization.queryHistory.isNotEmpty)
          _pill('${state.personalization.queryHistory.length} local queries'),
      ],
    );
  }

  Widget _pill(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.black.withOpacity(0.28),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: const TextStyle(
            color: Colors.white, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildClusterStrip(DiscoverWorldState state) {
    final clusters = state.clusters.take(6).toList(growable: false);
    return SizedBox(
      height: 42,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: clusters.length,
        separatorBuilder: (context, index) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final cluster = clusters[index];
          final selected = cluster.id == state.selectedClusterId;
          return ChoiceChip(
            label: Text(cluster.label),
            selected: selected,
            onSelected: (_) {
              _controller.selectCluster(cluster.id);
              _controller.selectActivity(cluster.topActivityId);
              unawaited(_bridge.focusPlace(cluster.topActivityId));
            },
          );
        },
      ),
    );
  }

  Widget _buildSelectedCard(DiscoverWorldActivityView selectedActivity) {
    return Material(
      color: Colors.transparent,
      child: Container(
        key: const Key('discover-world-selected-activity-card'),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: const Color(0xFF17101F).withOpacity(0.96),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withOpacity(0.08)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedActivity.activity.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${selectedActivity.clusterLabel} · score ${selectedActivity.score.toStringAsFixed(2)}',
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.72),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: _controller.clearSelection,
                  icon: const Icon(Icons.close_rounded, color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: const Color(0xFF201629),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 72,
                    height: 72,
                    decoration: BoxDecoration(
                      color: const Color(0xFF2F2240),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Icon(
                      _iconForCategory(selectedActivity.activity.category),
                      color: const Color(0xFF84F3D5),
                      size: 34,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          selectedActivity.activity.description,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.82),
                            height: 1.35,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            _signalPill(
                                selectedActivity.activity.distance ?? 'Nearby'),
                            _signalPill(
                              '★ ${selectedActivity.activity.rating.toStringAsFixed(1)}',
                            ),
                            _signalPill(
                              selectedActivity.activity.isOpen
                                  ? 'Open now'
                                  : 'Closed',
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),
                  FilledButton.icon(
                    onPressed: () =>
                        _controller.saveActivity(selectedActivity.activity.id),
                    icon: const Icon(Icons.bookmark_add_rounded),
                    label: const Text('Save'),
                  ),
                ],
              ),
            ),
            if (selectedActivity.signals.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: selectedActivity.signals
                      .map(
                        _signalPill,
                      )
                      .toList(growable: false),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Widget _signalPill(String signal) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFF261933),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        signal,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 11,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  IconData _iconForCategory(String category) {
    switch (category) {
      case 'food':
        return Icons.restaurant_rounded;
      case 'wellness':
        return Icons.spa_rounded;
      case 'nightlife':
        return Icons.nightlife_rounded;
      case 'culture':
        return Icons.museum_rounded;
      case 'shopping':
        return Icons.shopping_bag_rounded;
      default:
        return Icons.location_city_rounded;
    }
  }
}
