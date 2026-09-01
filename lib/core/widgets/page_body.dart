import 'package:flutter/material.dart';

/// Max width of a screen's content on desktop. The app chrome (AppBar, TabBar)
/// stays full-bleed like a normal web page; only the content is reined in, so
/// a row's amount never drifts a monitor's width away from its label.
const kContentMaxWidth = 1100.0;

/// Centers a screen's body and caps it at [kContentMaxWidth].
///
/// No breakpoint needed: on a phone the window is already narrower than the
/// cap, so this is a no-op and mobile renders exactly as it did before.
class PageBody extends StatelessWidget {
  const PageBody({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
        child: child,
      ),
    );
  }
}
