import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../data/stroll_models.dart';
import '../../data/stroll_repository.dart';

class FeedScreen extends StatefulWidget {
  const FeedScreen({super.key, required this.repository});
  final StrollRepository repository;

  @override
  State<FeedScreen> createState() => _FeedScreenState();
}

class _FeedScreenState extends State<FeedScreen> {
  final List<String> _chips = ['For You', 'Nearby', 'Trending', 'Food', 'Nightlife'];
  int _selectedChip = 0;
  final TextEditingController _searchController = TextEditingController();
  bool _isSearching = false;
  String? _aiSummary;
  List<ActivityModel> _activities = [];
  bool _isLoadingFeed = true;
  bool _feedError = false;
  String _errorMessage = '';

  @override
  void initState() {
    super.initState();
    _loadFeed();
  }

  Future<void> _loadFeed() async {
    setState(() { _isLoadingFeed = true; _feedError = false; });
    try {
      final feed = await widget.repository.getFeed();
      setState(() {
        _activities = feed.recommendations;
        _aiSummary = null;
        _isLoadingFeed = false;
      });
    } catch (e) {
      setState(() {
        _feedError = true;
        _errorMessage = e.toString();
        _isLoadingFeed = false;
      });
    }
  }

  Future<void> _searchPlaces(String query) async {
    if (query.trim().isEmpty) return;
    setState(() { _isSearching = true; _aiSummary = null; });
    try {
      final result = await widget.repository.processVoiceQuery(query: query);
      setState(() {
        _activities = result.activities;
        _aiSummary = result.summary;
        _isSearching = false;
      });
    } catch (e) {
      setState(() {
        _isSearching = false;
        _aiSummary = 'Search failed: $e';
      });
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1A1122),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── AI Search Header ──
            Container(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'PULSE',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'AI-powered city discovery',
                    style: TextStyle(color: Color(0xFFAD92C9), fontSize: 14),
                  ),
                  const SizedBox(height: 12),
                  // Search Bar
                  Container(
                    decoration: BoxDecoration(
                      color: const Color(0xFF2A1B3D),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: const Color(0xFF7F13EC).withOpacity(0.4)),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(width: 16),
                        Icon(Icons.auto_awesome, color: const Color(0xFF7F13EC), size: 22),
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(color: Colors.white, fontSize: 16),
                            decoration: const InputDecoration(
                              hintText: 'Ask AI... "best ramen near me"',
                              hintStyle: TextStyle(color: Color(0xFF8B6DAD), fontSize: 15),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.symmetric(vertical: 14),
                            ),
                            onSubmitted: _searchPlaces,
                          ),
                        ),
                        _isSearching
                          ? const Padding(
                              padding: EdgeInsets.all(12),
                              child: SizedBox(
                                width: 20, height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Color(0xFF7F13EC),
                                ),
                              ),
                            )
                          : IconButton(
                              icon: const Icon(Icons.send_rounded, color: Color(0xFF7F13EC)),
                              onPressed: () => _searchPlaces(_searchController.text),
                            ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            // ── AI Summary Card ──
            if (_aiSummary != null)
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      const Color(0xFF7F13EC).withOpacity(0.2),
                      const Color(0xFF2A1B3D),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFF7F13EC).withOpacity(0.3)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.auto_awesome, color: Color(0xFF7F13EC), size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _aiSummary!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Filter Chips ──
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: List.generate(_chips.length, (index) {
                  final isSelected = _selectedChip == index;
                  return Padding(
                    padding: const EdgeInsets.only(right: 10),
                    child: GestureDetector(
                      onTap: () {
                        setState(() => _selectedChip = index);
                        if (index == 0) {
                          _loadFeed();
                        } else {
                          _searchPlaces(_chips[index]);
                        }
                      },
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        height: 36,
                        padding: const EdgeInsets.symmetric(horizontal: 18),
                        decoration: BoxDecoration(
                          color: isSelected ? const Color(0xFF7F13EC) : const Color(0xFF362348),
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: isSelected ? [
                            BoxShadow(
                              color: const Color(0xFF7F13EC).withOpacity(0.4),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ] : null,
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          _chips[index],
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
                          ),
                        ),
                      ),
                    ),
                  );
                }),
              ),
            ),

            // ── Results Count ──
            if (!_isLoadingFeed && !_feedError && _activities.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Text(
                  '${_activities.length} places found',
                  style: const TextStyle(color: Color(0xFF8B6DAD), fontSize: 13),
                ),
              ),

            // ── Activity Cards ──
            Expanded(
              child: _isLoadingFeed
                ? const Center(child: CircularProgressIndicator(color: Color(0xFF7F13EC)))
                : _feedError
                  ? Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.cloud_off, color: Color(0xFFAD92C9), size: 48),
                          const SizedBox(height: 12),
                          Text(
                            'Could not load feed',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _errorMessage,
                            style: const TextStyle(color: Color(0xFFAD92C9), fontSize: 12),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _loadFeed,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: const Color(0xFF7F13EC),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                            ),
                            child: const Text('Retry', style: TextStyle(color: Colors.white)),
                          ),
                        ],
                      ),
                    )
                  : _activities.isEmpty
                    ? const Center(
                        child: Text(
                          'No places found. Try a different search!',
                          style: TextStyle(color: Color(0xFFAD92C9)),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                        itemCount: _activities.length,
                        itemBuilder: (context, index) {
                          final activity = _activities[index];
                          return _buildActivityCard(activity);
                        },
                      ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildActivityCard(ActivityModel activity) {
    final imageUrl = activity.images.isNotEmpty
        ? activity.images.first
        : 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=800&q=80';

    return Container(
      margin: const EdgeInsets.only(bottom: 20),
      decoration: BoxDecoration(
        color: const Color(0xFF2A1B3D),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: const Color(0xFF362348)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Image
          AspectRatio(
            aspectRatio: 16 / 9,
            child: Image.network(
              imageUrl,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: const Color(0xFF362348),
                child: const Center(
                  child: Icon(Icons.restaurant, color: Color(0xFF7F13EC), size: 48),
                ),
              ),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Name + Rating row
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        activity.name,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (activity.rating > 0) ...[
                      const Icon(Icons.star_rounded, color: Color(0xFFFFD700), size: 18),
                      const SizedBox(width: 4),
                      Text(
                        activity.rating.toStringAsFixed(1),
                        style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 6),

                // Description
                Text(
                  activity.description,
                  style: const TextStyle(color: Color(0xFFAD92C9), fontSize: 14, height: 1.4),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 8),

                // Meta info row
                Wrap(
                  spacing: 12,
                  children: [
                    if (activity.distance != null && activity.distance!.isNotEmpty)
                      _metaChip(Icons.near_me_rounded, activity.distance!, color: const Color(0xFF33CCFF)),
                    if (activity.reviewCount > 0)
                      _metaChip(Icons.people_outline, '${activity.reviewCount} reviews'),
                    if (activity.priceLevel > 0)
                      _metaChip(Icons.attach_money, '\$' * activity.priceLevel),
                    if (activity.isOpen)
                      _metaChip(Icons.schedule, 'Open now', color: Colors.green),
                  ],
                ),

                // "Why recommended" badge
                if (activity.whyRecommended != null && activity.whyRecommended!.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: const Color(0xFF7F13EC).withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.auto_awesome, size: 14, color: Color(0xFF7F13EC)),
                        const SizedBox(width: 6),
                        Flexible(
                          child: Text(
                            activity.whyRecommended!,
                            style: const TextStyle(color: Color(0xFFCBB3E8), fontSize: 12),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                const SizedBox(height: 12),

                // Navigation Buttons
                Row(
                  children: [
                    Expanded(
                      child: _navButton(
                        icon: Icons.navigation_rounded,
                        label: 'Waze',
                        color: const Color(0xFF33CCFF),
                        onTap: () async {
                          final url = Uri.parse(
                            'https://waze.com/ul?ll=${activity.location.lat},${activity.location.lng}&navigate=yes',
                          );
                          if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _navButton(
                        icon: Icons.map_rounded,
                        label: 'Maps',
                        color: const Color(0xFF4CAF50),
                        onTap: () async {
                          final url = Uri.parse(
                            'https://www.google.com/maps/search/?api=1&query=${activity.location.lat},${activity.location.lng}',
                          );
                          if (await canLaunchUrl(url)) await launchUrl(url, mode: LaunchMode.externalApplication);
                        },
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: _navButton(
                        icon: Icons.bookmark_add_outlined,
                        label: 'Save',
                        color: const Color(0xFF7F13EC),
                        onTap: () {
                          widget.repository.saveActivity(activity.id);
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Saved ${activity.name}'),
                              backgroundColor: const Color(0xFF7F13EC),
                              duration: const Duration(seconds: 1),
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _metaChip(IconData icon, String label, {Color color = const Color(0xFFAD92C9)}) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: color),
        const SizedBox(width: 4),
        Text(label, style: TextStyle(color: color, fontSize: 12)),
      ],
    );
  }

  Widget _navButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: color.withOpacity(0.15),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: color.withOpacity(0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(label, style: TextStyle(color: color, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}
