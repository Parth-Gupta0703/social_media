import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:social_media/pages/home_page.dart';
import 'package:social_media/auth/login_or_register.dart';
import 'package:social_media/pages/admin/admin_dashboard.dart';

class Auth extends StatelessWidget {
  const Auth({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        // 🔄 Loading
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // ❌ Not logged in
        if (!snapshot.hasData) {
          return const LoginOrRegister();
        }

        final user = snapshot.data!;

        // 🔥 ROLE CHECK
        return FutureBuilder<DocumentSnapshot>(
          future: FirebaseFirestore.instance
              .collection('Users')
              .doc(user.uid)
              .get(),
          builder: (context, roleSnapshot) {
            if (roleSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final data = roleSnapshot.data?.data() as Map<String, dynamic>?;

            final role = data?['role'] ?? 'user';
            final status = (data?['status'] ?? 'active')
                .toString()
                .toLowerCase();
            final banReason = (data?['banReason'] ?? '').toString().trim();

            if (status == 'banned') {
              return _BannedAccountPage(
                reason: banReason.isEmpty ? null : banReason,
              );
            }

            if (role == 'admin') {
              return const AdminDashboard();
            } else {
              return const HomePage();
            }
          },
        );
      },
    );
  }
}

class _BannedAccountPage extends StatelessWidget {
  const _BannedAccountPage({this.reason});

  final String? reason;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.gpp_bad_rounded,
                size: 72,
                color: Color(0xFFFF6B6B),
              ),
              const SizedBox(height: 16),
              const Text(
                'Your account is suspended',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 10),
              Text(
                reason ??
                    'Please contact support if you think this is a mistake.',
                style: const TextStyle(color: Color(0xFF6B7280), fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                onPressed: () async {
                  await FirebaseAuth.instance.signOut();
                },
                icon: const Icon(Icons.logout_rounded),
                label: const Text('Sign out'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
