import 'package:flutter/material.dart';

import '../../data/stroll_models.dart';

class UserCard extends StatelessWidget {
  const UserCard({
    super.key,
    required this.user,
    this.isFollowing = false,
    this.onFollow,
    this.onUnfollow,
  });

  final UserModel user;
  final bool isFollowing;
  final VoidCallback? onFollow;
  final VoidCallback? onUnfollow;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade200),
      ),
      child: Row(
        children: [
          CircleAvatar(
            backgroundImage: NetworkImage(user.avatar),
            radius: 24,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user.bio,
                  style: TextStyle(
                    color: Colors.grey.shade600,
                    fontSize: 12,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      '${user.followers} followers',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${user.checkins} check-ins',
                      style: TextStyle(
                        color: Colors.grey.shade600,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          if (isFollowing)
            OutlinedButton.icon(
              onPressed: onUnfollow,
              icon: const Icon(Icons.check, size: 16),
              label: const Text('Following'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            )
          else
            ElevatedButton.icon(
              onPressed: onFollow,
              icon: const Icon(Icons.add, size: 16),
              label: const Text('Follow'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 12),
              ),
            ),
        ],
      ),
    );
  }
}
