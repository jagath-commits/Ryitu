import 'package:flutter/material.dart';


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
        ClipRRect(
          borderRadius: BorderRadius.circular(height * 0.18),
          child: Image.asset(
            'assets/images/ryitu_logo_round.png',
            width: height * 0.75,
            height: height * 0.75,
            fit: BoxFit.cover,
          ),
        ),
        SizedBox(height: height * 0.1),
        Text(
          'Ritpen',
          style: TextStyle(
            fontFamily: 'Roboto',
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
  final bool showLabel;

  const PoweredByBadge({
    super.key,
    this.height = 42,
    this.showLabel = true,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (showLabel) ...[
          Text(
            'POWERED BY',
            style: TextStyle(
              fontSize: 10,
              color: Colors.black.withValues(alpha: 0.35),
              fontWeight: FontWeight.w800,
              letterSpacing: 2.0,
              fontFamily: 'Roboto',
            ),
          ),
          const SizedBox(height: 8),
        ],
        Image.asset(
          'assets/images/coderead_logo.png',
          height: height,
          fit: BoxFit.contain,
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
