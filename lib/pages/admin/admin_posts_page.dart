// Admin Posts Page — entry point.
// Post card widget is split into a posts/ subfolder for clarity:
//
//   posts/post_card.dart — PostCard, PostActionButton, PostDeleteButton

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import 'admin_dashboard.dart';
import 'posts/post_card.dart';

// ── Filter enum ───────────────────────────────────────────────────────────────

enum _PostFilter {
  all, // All posts
  liked, // Posts with 1+ likes (popular/viral)
  noLikes, // Posts with 0 likes (new or potential spam)
}

// ── Page ──────────────────────────────────────────────────────────────────────

class AdminPostsPage extends StatefulWidget {
  const AdminPostsPage({super.key});

  @override
  State<AdminPostsPage> createState() => _AdminPostsPageState();
}

class _AdminPostsPageState extends State<AdminPostsPage> {
  String _searchQuery = '';
  int _totalPosts = 0;
  _PostFilter _filter = _PostFilter.all;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [Color(0xFFDDF2FF), Color(0xFFFFEAF2)],
          ),
        ),
        child: NestedScrollView(
          headerSliverBuilder: (context, _) => [
            SliverAppBar(
              expandedHeight: 150,
              floating: false,
              pinned: true,
              backgroundColor: Colors.white,
              elevation: 0,
              flexibleSpace: FlexibleSpaceBar(
                background: AdminPageHeader(
                  title: 'Content Manager',
                  subtitle: '$_totalPosts posts total',
                  iconData: Icons.article_rounded,
                  fromColor: const Color(0xFF00B4D8),
                  toColor: const Color(0xFFFF8FAB),
                ),
              ),
            ),
          ],
          body: Column(
            children: [
              _buildFilters(),
              Expanded(child: _buildPostList()),
            ],
          ),
        ),
      ),
    );
  }

  // ── Filters ─────────────────────────────────────────────────────────────────

  Widget _buildFilters() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            style: const TextStyle(color: Color(0xFF2D3142)),
            decoration: InputDecoration(
              hintText: 'Search posts by content or author…',
              hintStyle: const TextStyle(color: Color(0xFF7D8A9C)),
              prefixIcon: const Icon(
                Icons.search_rounded,
                color: Color(0xFF7D8A9C),
              ),
              suffixIcon: _searchQuery.isNotEmpty
                  ? IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Color(0xFF7D8A9C),
                        size: 18,
                      ),
                      onPressed: () => setState(() => _searchQuery = ''),
                    )
                  : null,
              filled: true,
              fillColor: Colors.white,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFD7DCE5)),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: Color(0xFFD7DCE5)),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(
                  color: Color(0xFF00B4D8),
                  width: 1.5,
                ),
              ),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 14,
              ),
            ),
            onChanged: (v) =>
                setState(() => _searchQuery = v.trim().toLowerCase()),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Tooltip(
                message: 'Show all posts regardless of engagement',
                child: _chip('All', _PostFilter.all),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message:
                    'Posts with 1+ likes — popular or viral content worth monitoring',
                child: _chip('With likes', _PostFilter.liked),
              ),
              const SizedBox(width: 8),
              Tooltip(
                message:
                    'Posts with 0 likes — new content or potential spam to review',
                child: _chip('No likes', _PostFilter.noLikes),
              ),
            ],
          ),
          if (_filter != _PostFilter.all) ...[
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: const Color(0xFF00B4D8).withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: const Color(0xFF00B4D8).withValues(alpha: 0.3),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 13,
                    color: Color(0xFF007B97),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    _filter == _PostFilter.liked
                        ? 'Showing engaged posts — useful for identifying trending content'
                        : 'Showing zero-engagement posts — useful for spam checks',
                    style: const TextStyle(
                      color: Color(0xFF007B97),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _chip(String label, _PostFilter filter) {
    final selected = _filter == filter;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => setState(() => _filter = filter),
      side: BorderSide(
        color: selected ? const Color(0xFF00B4D8) : const Color(0xFFD7DCE5),
      ),
      backgroundColor: Colors.white,
      selectedColor: const Color(0xFFE4F8FF),
      labelStyle: TextStyle(
        color: selected ? const Color(0xFF007B97) : const Color(0xFF677489),
        fontWeight: FontWeight.w600,
        fontSize: 12,
      ),
    );
  }

  // ── Post list ────────────────────────────────────────────────────────────────

  Widget _buildPostList() {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: FirebaseFirestore.instance
          .collection('UserPosts')
          .orderBy('TimeStamp', descending: true)
          .snapshots(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting && !snap.hasData) {
          return const Center(
            child: CircularProgressIndicator(color: Color(0xFF00B4D8)),
          );
        }

        var posts = snap.data?.docs ?? const [];

        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted && _totalPosts != posts.length) {
            setState(() => _totalPosts = posts.length);
          }
        });

        if (_searchQuery.isNotEmpty) {
          posts = posts.where((doc) {
            final data = doc.data();
            final msg = _str(data, ['Message', 'Text']).toLowerCase();
            final email = _str(data, ['UserEmail', 'email']).toLowerCase();
            return msg.contains(_searchQuery) || email.contains(_searchQuery);
          }).toList();
        }

        if (_filter != _PostFilter.all) {
          posts = posts.where((doc) {
            final likes = _count(doc.data()['Likes']);
            return _filter == _PostFilter.liked ? likes > 0 : likes == 0;
          }).toList();
        }

        if (posts.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.article_outlined,
                  size: 60,
                  color: const Color(0xFF7D8A9C).withValues(alpha: 0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  _searchQuery.isNotEmpty
                      ? 'No posts matching "$_searchQuery"'
                      : 'No posts in this view',
                  style: const TextStyle(
                    color: Color(0xFF677489),
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          );
        }

        return ListView.separated(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
          itemCount: posts.length,
          separatorBuilder: (_, __) => const SizedBox(height: 10),
          itemBuilder: (context, i) => PostCard(doc: posts[i]),
        );
      },
    );
  }

  // ── Static helpers ───────────────────────────────────────────────────────────

  static String _str(
    Map<String, dynamic> data,
    List<String> keys, {
    String fallback = '',
  }) {
    for (final key in keys) {
      final v = data[key];
      if (v == null) continue;
      final t = v.toString().trim();
      if (t.isNotEmpty) return t;
    }
    return fallback;
  }

  static int _count(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is Iterable) return value.length;
    if (value is Map) return value.length;
    return int.tryParse(value.toString()) ?? 0;
  }
}
