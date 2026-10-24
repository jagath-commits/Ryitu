import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:dmk_project/api_config.dart';
import 'package:dmk_project/app_theme.dart';

class AppUpdateInfo {
  final int minBuildNumber;
  final int latestBuildNumber;
  final String minVersion;
  final String latestVersion;
  final bool forceUpdate;
  final String updateUrl;
  final String title;
  final String message;
  final int currentBuildNumber;
  final String currentVersion;
  final bool isUpdateRequired;

  AppUpdateInfo({
    required this.minBuildNumber,
    required this.latestBuildNumber,
    required this.minVersion,
    required this.latestVersion,
    required this.forceUpdate,
    required this.updateUrl,
    required this.title,
    required this.message,
    required this.currentBuildNumber,
    required this.currentVersion,
    required this.isUpdateRequired,
  });

  factory AppUpdateInfo.fromServer({
    required Map<String, dynamic> data,
    required int currentBuild,
    required String currentVer,
  }) {
    final minBuild = int.tryParse(data['minBuildNumber']?.toString() ?? '0') ?? 0;
    final latestBuild = int.tryParse(data['latestBuildNumber']?.toString() ?? '0') ?? minBuild;
    final force = data['forceUpdate'] == true;
    final minVer = data['minVersion']?.toString() ?? '1.0.0';
    final latestVer = data['latestVersion']?.toString() ?? minVer;
    final url = data['updateUrl']?.toString() ?? 'https://play.google.com/store/apps/details?id=com.ritpen';
    final title = data['title']?.toString() ?? 'Update Required';
    final message = data['message']?.toString() ??
        'A new version of Ritpen is available with exciting features, critical bug fixes, and performance improvements. Please update to continue.';

    // Update is required if current build is below min build, or if forced and below latest build
    final updateRequired = currentBuild < minBuild || (force && currentBuild < latestBuild);

    return AppUpdateInfo(
      minBuildNumber: minBuild,
      latestBuildNumber: latestBuild,
      minVersion: minVer,
      latestVersion: latestVer,
      forceUpdate: force,
      updateUrl: url,
      title: title,
      message: message,
      currentBuildNumber: currentBuild,
      currentVersion: currentVer,
      isUpdateRequired: updateRequired,
    );
  }
}

class AppUpdateService {
  static final AppUpdateService _instance = AppUpdateService._internal();
  factory AppUpdateService() => _instance;
  AppUpdateService._internal();

  bool _isChecking = false;
  bool _isDialogVisible = false;

  /// Check if the installed app requires an update against the backend requirements.
  /// If update is required, displays an un-bypassable modal dialog.
  Future<AppUpdateInfo?> checkUpdate(BuildContext? context) async {
    if (_isChecking || _isDialogVisible) return null;
    _isChecking = true;

    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;
      final currentVer = packageInfo.version;

      debugPrint('🔍 [AppUpdate] Checking app update... Current build: $currentBuild ($currentVer)');

      final response = await http
          .get(Uri.parse('${ApiConfig.apiBaseUrl}/app/version'))
          .timeout(const Duration(seconds: 7));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        if (body['success'] == true && body['data'] != null) {
          final info = AppUpdateInfo.fromServer(
            data: Map<String, dynamic>.from(body['data']),
            currentBuild: currentBuild,
            currentVer: currentVer,
          );

          debugPrint(
            '🔍 [AppUpdate] Server requirements -> minBuild: ${info.minBuildNumber}, latestBuild: ${info.latestBuildNumber}, forceUpdate: ${info.forceUpdate}, required: ${info.isUpdateRequired}',
          );

          if (info.isUpdateRequired && context != null && context.mounted) {
            _showForceUpdateDialog(context, info);
          }

          return info;
        }
      } else {
        debugPrint('⚠️ [AppUpdate] Server returned status ${response.statusCode}');
      }
    } catch (e) {
      debugPrint('⚠️ [AppUpdate] Check failed (network/offline): $e');
    } finally {
      _isChecking = false;
    }

    return null;
  }

  void _showForceUpdateDialog(BuildContext context, AppUpdateInfo info) {
    if (_isDialogVisible) return;
    _isDialogVisible = true;

    showDialog(
      context: context,
      barrierDismissible: false, // Cannot dismiss by tapping outside
      builder: (dialogCtx) {
        return PopScope(
          canPop: false, // Cannot dismiss via Android hardware back button or swipe gesture
          onPopInvokedWithResult: (didPop, result) {},
          child: _AppUpdateDialogContent(
            info: info,
            onDismiss: () {
              _isDialogVisible = false;
            },
          ),
        );
      },
    ).then((_) {
      _isDialogVisible = false;
    });
  }
}

