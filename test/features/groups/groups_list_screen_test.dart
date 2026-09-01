import 'package:tally/core/theme.dart';
import 'package:tally/features/groups/providers/groups_provider.dart';
import 'package:tally/features/groups/ui/groups_list_screen.dart';
import 'package:tally/models/group.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Group g(String id, String name) => Group(
      id: id,
      name: name,
      joinCode: 'CODE$id',
      createdBy: 'u1',
      createdAt: DateTime(2026, 8, 1),
    );

Future<void> pumpAt(
  WidgetTester tester,
  Size size, {
  required List<Group> groups,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        groupsProvider.overrideWith((ref) async => groups),
      ],
      child: MaterialApp(
        theme: AppTheme.light,
        home: const GroupsListScreen(),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

int? gridColumns(WidgetTester tester) {
  final grid = tester.widget<GridView>(find.byType(GridView));
  final delegate = grid.gridDelegate as SliverGridDelegateWithFixedCrossAxisCount;
  return delegate.crossAxisCount;
}

void main() {
  final groups = [for (var i = 0; i < 6; i++) g('$i', 'Group $i')];

  testWidgets('phone width renders the plain ListView, no grid', (tester) async {
    await pumpAt(tester, const Size(375, 900), groups: groups);
    expect(find.byType(GridView), findsNothing);
    expect(find.byType(ListView), findsOneWidget);
  });

  testWidgets('tablet width switches to a 2-column grid', (tester) async {
    await pumpAt(tester, const Size(800, 1000), groups: groups);
    expect(gridColumns(tester), 2);
  });

  testWidgets('wide desktop caps the grid at 3 columns', (tester) async {
    await pumpAt(tester, const Size(1920, 1080), groups: groups);
    // content is capped at 1100px by PageBody -> 1100/360 = 3
    expect(gridColumns(tester), 3);
  });

  testWidgets('empty state shown when there are no groups', (tester) async {
    await pumpAt(tester, const Size(1440, 900), groups: const []);
    expect(find.text('No groups yet'), findsOneWidget);
    expect(find.byType(GridView), findsNothing);
  });

  testWidgets('every group card is rendered', (tester) async {
    await pumpAt(tester, const Size(1200, 2000), groups: groups);
    expect(find.text('Group 0'), findsOneWidget);
    expect(find.text('Group 5'), findsOneWidget);
  });
}
