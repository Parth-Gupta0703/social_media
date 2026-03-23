// Admin User Management Page
// Logic is split across a users/ subfolder:
//   users/user_model.dart    — AdminUser data class + UserAction enum
//   users/user_tile.dart     — UserTile, RoleBadge, StatusBadge widgets
//   users/user_actions.dart  — dialogs, Firestore helpers, details sheet

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'admin_dashboard.dart';
import 'users/user_actions.dart';
import 'users/user_model.dart';
import 'users/user_tile.dart';

class AdminUsersPage extends StatefulWidget {
  const AdminUsersPage({super.key});

  @override
  State<AdminUsersPage> createState() => _AdminUsersPageState();
}

class _AdminUsersPageState extends State<AdminUsersPage>
    with SingleTickerProviderStateMixin {
  String _searchQuery = '';
  late TabController _tabController;
  String _filterRole = 'all';

  String get _myEmail =>
      FirebaseAuth.instance.currentUser?.email ?? 'admin@safespot.local';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      setState(() {
        _filterRole = switch (_tabController.index) {
          1 => 'admin',
          2 => 'user',
          _ => 'all',
        };
      });
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark ? const Color(0xFF0F1220) : const Color(0xFFF3F6FF);
    final card = isDark ? const Color(0xFF1A1F34) : Colors.white;
    final text = isDark ? const Color(0xFFE7EDFF) : const Color(0xFF2D3142);
    final muted = isDark ? const Color(0xFF9CACCF) : const Color(0xFF667086);
    final border = isDark ? const Color(0xFF2B3656) : const Color(0xFFD6DCEE);

    return Scaffold(
      backgroundColor: bg,
      body: NestedScrollView(
        headerSliverBuilder: (_, __) => [
          SliverAppBar(
            expandedHeight: 160,
            pinned: true,
            backgroundColor: isDark
                ? const Color(0xFF151C31)
                : const Color(0xFFE7EDFF),
            flexibleSpace: FlexibleSpaceBar(
              background: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('Users')
                    .snapshots(),
                builder: (context, snap) {
                  final docs = snap.data?.docs ?? const [];
                  final admins = docs
                      .where(
                        (d) =>
                            (d.data()['role'] ?? '').toString().toLowerCase() ==
                            'admin',
                      )
                      .length;
                  final banned = docs
                      .where(
                        (d) =>
                            (d.data()['status'] ?? '')
                                .toString()
                                .toLowerCase() ==
                            'banned',
                      )
                      .length;
                  return AdminPageHeader(
                    title: 'User Management',
                    subtitle:
                        '${docs.length} total · $admins admins · $banned banned',
                    iconData: Icons.people_rounded,
                    fromColor: const Color(0xFF6C63FF),
                    toColor: const Color(0xFFFF8FAB),
                  );
                },
              ),
            ),
            bottom: TabBar(
              controller: _tabController,
              indicatorColor: const Color(0xFF6C63FF),
              labelColor: const Color(0xFF6C63FF),
              unselectedLabelColor: muted,
              tabs: const [
                Tab(text: 'All'),
                Tab(text: 'Admins'),
                Tab(text: 'Members'),
              ],
            ),
          ),
        ],
        body: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: TextField(
                style: TextStyle(color: text),
                onChanged: (v) =>
                    setState(() => _searchQuery = v.trim().toLowerCase()),
                decoration: InputDecoration(
                  hintText: 'Search by email or username…',
                  hintStyle: TextStyle(color: muted),
                  prefixIcon: Icon(Icons.search_rounded, color: muted),
                  suffixIcon: _searchQuery.isNotEmpty
                      ? IconButton(
                          icon: Icon(Icons.close_rounded, color: muted),
                          onPressed: () => setState(() => _searchQuery = ''),
                        )
                      : null,
                  filled: true,
                  fillColor: card,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: BorderSide(color: border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(14),
                    borderSide: const BorderSide(color: Color(0xFF6C63FF)),
                  ),
                ),
              ),
            ),
            Expanded(
              child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('Users')
                    .snapshots(),
                builder: (context, snap) {
                  if (snap.connectionState == ConnectionState.waiting &&
                      !snap.hasData) {
                    return const Center(child: CircularProgressIndicator());
                  }

                  final users = <AdminUser>[];
                  for (final doc in snap.data?.docs ?? const []) {
                    final data = doc.data();
                    final email = (data['email'] ?? '')
                        .toString()
                        .trim()
                        .toLowerCase();
                    if (!email.contains('@')) continue;
                    final role =
                        (data['role'] ?? '').toString().toLowerCase() == 'admin'
                        ? 'admin'
                        : 'user';
                    final status =
                        (data['status'] ?? '').toString().toLowerCase() ==
                            'banned'
                        ? 'banned'
                        : 'active';

                    if (_filterRole != 'all' && role != _filterRole) continue;
                    if (_searchQuery.isNotEmpty &&
                        !email.contains(_searchQuery) &&
                        !(data['username'] ?? '')
                            .toString()
                            .toLowerCase()
                            .contains(_searchQuery))
                      continue;

                    users.add(
                      AdminUser(
                        email: email,
                        username: (data['username'] ?? '').toString(),
                        role: role,
                        status: status,
                        ref: doc.reference,
                        banReason: (data['banReason'] ?? '').toString(),
                        bannedAt: data['bannedAt'] as Timestamp?,
                        postCount: null,
                      ),
                    );
                  }
                  users.sort((a, b) => a.email.compareTo(b.email));

                  if (users.isEmpty) {
                    return Center(
                      child: Text(
                        'No users found',
                        style: TextStyle(color: muted),
                      ),
                    );
                  }

                  return ListView.separated(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 20),
                    itemCount: users.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (_, i) => UserTile(
                      user: users[i],
                      myEmail: _myEmail,
                      cardColor: card,
                      textColor: text,
                      mutedColor: muted,
                      borderColor: border,
                      onAction: (action) => _handleAction(users[i], action),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─────────────────────────────────────────────────────────────────────────
  // ACTION HANDLER
  //
  // KEY RULE: Before every `await`, capture what you need from `context`
  // into a local variable. After every `await`, check `mounted` before
  // touching `context` again.
  //
  // Why: When a dialog closes, Flutter may rebuild/dispose inherited widgets.
  // Any `context` access (Navigator, ScaffoldMessenger, Theme, etc.) after
  // an await without a mounted-check causes the
  // "_dependents.isEmpty is not true" assertion = red screen crash.
  // ─────────────────────────────────────────────────────────────────────────
  Future<void> _handleAction(AdminUser user, UserAction action) async {
    // ── Capture BEFORE any await ─────────────────────────────────────────
    // These are safe to hold across awaits because they don't depend on the
    // widget tree being alive — they are just Dart objects.
    final messenger = ScaffoldMessenger.maybeOf(context);
    final nav = Navigator.maybeOf(context);

    // Local helper that uses the pre-captured messenger (safe after awaits)
    void snack(String msg) {
      messenger?.showSnackBar(
        SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating),
      );
    }

    switch (action) {
      // ── View details ────────────────────────────────────────────────────
      case UserAction.viewDetails:
        // Single await, context used before it — safe.
        await showUserDetailsSheet(
          context,
          email: user.email,
          username: user.username,
          role: user.role,
          status: user.status,
          banReason: user.banReason,
          bannedAt: user.bannedAt,
        );
        return;

      // ── Promote to admin ────────────────────────────────────────────────
      case UserAction.promoteToAdmin:
        if (user.ref == null) {
          snack('Cannot promote unregistered user.');
          return;
        }
        // Single dialog await — context is still alive here
        final confirmed = await showUserConfirmDialog(
          context,
          title: 'Promote to Admin?',
          message: 'Grant full admin access to ${user.email}?',
        );
        if (!confirmed) return;
        // After await: use only pre-captured objects or Firestore
        try {
          await user.ref!.update({'role': 'admin'});
          snack('✅ ${user.email} promoted to admin');
        } catch (e) {
          snack('Failed to promote: $e');
        }
        return;

      // ── Demote from admin ───────────────────────────────────────────────
      case UserAction.demoteFromAdmin:
        if (user.ref == null) {
          snack('Cannot demote unregistered user.');
          return;
        }
        if (user.email == _myEmail) {
          snack('⚠️ You cannot demote yourself');
          return;
        }
        final confirmed = await showUserConfirmDialog(
          context,
          title: 'Demote Admin?',
          message: 'Remove admin access from ${user.email}?',
        );
        if (!confirmed) return;
        try {
          await user.ref!.update({'role': 'user'});
          snack('User demoted to member');
        } catch (e) {
          snack('Failed to demote: $e');
        }
        return;

      // ── Ban user ─────────────────────────────────────────────────────────
      // FIX: This action had TWO awaited dialogs back-to-back.
      // After the first dialog (text input) closes, `context` enters a
      // transitional state. Calling showDialog with it immediately causes
      // the "_dependents.isEmpty" crash.
      //
      // Solution: capture `nav` before anything, use `nav.overlay!.context`
      // for the second dialog so we use the Navigator's stable context
      // instead of the widget's potentially-stale one.
      case UserAction.banUser:
        if (user.ref == null) {
          snack('Cannot ban a user without a profile reference.');
          return;
        }

        // Step 1: Ask for ban reason (first dialog)
        // Use widget's context here — it's still alive at this point
        final reason = await showUserTextInputDialog(
          context,
          title: 'Ban Reason',
          hint: 'Why are you banning this user?',
        );

        // Step 2: Check mounted — widget may have rebuilt while dialog was open
        if (!mounted) return;
        if (reason == null || reason.trim().isEmpty) return;

        // Step 3: Confirm dialog — FIX: use `nav!.overlay!.context` which is
        // the Navigator's own stable context, not the widget's context.
        // This survives the dialog transition without causing the assertion.
        final overlayContext = nav?.overlay?.context;
        if (overlayContext == null) return; // navigator gone, abort safely

        final confirmed = await showUserConfirmDialog(
          overlayContext,
          title: 'Ban User?',
          message:
              '${user.email} will be blocked from the app.\nReason: ${reason.trim()}',
        );
        if (!confirmed) return;

        // Step 4: Firestore write + email — no context needed here
        try {
          await user.ref!.update({
            'status': 'banned',
            'banReason': reason.trim(),
            'bannedAt': Timestamp.now(),
            'bannedBy': _myEmail,
          });
          await queueEmail(
            user.email,
            'Your SafeSpot account has been suspended',
            'Your account was suspended.\nReason: ${reason.trim()}\n\nIf you believe this is a mistake, please contact support.',
            fromAdmin: _myEmail,
          );
          snack('🚫 User banned and notification queued');
        } catch (e) {
          snack('Error banning user: $e');
        }
        return;

      // ── Unban user ───────────────────────────────────────────────────────
      case UserAction.unbanUser:
        if (user.ref == null) return;
        final confirmed = await showUserConfirmDialog(
          context,
          title: 'Unban User?',
          message: '${user.email} will regain access to the app.',
        );
        if (!confirmed) return;
        try {
          await user.ref!.update({
            'status': 'active',
            'banReason': FieldValue.delete(),
            'bannedAt': FieldValue.delete(),
            'bannedBy': FieldValue.delete(),
          });
          await queueEmail(
            user.email,
            'Your SafeSpot account has been reactivated',
            'Your account suspension has been lifted. Welcome back!',
            fromAdmin: _myEmail,
          );
          snack('✅ User unbanned');
        } catch (e) {
          snack('Error unbanning user: $e');
        }
        return;

      // ── Change username ──────────────────────────────────────────────────
      // Same two-dialog pattern as banUser — same fix applied.
      case UserAction.changeUsername:
        if (user.ref == null) return;

        final reason = await showUserTextInputDialog(
          context,
          title: 'Request Username Change',
          hint: 'Why should this user change their username?',
        );

        if (!mounted) return;
        if (reason == null || reason.trim().isEmpty) return;

        final overlayCtx = nav?.overlay?.context;
        if (overlayCtx == null) return;

        final confirmed = await showUserConfirmDialog(
          overlayCtx,
          title: 'Send Username Change Request?',
          message: 'An email will be sent to ${user.email}.',
        );
        if (!confirmed) return;

        try {
          await user.ref!.update({
            'usernameChangeRequested': true,
            'usernameChangeReason': reason.trim(),
            'usernameChangeRequestedAt': Timestamp.now(),
            'usernameChangeRequestedBy': _myEmail,
          });
          await queueEmail(
            user.email,
            'Action required: Update your SafeSpot username',
            'An admin has requested you change your username.\nReason: ${reason.trim()}',
            fromAdmin: _myEmail,
          );
          snack('Username change request sent');
        } catch (e) {
          snack('Error: $e');
        }
        return;

      // ── Remove all user data ─────────────────────────────────────────────
      // Single confirm dialog — standard pattern is fine here.
      case UserAction.removeUserData:
        final confirmed = await showUserConfirmDialog(
          context,
          title: 'Remove User Data?',
          message:
              'Permanently deletes all posts, comments, and the profile for ${user.email}. Cannot be undone.',
        );
        if (!confirmed) return;

        try {
          final batch = FirebaseFirestore.instance.batch();
          await collectForDeletion(batch, 'User Posts', user.email);
          await collectForDeletion(batch, 'Moderated Posts', user.email);
          await collectForDeletion(batch, 'Moderated Comments', user.email);
          await batch.commit();

          await deleteCollectionGroup('Comments', user.email);
          await deleteCollectionGroup('Replies', user.email);

          if (user.ref != null) await user.ref!.delete();

          await queueEmail(
            user.email,
            'Your SafeSpot account has been removed',
            'Your account and all associated data have been permanently removed by a SafeSpot admin.',
            fromAdmin: _myEmail,
          );
          snack('User data removed');
        } catch (e) {
          snack('Error removing user data: $e');
        }
        return;
    }
  }
}
