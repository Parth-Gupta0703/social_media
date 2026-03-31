// User tile widget and role/status badge widgets used in the admin user list.

import 'package:flutter/material.dart';

import 'user_model.dart';

// ── User tile ─────────────────────────────────────────────────────────────────

class UserTile extends StatelessWidget {
  const UserTile({
    super.key,
    required this.user,
    required this.myEmail,
    required this.cardColor,
    required this.textColor,
    required this.mutedColor,
    required this.borderColor,
    required this.onAction,
  });

  final AdminUser user;
  final String myEmail;
  final Color cardColor;
  final Color textColor;
  final Color mutedColor;
  final Color borderColor;
  final void Function(UserAction) onAction;

  bool get _isMe => user.email == myEmail;
  bool get _isAdmin => user.role == 'admin';
  bool get _isBanned => user.status == 'banned';
  bool get _hasProfile => user.ref != null;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: _isBanned
              ? const Color(0xFFFF6B6B)
              : _isAdmin
                  ? const Color(0xFF6C63FF).withValues(alpha: 0.5)
                  : borderColor,
        ),
      ),
      child: Row(
        children: [
          // ── Avatar ───────────────────────────────────────────────────────
          Stack(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: _isAdmin
                    ? const Color(0xFF6C63FF)
                    : const Color(0xFF00B4D8),
                child: Text(
                  user.email.isNotEmpty ? user.email[0].toUpperCase() : '?',
                  style: const TextStyle(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ),
              if (_isAdmin)
                Positioned(
                  bottom: 0,
                  right: 0,
                  child: Container(
                    width: 14,
                    height: 14,
                    decoration: const BoxDecoration(
                        color: Color(0xFF6C63FF), shape: BoxShape.circle),
                    child: const Icon(Icons.star_rounded,
                        color: Colors.white, size: 9),
                  ),
                ),
            ],
          ),
          const SizedBox(width: 12),

          // ── Info ─────────────────────────────────────────────────────────
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(user.email,
                          style: TextStyle(
                              color: textColor,
                              fontWeight: FontWeight.w700,
                              fontSize: 13),
                          overflow: TextOverflow.ellipsis),
                    ),
                    if (_isMe)
                      Container(
                        margin: const EdgeInsets.only(left: 6),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 7, vertical: 2),
                        decoration: BoxDecoration(
                          color: const Color(0xFF6C63FF).withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: const Text('You',
                            style: TextStyle(
                                color: Color(0xFF6C63FF),
                                fontSize: 10,
                                fontWeight: FontWeight.w700)),
                      ),
                  ],
                ),
                if (user.username.isNotEmpty)
                  Text('@${user.username}',
                      style: TextStyle(color: mutedColor, fontSize: 12)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    RoleBadge(
                        role: _isAdmin ? 'Admin' : 'Member',
                        isAdmin: _isAdmin),
                    if (_isBanned) const StatusBadge('Banned'),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),

          // ── Action menu ──────────────────────────────────────────────────
          _buildActionMenu(),
        ],
      ),
    );
  }

  Widget _buildActionMenu() {
    if (!_hasProfile) {
      return Tooltip(
        message:
            'User found in posts but has no profile document in Users collection',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: const Color(0xFFFFB84D).withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(20),
            border:
                Border.all(color: const Color(0xFFFFB84D).withValues(alpha: 0.4)),
          ),
          child: const Text('Not registered',
              style: TextStyle(
                  color: Color(0xFFB07A00),
                  fontSize: 10,
                  fontWeight: FontWeight.w600)),
        ),
      );
    }

    final items = <PopupMenuItem<UserAction>>[];

    items.add(const PopupMenuItem(
      value: UserAction.viewDetails,
      child: Row(children: [
        Icon(Icons.info_outline_rounded, size: 16, color: Color(0xFF677489)),
        SizedBox(width: 8),
        Text('View full details'),
      ]),
    ));

    if (!_isMe) {
      if (_isAdmin) {
        items.add(const PopupMenuItem(
          value: UserAction.demoteFromAdmin,
          child: Row(children: [
            Icon(Icons.arrow_downward_rounded,
                size: 16, color: Color(0xFFFF9F43)),
            SizedBox(width: 8),
            Text('Demote to member'),
          ]),
        ));
      } else {
        items.add(const PopupMenuItem(
          value: UserAction.promoteToAdmin,
          child: Row(children: [
            Icon(Icons.arrow_upward_rounded,
                size: 16, color: Color(0xFF6C63FF)),
            SizedBox(width: 8),
            Text('Promote to admin'),
          ]),
        ));

        if (_isBanned) {
          items.add(const PopupMenuItem(
            value: UserAction.unbanUser,
            child: Row(children: [
              Icon(Icons.lock_open_rounded,
                  size: 16, color: Color(0xFF00C49A)),
              SizedBox(width: 8),
              Text('Unban user'),
            ]),
          ));
        } else {
          items.add(const PopupMenuItem(
            value: UserAction.banUser,
            child: Row(children: [
              Icon(Icons.block_rounded, size: 16, color: Color(0xFFFF6B6B)),
              SizedBox(width: 8),
              Text('Ban user',
                  style: TextStyle(color: Color(0xFFFF6B6B))),
            ]),
          ));
        }

        items.add(const PopupMenuItem(
          value: UserAction.removeUserData,
          child: Row(children: [
            Icon(Icons.delete_forever_rounded,
                size: 16, color: Color(0xFFFF6B6B)),
            SizedBox(width: 8),
            Text('Remove all user data',
                style: TextStyle(color: Color(0xFFFF6B6B))),
          ]),
        ));
      }
    }

    return PopupMenuButton<UserAction>(
      onSelected: onAction,
      itemBuilder: (_) => items,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      icon: const Icon(Icons.more_vert_rounded, size: 20),
    );
  }
}

// ── Badge widgets ─────────────────────────────────────────────────────────────

class RoleBadge extends StatelessWidget {
  const RoleBadge({super.key, required this.role, required this.isAdmin});
  final String role;
  final bool isAdmin;

  @override
  Widget build(BuildContext context) {
    final color = isAdmin ? const Color(0xFF6C63FF) : const Color(0xFF00B4D8);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(role,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w700)),
    );
  }
}

class StatusBadge extends StatelessWidget {
  const StatusBadge(this.label, {super.key});
  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: const Color(0xFFFF6B6B).withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: const TextStyle(
              color: Color(0xFFFF6B6B),
              fontSize: 10,
              fontWeight: FontWeight.w700)),
    );
  }
}
