import 'package:tally/core/widgets/page_body.dart';
import 'package:tally/features/labels/ui/labels_tab.dart';
import 'package:flutter/material.dart';

// Standalone route for Labels, so a bookmarked /import/rules link (retired
// alongside MerchantRulesScreen) has somewhere to land. The group detail
// screen embeds LabelsTab directly rather than pushing this route.
class LabelsScreen extends StatelessWidget {
  const LabelsScreen({super.key, required this.groupId});
  final String groupId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Labels')),
      body: PageBody(child: LabelsTab(groupId: groupId)),
    );
  }
}
