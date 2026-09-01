import 'package:flutter/material.dart';

// The UI is mobile-first. Below this window width we leave it completely
// alone; above it, edge-to-edge lists and forms look stretched on a monitor.
const _breakpoint = 600.0;

// Phone-ish, but wide enough that expense rows and the split editor breathe.
const _maxWidth = 560.0;

/// Centers the whole app — AppBar, body, tabs and FAB — in a narrow column on
/// wide screens, with a tinted backdrop filling the rest of the window.
///
/// Mounted from `MaterialApp.router`'s `builder`, so it sits above the root
/// Navigator and catches every route plus every dialog, bottom sheet and
/// SnackBar. On narrow screens it is a no-op: the child is returned untouched.
class ResponsiveShell extends StatelessWidget {
  const ResponsiveShell({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        if (constraints.maxWidth <= _breakpoint) return child;

        return ColoredBox(
          color: Theme.of(context).colorScheme.surfaceContainerHighest,
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: _maxWidth),
              // Dialogs, bottom sheets and TabBar size themselves off
              // MediaQuery.size rather than their parent constraints, so
              // narrow that too. Only `size` — padding and viewInsets must
              // keep reporting the real window so the keyboard still works.
              child: MediaQuery(
                data: MediaQuery.of(context).copyWith(
                  size: Size(_maxWidth, constraints.maxHeight),
                ),
                child: child,
              ),
            ),
          ),
        );
      },
    );
  }
}
