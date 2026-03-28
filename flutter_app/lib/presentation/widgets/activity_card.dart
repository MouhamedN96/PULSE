import 'package:flutter/material.dart';

import '../../data/stroll_models.dart';

class ActivityCard extends StatefulWidget {
  const ActivityCard({
    super.key,
    required this.activity,
    this.compact = false,
    this.onSave,
  });

  const ActivityCard.compact({
    super.key,
    required this.activity,
    this.onSave,
  }) : compact = true;

  final ActivityModel activity;
  final bool compact;
  final Future<void> Function(ActivityModel activity)? onSave;

  @override
  State<ActivityCard> createState() => _ActivityCardState();
}

class _ActivityCardState extends State<ActivityCard> {
  bool _isSaved = false;

  @override
  Widget build(BuildContext context) {
    if (widget.compact) {
      return _buildCompactCard(context);
    }
    return _buildFullCard(context);
  }

  Widget _buildCompactCard(BuildContext context) {
    final activity = widget.activity;

    return Container(
      width: 280,
      margin: const EdgeInsets.only(right: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Image.network(
                activity.images.isNotEmpty
                    ? activity.images.first
                    : 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=400&h=300&fit=crop',
                height: 120,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
              Positioned(
                top: 8,
                right: 8,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.9),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.star, size: 14, color: Colors.amber),
                      const SizedBox(width: 2),
                      Text(
                        activity.rating.toStringAsFixed(1),
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (activity.isOpen)
                Positioned(
                  bottom: 8,
                  left: 8,
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Text(
                      'Open',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  activity.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Text(
                  activity.category,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      activity.distance ?? '-',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    Text(
                      '💰' * activity.priceLevel.clamp(1, 4),
                      style: const TextStyle(fontSize: 12),
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

  Widget _buildFullCard(BuildContext context) {
    final activity = widget.activity;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Stack(
            children: [
              Image.network(
                activity.images.isNotEmpty
                    ? activity.images.first
                    : 'https://images.unsplash.com/photo-1517248135467-4c7edcad34c4?w=400&h=300&fit=crop',
                height: 200,
                width: double.infinity,
                fit: BoxFit.cover,
              ),
              Positioned(
                top: 12,
                right: 12,
                child: IconButton(
                  onPressed: () async {
                    setState(() => _isSaved = !_isSaved);
                    await widget.onSave?.call(activity);
                  },
                  icon: Icon(_isSaved ? Icons.bookmark : Icons.bookmark_border),
                  style: IconButton.styleFrom(
                    backgroundColor: Colors.white.withOpacity(0.9),
                  ),
                ),
              ),
              Positioned(
                bottom: 12,
                left: 12,
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.9),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star, size: 16, color: Colors.amber),
                          const SizedBox(width: 4),
                          Text(
                            '${activity.rating.toStringAsFixed(1)} (${activity.reviewCount})',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (activity.isOpen)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.green,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text(
                          'Open Now',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            activity.name,
                            style: const TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              Icon(Icons.location_on, size: 14, color: Colors.grey.shade600),
                              const SizedBox(width: 4),
                              Text(
                                '${activity.location.neighborhood} • ${activity.distance ?? '-'}',
                                style: TextStyle(
                                  color: Colors.grey.shade600,
                                  fontSize: 14,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '💰' * activity.priceLevel.clamp(1, 4),
                      style: const TextStyle(fontSize: 18),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                if (activity.aiSummary != null && activity.aiSummary!.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(context).colorScheme.primary.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: Theme.of(context).colorScheme.primary.withOpacity(0.2),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 16,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              'AI Insight',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).colorScheme.primary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          activity.aiSummary!,
                          style: TextStyle(
                            color: Colors.grey.shade700,
                            fontSize: 14,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                if (activity.aiSummary != null && activity.aiSummary!.isNotEmpty)
                  const SizedBox(height: 12),
                if (activity.whyRecommended != null && activity.whyRecommended!.isNotEmpty)
                  Text(
                    'Why recommended: ${activity.whyRecommended!}',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 14,
                    ),
                  ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: activity.tags
                      .map(
                        (tag) => Chip(
                          label: Text('#$tag'),
                          backgroundColor: Colors.grey.shade100,
                          padding: EdgeInsets.zero,
                          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Icon(Icons.access_time, size: 16, color: Colors.grey.shade600),
                    const SizedBox(width: 4),
                    Expanded(
                      child: Text(
                        activity.openHours,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    if (activity.phone != null)
                      OutlinedButton.icon(
                        onPressed: () {},
                        icon: const Icon(Icons.phone, size: 16),
                        label: const Text('Call'),
                      ),
                    const SizedBox(width: 8),
                    ElevatedButton.icon(
                      onPressed: () {},
                      icon: const Icon(Icons.navigation, size: 16),
                      label: const Text('Directions'),
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
}
