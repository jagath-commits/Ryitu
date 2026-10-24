import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Shared design tokens for a consistent, professional UI across the app.
abstract final class AppColors {
  static const brand = Color(0xFF0729E8);
  static const brandDark = Color(0xFF041CA1);
  static const scaffold = Color(0xFFF4F5F7);
  static const surface = Colors.white;
  static const textPrimary = Color(0xFF1A1A1A);
  static const textSecondary = Color(0xFF6B7280);
  static const border = Color(0xFFE8EAED);
  static const chipBg = Color(0xFFF0F1F3);
}

abstract final class AppRadius {
  static const sm = 12.0;
  static const md = 16.0;
  static const lg = 20.0;
  static const xl = 24.0;
}

/// Android App Default Font Settings:
/// - Default app font: Roboto, System default
/// - App title / Toolbar: Roboto Medium 20sp
/// - Page heading: Roboto Medium 20–24sp
/// - Subheading: Roboto Medium 16–18sp
/// - Body / Paragraph: Roboto Regular 14–16sp
/// - Button text: Roboto Medium 14sp
/// - Caption / Helper text: Roboto Regular 12sp
/// - Bottom navigation label: Roboto Medium 12sp
abstract final class AppTypography {
  static const String fontFamily = 'Roboto';

  /// Default app font - System default
  static const TextStyle defaultFont = TextStyle(
    fontFamily: fontFamily,
    fontWeight: FontWeight.w400,
  );

  /// App title / Toolbar: Roboto Medium 20sp
  static const TextStyle appTitle = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
  );

  /// Page heading: Roboto Medium 20–24sp (default: 22sp)
  static const TextStyle pageHeading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 22,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
  );

  /// Page heading (20sp)
  static const TextStyle pageHeading20 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 20,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
  );

  /// Page heading (24sp)
  static const TextStyle pageHeading24 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 24,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
    letterSpacing: -0.2,
  );

  /// Subheading: Roboto Medium 16–18sp (default: 16sp)
  static const TextStyle subheading = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  /// Subheading (18sp)
  static const TextStyle subheading18 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 18,
    fontWeight: FontWeight.w500,
    color: AppColors.textPrimary,
  );

  /// Body / Paragraph: Roboto Regular 14–16sp (default: 14sp)
  static const TextStyle body = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  /// Body / Paragraph (16sp)
  static const TextStyle body16 = TextStyle(
    fontFamily: fontFamily,
    fontSize: 16,
    fontWeight: FontWeight.w400,
    color: AppColors.textPrimary,
    height: 1.4,
  );

  /// Button text: Roboto Medium 14sp
  static const TextStyle button = TextStyle(
    fontFamily: fontFamily,
    fontSize: 14,
    fontWeight: FontWeight.w500,
    letterSpacing: 0.1,
  );

  /// Caption / Helper text: Roboto Regular 12sp
  static const TextStyle caption = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    color: AppColors.textSecondary,
    height: 1.3,
  );

  /// Bottom navigation label: Roboto Medium 12sp
  static const TextStyle bottomNavLabel = TextStyle(
    fontFamily: fontFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
  );
}

