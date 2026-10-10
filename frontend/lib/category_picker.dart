import 'package:dmk_project/app_theme.dart';
import 'package:flutter/material.dart';

Future<String?> showCategorySelectionBottomSheet(BuildContext context) async {
  return showModalBottomSheet<String>(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (context) {
      return Container(
        decoration: const BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.xl)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 20),
              decoration: BoxDecoration(
                color: AppColors.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const Text(
              'நீங்கள் என்ன எழுத விரும்புகிறீர்கள்?',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 6),
            const Text(
              'வகையைத் தேர்ந்தெடுக்கவும்',
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w500,
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 24),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              alignment: WrapAlignment.center,
              children: [
                _buildCategoryOption(context, '4', 'Ryitu', Icons.library_books_rounded),
              ],
            ),
          ],
        ),
      );
    },
  );
}

Widget _buildCategoryOption(
  BuildContext context,
  String id,
  String title,
  IconData icon,
) {
  final screenWidth = MediaQuery.of(context).size.width;
  final itemWidth = (screenWidth - 52) / 2;

  return Material(
    color: Colors.transparent,
    child: InkWell(
      onTap: () => Navigator.pop(context, id),
      borderRadius: BorderRadius.circular(AppRadius.md),
      child: Ink(
        width: itemWidth.clamp(140.0, 200.0),
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 12),
        decoration: appCardDecoration(radius: AppRadius.md),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.brand.withValues(alpha: 0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: AppColors.brand, size: 26),
            ),
            const SizedBox(height: 12),
            Text(
              title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}
