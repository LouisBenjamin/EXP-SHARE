import 'package:exp_share/core/router.dart';
import 'package:exp_share/core/theme.dart';
import 'package:exp_share/core/widgets/responsive_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'EXP Share',
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      routerConfig: ref.watch(routerProvider),
      builder: (context, child) => ResponsiveShell(child: child!),
    );
  }
}