class _AppUpdateDialogContent extends StatefulWidget {
  final AppUpdateInfo info;
  final VoidCallback onDismiss;

  const _AppUpdateDialogContent({
    required this.info,
    required this.onDismiss,
  });

  @override
  State<_AppUpdateDialogContent> createState() => _AppUpdateDialogContentState();
}

class _AppUpdateDialogContentState extends State<_AppUpdateDialogContent> {
  bool _isCheckingAgain = false;

  Future<void> _launchUpdateUrl() async {
    final uri = Uri.parse(widget.info.updateUrl);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );
      if (!launched) {
        await launchUrl(uri);
      }
    } catch (e) {
      debugPrint('⚠️ [AppUpdate] Failed to launch update URL: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Could not open link. Please visit: ${widget.info.updateUrl}'),
            backgroundColor: AppColors.brand,
          ),
        );
      }
    }
  }

  Future<void> _recheckVersion() async {
    setState(() => _isCheckingAgain = true);
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentBuild = int.tryParse(packageInfo.buildNumber) ?? 0;

      final response = await http
          .get(Uri.parse('${ApiConfig.apiBaseUrl}/app/version'))
          .timeout(const Duration(seconds: 5));

      if (response.statusCode == 200) {
        final body = jsonDecode(response.body);
        final minBuild = int.tryParse(body['data']?['minBuildNumber']?.toString() ?? '0') ?? 0;

        if (currentBuild >= minBuild) {
          // Successfully updated!
          widget.onDismiss();
          if (mounted) {
            Navigator.of(context, rootNavigator: true).pop();
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Ritpen is up to date! Welcome back.'),
                backgroundColor: Color(0xFF2E7D32),
              ),
            );
          }
          return;
        }
      }
    } catch (_) {
      // Ignore
    } finally {
      if (mounted) {
        setState(() => _isCheckingAgain = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      elevation: 16,
      backgroundColor: Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // Logo with subtle glow/border
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: AppColors.brand.withValues(alpha: 0.18),
                    blurRadius: 20,
                    offset: const Offset(0, 8),
                  ),
                ],
                border: Border.all(
                  color: AppColors.brand.withValues(alpha: 0.25),
                  width: 2,
                ),
              ),
              child: ClipOval(
                child: Padding(
                  padding: const EdgeInsets.all(12.0),
                  child: Image.asset(
                    'assets/images/ritpen_logo.png',
                    fit: BoxFit.contain,
                    errorBuilder: (ctx, err, stack) => const Icon(
                      Icons.system_update_rounded,
                      color: AppColors.brand,
                      size: 40,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),

            // Mandatory Update Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
              decoration: BoxDecoration(
                color: const Color(0xFFFFF0F0),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: const Color(0xFFFFD4D4)),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.warning_amber_rounded,
                    size: 14,
                    color: AppColors.brand,
                  ),
                  SizedBox(width: 6),
                  Text(
                    'UPDATE REQUIRED',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: AppColors.brand,
                      letterSpacing: 0.8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            // Title
            Text(
              widget.info.title,
              textAlign: TextAlign.center,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                color: Color(0xFF1A1A1A),
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 10),

            // Message
            Text(
              widget.info.message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                color: Colors.grey.shade700,
                height: 1.45,
              ),
            ),
            const SizedBox(height: 18),

            // Version Info Pill
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF6F7F9),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Installed: v${widget.info.currentVersion} (${widget.info.currentBuildNumber})',
                    style: TextStyle(
                      color: Colors.grey.shade600,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8),
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 13,
                      color: Colors.grey.shade500,
                    ),
                  ),
                  Text(
                    'Latest: v${widget.info.latestVersion} (${widget.info.latestBuildNumber})',
                    style: const TextStyle(
                      color: AppColors.brand,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // "Update Now" Action Button
            SizedBox(
              width: double.infinity,
              height: 48,
              child: ElevatedButton.icon(
                onPressed: _launchUpdateUrl,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.brand,
                  foregroundColor: Colors.white,
                  elevation: 2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                icon: const Icon(Icons.download_rounded, size: 20),
                label: const Text(
                  'Update Now',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.3,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),

            // Recheck Button (In case tester already updated and switched back)
            TextButton.icon(
              onPressed: _isCheckingAgain ? null : _recheckVersion,
              icon: _isCheckingAgain
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppColors.brand,
                      ),
                    )
                  : Icon(
                      Icons.refresh_rounded,
                      size: 16,
                      color: Colors.grey.shade600,
                    ),
              label: Text(
                _isCheckingAgain ? 'Checking...' : 'Check Again',
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: Colors.grey.shade700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
