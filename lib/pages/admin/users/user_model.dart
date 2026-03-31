// Data model and action enum for admin user management.

import 'package:cloud_firestore/cloud_firestore.dart';

/// The moderation actions an admin can take on a user.
enum UserAction {
  viewDetails,
  promoteToAdmin,
  demoteFromAdmin,
  banUser,
  unbanUser,
  removeUserData,
}

/// Represents a user entry displayed in the admin user management list.
class AdminUser {
  const AdminUser({
    required this.email,
    required this.username,
    required this.role,
    required this.status,
    required this.ref,
    required this.banReason,
    required this.bannedAt,
    required this.postCount,
  });

  final String email;
  final String username;
  final String role;    // 'admin' | 'user'
  final String status;  // 'active' | 'banned'
  final DocumentReference<Map<String, dynamic>>? ref;
  final String banReason;
  final Timestamp? bannedAt;
  final int? postCount;
}
