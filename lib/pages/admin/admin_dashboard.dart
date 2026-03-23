import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'admin_overview_page.dart';
import 'admin_users_page.dart';
import 'admin_posts_page.dart';
import 'admin_moderation_page.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key});

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard>
    with SingleTickerProviderStateMixin {
  int _index = 0;
  late AnimationController _fadeController;
  late Animation<double> _fadeAnimation;

  final List<Widget> _pages = const [
    AdminOverviewPage(),
    AdminUsersPage(),
    AdminPostsPage(),
    AdminModerationPage(),
  ];

  final List<_NavItem> _navItems = const [
    _NavItem(Icons.dashboard_rounded, Icons.dashboard_outlined, 'Overview'),
    _NavItem(Icons.people_rounded, Icons.people_outline_rounded, 'Users'),
    _NavItem(Icons.article_rounded, Icons.article_outlined, 'Posts'),
    _NavItem(Icons.shield_rounded, Icons.shield_outlined, 'Moderation'),
  ];

  @override
  void initState() {
    super.initState();
    _fadeController = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 250));
    _fadeAnimation =
        CurvedAnimation(parent: _fadeController, curve: Curves.easeInOut);
    _fadeController.forward();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  void _onTabTap(int index) {
    if (index == _index) return;
    _fadeController.reverse().then((_) {
      setState(() => _index = index);
      _fadeController.forward();
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Scaffold(
      // FIX: No outer AppBar — each page owns its own header via SliverAppBar.
      // The logout button is now in every page header, properly contextualized.
      backgroundColor:
          isDark ? const Color(0xFF0F1220) : const Color(0xFFF4F8FF),
      body: FadeTransition(opacity: _fadeAnimation, child: _pages[_index]),
      bottomNavigationBar: _buildBottomNav(isDark),
    );
  }

  Widget _buildBottomNav(bool isDark) {
    return Container(
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF171D31) : Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.22 : 0.08),
            blurRadius: 16,
            offset: const Offset(0, -2),
          ),
        ],
        border: Border(
          top: BorderSide(
            color: isDark ? const Color(0xFF2A3454) : const Color(0xFFD7DCE5),
          ),
        ),
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: List.generate(_navItems.length, (i) {
              final isSelected = i == _index;
              final item = _navItems[i];
              return GestureDetector(
                onTap: () => _onTabTap(i),
                behavior: HitTestBehavior.opaque,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.symmetric(
                    horizontal: isSelected ? 20 : 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    gradient: isSelected
                        ? const LinearGradient(
                            colors: [Color(0xFF6C63FF), Color(0xFFFF8FAB)])
                        : null,
                    borderRadius: BorderRadius.circular(30),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        isSelected ? item.activeIcon : item.icon,
                        color: isSelected
                            ? Colors.white
                            : (isDark
                                ? const Color(0xFF9BA8CC)
                                : const Color(0xFF677489)),
                        size: 22,
                      ),
                      if (isSelected) ...[
                        const SizedBox(width: 6),
                        Text(
                          item.label,
                          style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.w600,
                              fontSize: 13),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            }),
          ),
        ),
      ),
    );
  }
}

class _NavItem {
  final IconData activeIcon;
  final IconData icon;
  final String label;
  const _NavItem(this.activeIcon, this.icon, this.label);
}

// ─────────────────────────────────────────────────────────────────────────────
// Shared header widget used in every sub-page's SliverAppBar.flexibleSpace.
// Includes a logout button in the trailing position so it's always accessible
// but is clearly part of the page header, not floating over the title.
// ─────────────────────────────────────────────────────────────────────────────
class AdminPageHeader extends StatelessWidget {
  const AdminPageHeader({
    super.key,
    required this.title,
    required this.subtitle,
    required this.iconData,
    required this.fromColor,
    required this.toColor,
    this.extra,
  });

  final String title;
  final String subtitle;
  final IconData iconData;
  final Color fromColor;
  final Color toColor;
  final Widget? extra;

  static void logout(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Row(
          children: [
            Icon(Icons.logout_rounded, color: Color(0xFFFF6B6B)),
            SizedBox(width: 10),
            Text('Logout?', style: TextStyle(fontWeight: FontWeight.w700)),
          ],
        ),
        content: Text(
          'Signed in as:\n${FirebaseAuth.instance.currentUser?.email ?? 'admin'}',
          style: const TextStyle(color: Color(0xFF677489)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel',
                style: TextStyle(color: Color(0xFF677489))),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await FirebaseAuth.instance.signOut();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFFF6B6B),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Logout',
                style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: isDark
              ? [
                  fromColor.withValues(alpha: 0.20),
                  toColor.withValues(alpha: 0.20)
                ]
              : [
                  fromColor.withValues(alpha: 0.15),
                  toColor.withValues(alpha: 0.15)
                ],
        ),
      ),
      padding: const EdgeInsets.fromLTRB(20, 52, 20, 14),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: [fromColor, toColor]),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: toColor.withValues(alpha: 0.35),
                  blurRadius: 10,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Icon(iconData, color: Colors.white, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(title,
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFFE7EDFF)
                          : const Color(0xFF2D3142),
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                    )),
                Text(subtitle,
                    style: TextStyle(
                      color: isDark
                          ? const Color(0xFF9CACCF)
                          : const Color(0xFF677489),
                      fontSize: 12,
                    ),
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (extra != null) ...[const SizedBox(width: 8), extra!],
          const SizedBox(width: 8),
          Tooltip(
            message: 'Logout',
            child: GestureDetector(
              onTap: () => logout(context),
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: const Color(0xFFFF6B6B).withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                      color: const Color(0xFFFF6B6B).withValues(alpha: 0.35)),
                ),
                child: const Icon(Icons.logout_rounded,
                    color: Color(0xFFFF6B6B), size: 18),
              ),
            ),
          ),
        ],
      ),
    );
  }
}