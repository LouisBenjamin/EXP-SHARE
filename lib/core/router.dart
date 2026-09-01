import 'package:exp_share/core/supabase_client.dart';
import 'package:exp_share/features/auth/ui/login_screen.dart';
import 'package:exp_share/features/expenses/ui/add_expense_screen.dart';
import 'package:exp_share/features/groups/ui/group_detail_screen.dart';
import 'package:exp_share/features/groups/ui/groups_list_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final notifier = _AuthNotifier();
  ref.onDispose(notifier.dispose);

  return GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: (context, state) {
      final isLoggedIn = supabase.auth.currentSession != null;
      final isGoingToLogin = state.matchedLocation == '/login';
      if (!isLoggedIn && !isGoingToLogin) return '/login';
      if (isLoggedIn && isGoingToLogin) return '/groups';
      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (_, __) => const LoginScreen(),
      ),
      GoRoute(
        path: '/groups',
        builder: (_, __) => const GroupsListScreen(),
        routes: [
          GoRoute(
            path: ':groupId',
            builder: (_, state) => GroupDetailScreen(
              groupId: state.pathParameters['groupId']!,
            ),
            routes: [
              GoRoute(
                path: 'expenses/new',
                builder: (_, state) => AddExpenseScreen(
                  groupId: state.pathParameters['groupId']!,
                ),
              ),
            ],
          ),
        ],
      ),
    ],
  );
});

// Bridges Supabase auth state changes into GoRouter's Listenable interface.
class _AuthNotifier extends ChangeNotifier {
  _AuthNotifier() {
    _sub = supabase.auth.onAuthStateChange.listen((_) => notifyListeners());
  }

  late final dynamic _sub;

  @override
  void dispose() {
    _sub.cancel();
    super.dispose();
  }
}
