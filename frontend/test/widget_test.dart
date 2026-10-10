import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dmk_project/branding.dart';
import 'package:dmk_project/app_bottom_nav.dart';

void main() {
  testWidgets('AppLogo displays Ryitu title without Sooriyan branding', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: AppLogo(height: 72),
        ),
      ),
    );

    // Verify 'Ryitu' is displayed
    expect(find.text('Ryitu'), findsOneWidget);

    // Verify 'Sooriyan' and 'நூலகம்' are NOT displayed
    expect(find.text('Sooriyan'), findsNothing);
    expect(find.text('நூலகம்'), findsNothing);
  });

  testWidgets('AppBottomNavBar contains only Home, Write, and Profile (No Explore)', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          bottomNavigationBar: AppBottomNavBar(activeIndex: 0),
        ),
      ),
    );

    // Verify Home, Write, Profile exist
    expect(find.text('Home'), findsOneWidget);
    expect(find.text('Write'), findsOneWidget);
    expect(find.text('Profile'), findsOneWidget);

    // Verify Explore is removed
    expect(find.text('Explore'), findsNothing);
  });
}
