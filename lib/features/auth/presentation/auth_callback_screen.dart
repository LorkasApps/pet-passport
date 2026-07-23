import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../application/auth_providers.dart';

/// Landing screen after the magic-link deep-link kicks the app open.
///
/// The Supabase SDK's own deep-link observer runs in parallel and does
/// the PKCE code exchange. We just show a spinner and forward to `/home`
/// as soon as a session materialises. A 6-second timeout catches the
/// case where something silently fails so the user isn't stuck on a
/// spinner forever.
class AuthCallbackScreen extends ConsumerStatefulWidget {
  const AuthCallbackScreen({super.key});

  @override
  ConsumerState<AuthCallbackScreen> createState() =>
      _AuthCallbackScreenState();
}

class _AuthCallbackScreenState extends ConsumerState<AuthCallbackScreen> {
  Timer? _timeout;

  @override
  void initState() {
    super.initState();
    _timeout = Timer(const Duration(seconds: 6), () {
      if (!mounted) return;
      // Nothing came in — bounce back to sign-in so the user can retry.
      context.go('/auth/signin');
    });
  }

  @override
  void dispose() {
    _timeout?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Fire once when the user materialises.
    ref.listen<User?>(currentUserProvider, (previous, next) {
      if (next != null && mounted) {
        _timeout?.cancel();
        context.go('/home');
      }
    });
    // If the SDK already exchanged (e.g. warm start) the user is present
    // synchronously — jump immediately.
    final user = ref.watch(currentUserProvider);
    if (user != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/home');
      });
    }

    return const Scaffold(
      body: Center(child: CircularProgressIndicator()),
    );
  }
}
