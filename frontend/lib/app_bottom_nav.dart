import 'package:dmk_project/app_theme.dart';
import 'package:dmk_project/drafts_manager.dart';
import 'package:dmk_project/home.dart';
import 'package:dmk_project/write.dart' deferred as write;
import 'package:flutter/material.dart';

/// Shared bottom navigation — same style across MainShell and Edit Profile.
class AppBottomNavBar extends StatelessWidget {
  /// 0 Home, 1 Profile. Null = no tab highlighted.
  final int? activeIndex;

  /// When set (MainShell), switches tabs in place. Otherwise navigates to MainShell.
  final void Function(int index)? onTabSelected;

  const AppBottomNavBar({
    super.key,
    this.activeIndex,
    this.onTabSelected,
  });

  void _goToTab(BuildContext context, int index) {
    if (onTabSelected != null) {
      onTabSelected!(index);
      return;
    }
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => MainShell(initialIndex: index)),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        border: const Border(top: BorderSide(color: AppColors.border)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _NavItem(
                icon: Icons.home_rounded,
                label: 'Home',
                isActive: activeIndex == 0,
                onTap: () => _goToTab(context, 0),
              ),
              _NavItem(
                icon: Icons.edit_note_rounded,
                label: 'Write',
                isActive: false,
                onTap: () async {
                  await write.loadLibrary();
                  if (!context.mounted) return;
                  await Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => write.WritePage(category: '4'),
                    ),
                  );
                  DraftsManager.instance.notifyDraftsChanged();
                },
              ),
              _NavItem(
                icon: Icons.person_rounded,
                label: 'Profile',
                isActive: activeIndex == 1,
                onTap: () => _goToTab(context, 1),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isActive;
  final VoidCallback onTap;

  const _NavItem({
    required this.icon,
    required this.label,
    required this.isActive,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color =
        isActive ? AppColors.brand : AppColors.textSecondary;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 4),
          Text(
            label,
            // Bottom navigation label: Roboto Medium 12sp
            style: AppTypography.bottomNavLabel.copyWith(
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