abstract final class AppTheme {
  static ThemeData get light {
    const colorScheme = ColorScheme.light(
      primary: AppColors.brand,
      onPrimary: Colors.white,
      surface: AppColors.surface,
      onSurface: AppColors.textPrimary,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: AppColors.scaffold,
      // Default app font: Roboto, System default
      fontFamily: AppTypography.fontFamily,
      textTheme: const TextTheme(
        // Page heading: Roboto Medium 20–24sp
        headlineLarge: AppTypography.pageHeading24,
        headlineMedium: AppTypography.pageHeading,
        headlineSmall: AppTypography.pageHeading20,

        // App title / Toolbar: Roboto Medium 20sp
        titleLarge: AppTypography.appTitle,

        // Subheading: Roboto Medium 16–18sp
        titleMedium: AppTypography.subheading18,
        titleSmall: AppTypography.subheading,

        // Body / Paragraph: Roboto Regular 14–16sp
        bodyLarge: AppTypography.body16,
        bodyMedium: AppTypography.body,

        // Caption / Helper text: Roboto Regular 12sp
        bodySmall: AppTypography.caption,

        // Button text: Roboto Medium 14sp
        labelLarge: AppTypography.button,

        // Bottom navigation label: Roboto Medium 12sp
        labelMedium: AppTypography.bottomNavLabel,

        // Caption / Helper text: Roboto Regular 12sp
        labelSmall: AppTypography.caption,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        centerTitle: true,
        scrolledUnderElevation: 0.5,
        systemOverlayStyle: SystemUiOverlayStyle(
          statusBarColor: Colors.transparent,
          statusBarIconBrightness: Brightness.dark,
        ),
        // App title / Toolbar: Roboto Medium 20sp
        titleTextStyle: AppTypography.appTitle,
        iconTheme: IconThemeData(color: AppColors.textPrimary, size: 22),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          side: const BorderSide(color: AppColors.border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
          borderSide: const BorderSide(color: AppColors.brand, width: 1.5),
        ),
        // Body / Paragraph: Roboto Regular 14sp
        hintStyle: AppTypography.body.copyWith(
          color: AppColors.textSecondary,
        ),
        // Caption / Helper text: Roboto Regular 12sp
        helperStyle: AppTypography.caption,
        errorStyle: AppTypography.caption,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.brand,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          // Button text: Roboto Medium 14sp
          textStyle: AppTypography.button,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.brand,
          // Button text: Roboto Medium 14sp
          textStyle: AppTypography.button,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.brand,
          side: const BorderSide(color: AppColors.border),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.sm),
          ),
          // Button text: Roboto Medium 14sp
          textStyle: AppTypography.button,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.brand,
        unselectedItemColor: AppColors.textSecondary,
        // Bottom navigation label: Roboto Medium 12sp
        selectedLabelStyle: AppTypography.bottomNavLabel,
        unselectedLabelStyle: AppTypography.bottomNavLabel,
        type: BottomNavigationBarType.fixed,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: AppColors.brand.withValues(alpha: 0.1),
        // Bottom navigation label: Roboto Medium 12sp
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return AppTypography.bottomNavLabel;
        }),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.sm),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: AppColors.border,
        thickness: 1,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: AppColors.brand,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.chipBg,
        selectedColor: AppColors.brand,
        labelStyle: const TextStyle(
          fontFamily: AppTypography.fontFamily,
          fontWeight: FontWeight.w500,
          fontSize: 13,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        showCheckmark: false,
        side: BorderSide.none,
      ),
    );
  }
}

/// Standard white app bar used on Home, Explore, Write, etc.
PreferredSizeWidget appBar(
  String title, {
  List<Widget>? actions,
  Widget? leading,
  bool centerTitle = true,
  bool automaticallyImplyLeading = false,
}) {
  return AppBar(
    title: Text(title),
    centerTitle: centerTitle,
    automaticallyImplyLeading: automaticallyImplyLeading,
    leading: leading,
    actions: actions,
  );
}

/// Rounded white search / input container.
Widget appSearchField({
  required TextEditingController controller,
  required String hint,
  ValueChanged<String>? onChanged,
  Widget? prefixIcon,
}) {
  return Container(
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withValues(alpha: 0.03),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ],
    ),
    child: TextField(
      controller: controller,
      onChanged: onChanged,
      // Body / Paragraph: Roboto Regular 14sp
      style: AppTypography.body,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: AppTypography.body.copyWith(color: AppColors.textSecondary),
        prefixIcon: prefixIcon ??
            const Icon(Icons.search_rounded, color: AppColors.brand),
        border: InputBorder.none,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    ),
  );
}

/// Consistent empty state across tabs and lists.
Widget appEmptyState({
  required IconData icon,
  required String title,
  String? subtitle,
}) {
  return Center(
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.brand.withValues(alpha: 0.08),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 40, color: AppColors.brand),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            textAlign: TextAlign.center,
            // Page heading / Subheading: Roboto Medium 20sp
            style: AppTypography.pageHeading20,
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              // Caption / Helper text: Roboto Regular 12sp
              style: AppTypography.caption,
            ),
          ],
        ],
      ),
    ),
  );
}

/// White card with subtle border — forms, lists.
BoxDecoration appCardDecoration({double radius = AppRadius.md}) {
  return BoxDecoration(
    color: AppColors.surface,
    borderRadius: BorderRadius.circular(radius),
    border: Border.all(color: AppColors.border),
    boxShadow: [
      BoxShadow(
        color: Colors.black.withValues(alpha: 0.03),
        blurRadius: 10,
        offset: const Offset(0, 2),
      ),
    ],
  );
}
