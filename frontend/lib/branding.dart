import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Safe branding widgets — no asset files required.
class AppLogo extends StatelessWidget {
  final double height;

  const AppLogo({super.key, this.height = 72});

  @override
  Widget build(BuildContext context) {
    final fontSize = height * 0.28;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        ClipOval(
          child: Image.asset(
            'assets/images/ryitu_logo_round.png',
            width: height * 0.75,
            height: height * 0.75,
            fit: BoxFit.cover,
          ),
        ),
        SizedBox(height: height * 0.1),
        Text(
          'Ryitu',
          style: GoogleFonts.merienda(
            fontSize: fontSize,
            fontWeight: FontWeight.w900,
            color: const Color(0xFF0729E8),
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }
}

class PoweredByBadge extends StatelessWidget {
  final double height;

  const PoweredByBadge({super.key, this.height = 48});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'Powered by',
          style: TextStyle(
            fontSize: 12,
            color: Colors.black.withValues(alpha: 0.4),
            fontWeight: FontWeight.w700,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'CodeRead',
          style: TextStyle(
            fontSize: height * 0.45,
            fontWeight: FontWeight.w800,
            color: Colors.black.withValues(alpha: 0.55),
          ),
        ),
      ],
    );
  }
}

/// Use when image assets are added to pubspec later.
Widget appLogoImage({
  double height = 72,
  String? asset,
}) {
  return AppLogo(height: height);
}
