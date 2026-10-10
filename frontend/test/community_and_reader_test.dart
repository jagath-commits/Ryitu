import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:dmk_project/home.dart';
import 'package:dmk_project/community_page.dart';
import 'package:dmk_project/pdf_upload_page.dart';
import 'package:dmk_project/reading_page.dart';
import 'package:dmk_project/app_theme.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  testWidgets('PostContainer displays Community Post badge with community name', (WidgetTester tester) async {
    final communityPost = {
      'post_id': 'POST_COMM_123',
      'username': 'Test Author',
      'title': 'Organic Rice Farming Techniques',
      'caption': 'Detailed explanation on natural fertilizers.',
      'communityId': 'COMM_001',
      'communityName': 'Ryitu Farmers Community',
      'isCommunityPost': true,
      'support_count': 12,
      'views': 45,
      'content': [],
      'createdAt': DateTime.now().toIso8601String(),
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PostContainer(
              post: communityPost,
              isCommunityView: false,
            ),
          ),
        ),
      ),
    );

    // Verify community badge is displayed
    expect(find.text('Community: Ryitu Farmers Community'), findsOneWidget);
    expect(find.text('Organic Rice Farming Techniques'), findsWidgets);
    expect(find.text('TEST AUTHOR'), findsWidgets);
    expect(find.byIcon(Icons.groups_rounded), findsOneWidget);
  });

  testWidgets('PostContainer displays General Post badge when communityId is absent', (WidgetTester tester) async {
    final generalPost = {
      'post_id': 'POST_GEN_456',
      'username': 'General Storyteller',
      'title': 'Morning Thoughts on Poetry',
      'caption': 'Short reflection on classic Tamil verses.',
      'communityId': null,
      'isCommunityPost': false,
      'support_count': 5,
      'views': 20,
      'content': [],
      'createdAt': DateTime.now().toIso8601String(),
    };

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: SingleChildScrollView(
            child: PostContainer(
              post: generalPost,
              isCommunityView: false,
            ),
          ),
        ),
      ),
    );

    // Verify General Post badge is displayed
    expect(find.text('General Post'), findsOneWidget);
    expect(find.text('Morning Thoughts on Poetry'), findsWidgets);
    expect(find.byIcon(Icons.public_rounded), findsOneWidget);
    expect(find.byIcon(Icons.groups_rounded), findsNothing);
  });

  testWidgets('CommunityPage renders header with share button and request join without separate PDF button', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CommunityPage(
          communityId: 'test-comm-id',
          communityName: 'Organic Agriculture Network',
        ),
      ),
    );

    // Initial load will show community name and share button
    expect(find.text('Organic Agriculture Network'), findsWidgets);
    expect(find.byIcon(Icons.share_rounded), findsOneWidget);
    // Confirm NO separate upload PDF button in community page
    expect(find.text('Upload PDF'), findsNothing);
  });

  testWidgets('CommunitiesListPage renders explore header, filters, and Create Community button', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: CommunitiesListPage(),
      ),
    );

    // Verify Communities title and Create Community triggers
    expect(find.text('Communities'), findsOneWidget);
    expect(find.text('Create Community'), findsOneWidget);
    expect(find.byIcon(Icons.add_circle_outline_rounded), findsOneWidget);
  });

  testWidgets('PdfUploadPage renders form inputs and file pick trigger', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: PdfUploadPage(
          communityId: 'test-comm-id',
          communityName: 'Organic Agriculture Network',
        ),
      ),
    );

    // Verify title with community name and input placeholders
    expect(find.text('Upload PDF to Organic Agriculture Network'), findsOneWidget);
    expect(find.text('Tap to select PDF file'), findsOneWidget);
    expect(find.text('Book Title *'), findsOneWidget);
    expect(find.text('Author Name'), findsOneWidget);
    expect(find.text('Upload & Read Book'), findsOneWidget);
  });

  testWidgets('ReadingPage renders reader title, bookmarks, settings, and page counter', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: ReadingPage(
          bookId: 'book-123',
          bookTitle: 'Handbook of Modern Agriculture',
          initialPage: 1,
          totalPages: 10,
        ),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // Verify reader title and UI controls
    expect(find.text('Handbook of Modern Agriculture'), findsOneWidget);
    expect(find.byIcon(Icons.bookmark_border_rounded), findsOneWidget);
    expect(find.byIcon(Icons.bookmarks_outlined), findsOneWidget);
    expect(find.byIcon(Icons.tune_rounded), findsOneWidget);
    expect(find.byType(Slider), findsOneWidget);
  });

  testWidgets('Theme tone is set to #0729E8 across AppColors and light theme', (WidgetTester tester) async {
    expect(AppColors.brand, const Color(0xFF0729E8));
    expect(AppColors.brandDark, const Color(0xFF041CA1));
    final lightTheme = AppTheme.light;
    expect(lightTheme.colorScheme.primary, const Color(0xFF0729E8));
  });

  testWidgets('CommunitiesListPage renders on narrow 320px screen without any RenderFlex overflow', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(320, 640);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: const CommunitiesListPage(),
      ),
    );
    await tester.pump();

    // Verify no RenderFlex overflow exception
    expect(tester.takeException(), isNull);
    expect(find.text('Communities'), findsOneWidget);
  });

  testWidgets('Theme font is set to Merienda globally', (WidgetTester tester) async {
    final lightTheme = AppTheme.light;
    expect(lightTheme.textTheme.bodyMedium?.fontFamily, contains('Merienda'));
  });

  testWidgets('Tapping on a post navigates directly to FullScreenPostViewer reader', (WidgetTester tester) async {
    SharedPreferences.setMockInitialValues({});
    final postData = {
      'post_id': 'POST_READ_999',
      'username': 'Farmer Ram',
      'title': 'Paddy Cultivation Secrets',
      'caption': 'Step by step planting guide.',
      'communityId': 'COMM_001',
      'communityName': 'Ryitu Farmers Community',
      'isCommunityPost': true,
      'support_count': 8,
      'views': 15,
      'content': [
        {
          'blocks': [
            {'type': 'text', 'text': 'Page 1 of farming manual.'}
          ]
        }
      ],
      'createdAt': DateTime.now().toIso8601String(),
    };

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: SingleChildScrollView(
            child: PostContainer(
              post: postData,
              isCommunityView: false,
            ),
          ),
        ),
      ),
    );

    // Tap on Open Reader on the book cover
    await tester.tap(find.text('Open Reader'));
    await tester.pumpAndSettle();

    // Verify reader is opened
    expect(find.byType(FullScreenPostViewer), findsOneWidget);
    expect(find.text('Page 1 of farming manual.'), findsOneWidget);
  });
}

