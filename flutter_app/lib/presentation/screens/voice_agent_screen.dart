import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart';

import '../../data/stroll_models.dart';
import '../../data/stroll_repository.dart';
import '../widgets/activity_card.dart';

enum _AgentProviderOption {
  local('local', 'Local'),
  openrouter('openrouter', 'OpenRouter'),
  huggingface('huggingface', 'HuggingFace'),
  gemini('gemini', 'Gemini Flash');

  const _AgentProviderOption(this.wireValue, this.label);

  final String wireValue;
  final String label;
}

class VoiceAgentScreen extends StatefulWidget {
  const VoiceAgentScreen({
    super.key,
    required this.repository,
  });

  final StrollRepository repository;

  @override
  State<VoiceAgentScreen> createState() => _VoiceAgentScreenState();
}

class _VoiceAgentScreenState extends State<VoiceAgentScreen> {
  final SpeechToText _speech = SpeechToText();

  bool _isListening = false;
  bool _showResults = false;
  bool _loadingResults = false;
  String? _error;
  String _query = '';
  AgentResponseModel? _response;
  String _selectedFilter = 'all';
  _AgentProviderOption _selectedProvider = _AgentProviderOption.local;
  late RecommendationBackendStatus _backendStatus;

  final List<String> _examplePrompts = const [
    'Find Italian brunch nearby',
    'Wellness activities this weekend',
    'Trending bars with good cocktails',
    'Quiet places to work with wifi',
  ];

  @override
  void initState() {
    super.initState();
    _backendStatus = widget.repository.recommendationBackendStatus;
    _initSpeech();
  }

  Future<void> _initSpeech() async {
    try {
      await _speech.initialize();
    } catch (_) {
      // Widget and integration tests may run without speech platform bindings.
    }
  }

  Future<void> _startListening() async {
    if (!_speech.isAvailable) return;

    setState(() {
      _isListening = true;
      _error = null;
    });

    try {
      await _speech.listen(
        onResult: (result) {
          setState(() {
            _query = result.recognizedWords;
          });

          if (result.finalResult) {
            _processQuery();
          }
        },
      );
    } catch (error) {
      setState(() {
        _isListening = false;
        _error = 'Speech input unavailable: $error';
      });
    }
  }

  Future<void> _stopListening() async {
    await _speech.stop();
    setState(() => _isListening = false);
  }

  Future<void> _processQuery() async {
    final trimmed = _query.trim();
    if (trimmed.isEmpty) {
      return;
    }

    setState(() {
      _isListening = false;
      _showResults = true;
      _loadingResults = true;
      _error = null;
    });

    try {
      final result = await widget.repository.processVoiceQuery(
        query: trimmed,
        provider: _selectedProvider.wireValue,
      );
      if (!mounted) return;
      setState(() {
        _response = result;
        _loadingResults = false;
        _selectedFilter = result.filters.isNotEmpty ? result.filters.first.id : 'all';
        _backendStatus = widget.repository.recommendationBackendStatus;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadingResults = false;
        _error = error.toString();
        _backendStatus = widget.repository.recommendationBackendStatus;
      });
    }
  }

  List<ActivityModel> _filteredActivities() {
    final response = _response;
    if (response == null) {
      return const [];
    }

    if (_selectedFilter == 'all') {
      return response.activities;
    }

    return response.activities
        .where((activity) => activity.category == _selectedFilter)
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close, color: Colors.black),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'STROLL Agent',
          style: TextStyle(
            color: Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
        centerTitle: true,
      ),
      body: _showResults ? _buildResultsView() : _buildInputView(),
    );
  }

  Widget _buildInputView() {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.location_on, size: 16, color: Colors.grey.shade600),
              const SizedBox(width: 4),
              Text(
                'Jingan, Shanghai',
                style: TextStyle(
                  color: Colors.grey.shade600,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildBackendStatusBadge(),
        ),
        const SizedBox(height: 8),
        Expanded(
          flex: 3,
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 32),
            decoration: BoxDecoration(
              color: Colors.grey.shade100,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.mic,
                  size: 64,
                  color: Colors.grey.shade400,
                ),
                Positioned(
                  bottom: 24,
                  right: 24,
                  child: GestureDetector(
                    onTap: _isListening ? _stopListening : _startListening,
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 200),
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _isListening ? Colors.red : Colors.black,
                      ),
                      child: Icon(
                        _isListening ? Icons.stop : Icons.mic,
                        color: Colors.white,
                        size: 28,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(
            _isListening
                ? 'Listening... Tell me what you\'re looking for!'
                : 'Tap the microphone and tell me what you want to explore',
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.grey.shade600,
              fontSize: 16,
            ),
          ),
        ),
        Expanded(
          flex: 2,
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.center,
              children: _examplePrompts.map((prompt) {
                return ActionChip(
                  label: Text('"$prompt"'),
                  onPressed: () {
                    setState(() => _query = prompt);
                    _processQuery();
                  },
                  backgroundColor: Colors.grey.shade100,
                  side: BorderSide.none,
                );
              }).toList(growable: false),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Recommendation Provider',
                style: TextStyle(
                  color: Colors.grey.shade700,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _AgentProviderOption.values.map((provider) {
                  final selected = provider == _selectedProvider;
                  return ChoiceChip(
                    label: Text(provider.label),
                    selected: selected,
                    onSelected: (_) {
                      setState(() => _selectedProvider = provider);
                    },
                  );
                }).toList(growable: false),
              ),
            ],
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }

  Widget _buildResultsView() {
    if (_loadingResults) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, size: 40),
              const SizedBox(height: 12),
              const Text(
                'Voice query failed',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(_error!, textAlign: TextAlign.center),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: _processQuery,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }

    final response = _response;
    if (response == null) {
      return const Center(child: Text('No response from agent.'));
    }

    final activities = _filteredActivities();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: _buildBackendStatusBadge(),
        ),
        const SizedBox(height: 8),
        Container(
          margin: const EdgeInsets.all(16),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                Theme.of(context).colorScheme.primary.withOpacity(0.1),
                Theme.of(context).colorScheme.secondary.withOpacity(0.1),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary,
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 16,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'STROLL Agent',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                response.summary,
                style: TextStyle(
                  color: Colors.grey.shade700,
                  height: 1.5,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 44,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            itemCount: response.filters.length,
            itemBuilder: (context, index) {
              final filter = response.filters[index];
              final isSelected = _selectedFilter == filter.id;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(filter.label),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() => _selectedFilter = filter.id);
                  },
                  selectedColor: Theme.of(context).colorScheme.primary,
                  labelStyle: TextStyle(
                    color: isSelected ? Colors.white : Colors.black,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(height: 8),
        Expanded(
          child: activities.isEmpty
              ? const Center(child: Text('No activities for this filter.'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: activities.length,
                  itemBuilder: (context, index) {
                    return ActivityCard(activity: activities[index]);
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildBackendStatusBadge() {
    final isApi = _backendStatus.mode == RecommendationBackendMode.api;
    final accentColor = isApi ? Colors.green.shade700 : Colors.orange.shade700;
    final backgroundColor = isApi ? Colors.green.shade50 : Colors.orange.shade50;
    final detail = _backendStatus.detail;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: accentColor.withOpacity(0.35)),
      ),
      child: Row(
        children: [
          Icon(
            isApi ? Icons.cloud_done_outlined : Icons.memory_outlined,
            color: accentColor,
            size: 18,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              detail == null || detail.isEmpty
                  ? 'Backend: ${_backendStatus.label}'
                  : 'Backend: ${_backendStatus.label} - $detail',
              style: TextStyle(
                color: accentColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
