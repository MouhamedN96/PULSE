import 'package:flutter/material.dart';

import '../../data/stroll_models.dart';

class PostCard extends StatefulWidget {
  const PostCard({
    super.key,
    required this.post,
  });

  final PostModel post;

  @override
  State<PostCard> createState() => _PostCardState();
}

class _PostCardState extends State<PostCard> {
  late bool _isLiked;
  late int _likes;

  @override
  void initState() {
    super.initState();
    _isLiked = widget.post.isLiked;
    _likes = widget.post.likes;
  }

  @override
  Widget build(BuildContext context) {
    final post = widget.post;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundImage: NetworkImage(post.user.avatar),
                  radius: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        post.user.name,
                        style: const TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      Text(
                        post.timestamp,
                        style: TextStyle(
                          color: Colors.grey.shade600,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.more_horiz),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              post.caption,
              style: const TextStyle(fontSize: 14),
            ),
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Stack(
                children: [
                  Image.network(
                    post.image,
                    height: 240,
                    width: double.infinity,
                    fit: BoxFit.cover,
                  ),
                  Positioned(
                    bottom: 0,
                    left: 0,
                    right: 0,
                    child: Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            Colors.black.withOpacity(0.7),
                            Colors.transparent,
                          ],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            post.activity.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            post.activity.location.neighborhood,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.8),
                              fontSize: 14,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                IconButton(
                  onPressed: () {
                    setState(() {
                      _isLiked = !_isLiked;
                      _likes += _isLiked ? 1 : -1;
                    });
                  },
                  icon: Icon(
                    _isLiked ? Icons.favorite : Icons.favorite_border,
                    color: _isLiked ? Colors.red : null,
                  ),
                ),
                Text('$_likes'),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.chat_bubble_outline),
                ),
                Text('${post.comments}'),
                const SizedBox(width: 16),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.share),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () {},
                  icon: const Icon(Icons.bookmark_border),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
