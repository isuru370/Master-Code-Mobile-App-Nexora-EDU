import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexorait_education_app/core/theme/app_theme.dart';
import 'package:nexorait_education_app/core/widgets/nx_ui.dart';

/// The web-style building blocks build without layout errors on a small
/// phone screen.
void main() {
  Future<void> pump(WidgetTester tester, Widget child) async {
    tester.view.physicalSize = const Size(360 * 3, 760 * 3);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          appBar: AppBar(
            title: const NxPageTitle('Dashboard', subtitle: 'Colombo'),
          ),
          drawer: NxDrawer(
            header: const NxDrawerHeader(
              userName: 'Isuru',
              userDetail: 'Colombo',
              roleLabel: 'Admin',
            ),
            footer: NxDrawerItem(
              icon: Icons.logout_rounded,
              title: 'Logout',
              danger: true,
              onTap: () {},
            ),
            children: [
              NxDrawerItem(
                icon: Icons.grid_view_rounded,
                title: 'Dashboard',
                active: true,
                onTap: () {},
              ),
              const NxDrawerSection('Student Management'),
              NxDrawerItem(
                icon: Icons.people_alt_rounded,
                title: 'Students',
                onTap: () {},
              ),
            ],
          ),
          body: ListView(padding: const EdgeInsets.all(16), children: [child]),
        ),
      ),
    );
  }

  testWidgets('cards, stats, badges and alerts', (tester) async {
    await pump(
      tester,
      Column(
        children: [
          const NxHero(
            child: Wrap(
              spacing: 8,
              children: [
                NxHeroChip(icon: Icons.badge_rounded, text: 'Admin'),
                NxHeroChip(icon: Icons.store_rounded, text: 'Colombo'),
              ],
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: NxStatCard(
                  label: 'Attendance',
                  value: '1,234',
                  note: 'Marked today',
                  icon: Icons.fact_check_rounded,
                  onTap: () {},
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: NxStatCard(
                  label: 'Today Classes',
                  value: 'LKR 1,250,000.00',
                  icon: Icons.today_rounded,
                  tone: NxTone.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          NxCard(
            title: "Today's Classes",
            subtitle: '3 classes',
            icon: Icons.class_rounded,
            trailing: const NxBadge('Ongoing', tone: NxTone.green),
            child: const NxProgress(value: .4),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 64,
            child: NxQuickAction(
              icon: Icons.school_rounded,
              title: 'Course Attendance',
              onTap: () {},
            ),
          ),
          const SizedBox(height: 12),
          const NxAlert(message: 'Printer not connected', tone: NxTone.amber),
          const NxSectionTitle(title: 'Overview', actionText: 'See all'),
          NxEmpty(
            icon: Icons.error_outline_rounded,
            message: 'Something went wrong',
            onRetry: () {},
          ),
        ],
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('ATTENDANCE'), findsOneWidget);
    expect(find.text('Course Attendance'), findsOneWidget);
    expect(find.text('Try again'), findsOneWidget);
  });

  testWidgets('drawer opens', (tester) async {
    await pump(tester, const SizedBox());

    final state = tester.firstState<ScaffoldState>(find.byType(Scaffold));
    state.openDrawer();
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('STUDENT MANAGEMENT'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
  });

  testWidgets('navy background (login / splash)', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.lightTheme,
        home: const Scaffold(
          body: NxNavyBackground(child: Center(child: Text('Welcome Back'))),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('Welcome Back'), findsOneWidget);
  });
}
