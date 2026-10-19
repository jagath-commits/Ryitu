import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dmk_project/app_theme.dart';
import 'package:url_launcher/url_launcher.dart';

// =========================================================================
// PRIVACY POLICY PAGE
// =========================================================================
class PrivacyPolicyPage extends StatelessWidget {
  const PrivacyPolicyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        title: const Text('Privacy Policy'),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(
              icon: Icons.security_rounded,
              title: 'Privacy & Data Security',
              subtitle: 'Last updated: August 2026',
            ),
            const SizedBox(height: 20),
            _buildSection(
              icon: Icons.person_search_rounded,
              title: '1. Information We Collect',
              content:
                  'We only collect essential information required to provide you with a secure and personalized experience:\n\n'
                  '• Username: Used to identify you on the platform and display authorship on stories you create.\n'
                  '• Email Address: Used for secure account authentication, password recovery, and important service updates.\n'
                  '• User Content: Stories, text, and cover images you create and publish within the app.',
            ),
            _buildSection(
              icon: Icons.security_outlined,
              title: '2. How We Use Your Data',
              content:
                  'Your data is strictly used for core app functionality:\n\n'
                  '• To create and manage your secure account.\n'
                  '• To attribute authorship to the stories you write.\n'
                  '• To deliver push notification updates via Firebase Cloud Messaging (FCM).\n'
                  '• To prevent abuse, spam, and ensure a safe community environment.',
            ),
            _buildSection(
              icon: Icons.vpn_key_rounded,
              title: '3. Data Security & Protection',
              content:
                  'We prioritize the security of your data above all else:\n\n'
                  '• Transmission: All data is sent securely using industry-standard SSL/TLS (HTTPS) encryption.\n'
                  '• Storage: Your email, password hashes, and username are stored in secure cloud environments with strict access controls.\n'
                  '• No Sharing: We do NOT sell, rent, trade, or share your personal information with third-party advertisers or external marketing networks under any circumstances.',
            ),
            _buildSectionWithEmail(
              icon: Icons.delete_sweep_rounded,
              title: '4. Data Retention & Deletion',
              contentBefore:
                  'You retain full ownership of your data:\n\n'
                  '• We keep your account information active as long as you maintain your account.\n'
                  '• You can request full deletion of your account and all associated stories at any time by emailing us at ',
              email: 'jagath@coderead.in',
              contentAfter:
                  '. We will process your deletion request within 48 hours.',
            ),
            _buildSectionWithEmail(
              icon: Icons.contact_support_rounded,
              title: '5. Contact Us',
              contentBefore:
                  'If you have any questions or concerns regarding this Privacy Policy or your data protection rights, please contact us at:\n\n',
              email: 'jagath@coderead.in',
            ),
            _buildSectionWithEmail(
              icon: Icons.child_care_rounded,
              title: '6. Child Safety Standards',
              contentBefore:
                  'Zero-Tolerance Policy for Child Sexual Abuse and Exploitation (CSAE):\n\n'
                  'Ritpen, developed by Coderead Academy, maintains a strict zero-tolerance policy toward Child Sexual Abuse and Exploitation (CSAE) and Child Sexual Abuse Material (CSAM). Ritpen strictly prohibits users from creating, uploading, publishing, sharing, requesting, promoting, distributing, or otherwise facilitating any content or activity that sexually exploits, abuses, or endangers children.\n\n'
                  'Prohibited activities include, but are not limited to:\n'
                  '• Child Sexual Abuse and Exploitation (CSAE) in any form.\n'
                  '• Child Sexual Abuse Material (CSAM), including images, videos, text, illustrations, or other content depicting or facilitating sexual abuse or exploitation of minors.\n'
                  '• Sexualization of minors.\n'
                  '• Grooming or attempting to establish inappropriate relationships with children for sexual purposes.\n'
                  '• Soliciting, requesting, exchanging, or distributing sexual content involving minors.\n'
                  '• Sextortion, sexual exploitation, trafficking, or any other form of sexual abuse involving children.\n'
                  '• Any content that promotes, encourages, facilitates, or normalizes the sexual exploitation or abuse of children.\n\n'
                  'Content Reporting and User Safety:\n\n'
                  'Users who become aware of content or behavior that may involve CSAE or CSAM should report it immediately through the available reporting or support mechanism within the application or by contacting our Child Safety Point of Contact. Reports involving child safety are treated as a priority. When we become aware of suspected CSAM or CSAE content, we may remove the content, restrict or terminate the responsible account, preserve relevant information where legally appropriate, and report the matter to the appropriate authorities as required by applicable law.\n\n'
                  'Child Safety Point of Contact:\n\n'
                  'Child Safety Team – Ritpen / Coderead Academy\n\n',
              email: 'jagath@coderead.in',
              contentAfter:
                  '\n\nCompliance With Applicable Laws:\n\n'
                  'Ritpen is committed to complying with applicable child safety laws and regulations. We cooperate with relevant authorities and take appropriate action when legally required in relation to suspected child sexual abuse, exploitation, or CSAM. Ritpen does not knowingly permit the creation, upload, storage, publication, or distribution of content that facilitates the sexual abuse or exploitation of children.\n\n'
                  'Enforcement:\n\n'
                  'Violations of these Child Safety Standards may result in immediate removal of content, suspension or termination of the user\'s account, and/or reporting to relevant authorities where required by applicable law.\n\n'
                  'These Child Safety Standards apply to all users and all content available through Ritpen.\n\n'
                  'Last updated: August 2026',
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'Thank you for trusting Ritpen.',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

Future<void> _launchEmail(String email) async {
  final Uri emailUri = Uri(scheme: 'mailto', path: email);
  if (await canLaunchUrl(emailUri)) {
    await launchUrl(emailUri);
  } else {
    await launchUrl(emailUri);
  }
}

Widget _buildSectionWithEmail({
  required IconData icon,
  required String title,
  required String contentBefore,
  required String email,
  String contentAfter = '',
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.02),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.brand, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const Divider(height: 24),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              contentBefore,
              style: GoogleFonts.outfit(
                fontSize: 14,
                height: 1.5,
                color: AppColors.textPrimary.withOpacity(0.8),
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 8),
            InkWell(
              onTap: () async => await _launchEmail(email),
              child: Text(
                email,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.brand,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            if (contentAfter.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(
                contentAfter,
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  height: 1.5,
                  color: AppColors.textPrimary.withOpacity(0.8),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ],
        ),
      ],
    ),
  );
}

// =========================================================================
// TERMS & CONDITIONS PAGE
// =========================================================================
class TermsConditionsPage extends StatelessWidget {
  const TermsConditionsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.scaffold,
      appBar: AppBar(
        title: const Text('Terms & Conditions'),
        centerTitle: true,
        backgroundColor: AppColors.surface,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new_rounded,
            color: AppColors.textPrimary,
          ),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeaderCard(
              icon: Icons.description_rounded,
              title: 'Terms of Service',
              subtitle: 'Last updated: June 2026',
            ),
            const SizedBox(height: 20),
            _buildSection(
              icon: Icons.verified_user_outlined,
              title: '1. Acceptance of Terms',
              content:
                  'By installing and using the Ritpen mobile application, you agree to comply with and be bound by these Terms and Conditions. If you do not agree, please do not use the app.',
            ),
            _buildSection(
              icon: Icons.manage_accounts_rounded,
              title: '2. User Accounts & Security',
              content:
                  '• You must provide accurate registration details (username and email address).\n'
                  '• You are responsible for keeping your login credentials confidential and secure.\n'
                  '• You agree to immediately notify us of any unauthorized use or security breaches of your account.',
            ),
            _buildSection(
              icon: Icons.create_rounded,
              title: '3. Content Guidelines & Ownership',
              content:
                  '• Intellectual Property: You retain the ownership and copyright of any stories and content you post on Ritpen. By posting, you grant Ritpen a non-exclusive license to display, host, and distribute your content within the app.\n'
                  '• Prohibited Content: You agree not to post content that is illegal, hateful, violent, harassing, defamatory, sexually explicit, or violates intellectual property rights.\n'
                  '• Moderation: We reserve the right to remove any stories or terminate user accounts that violate these guidelines without prior notice.',
            ),
            _buildSection(
              icon: Icons.gavel_rounded,
              title: '4. Limitation of Liability',
              content:
                  'Ritpen is provided "as is" without warranties of any kind. We are not liable for any damages, data loss, or service interruptions arising from your use of the application.',
            ),
            _buildSection(
              icon: Icons.edit_note_rounded,
              title: '5. Changes to Terms',
              content:
                  'We reserve the right to update these terms at any time. We will notify users of significant changes by updating the date listed at the top of these terms or through an in-app announcement.',
            ),
            const SizedBox(height: 20),
            Center(
              child: Text(
                'By using the app, you agree to these terms.',
                style: GoogleFonts.outfit(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// =========================================================================
// HELPER COMPONENT WIDGETS
// =========================================================================
Widget _buildHeaderCard({
  required IconData icon,
  required String title,
  required String subtitle,
}) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      gradient: const LinearGradient(
        colors: [AppColors.brand, AppColors.brandDark],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(AppRadius.lg),
      boxShadow: [
        BoxShadow(
          color: AppColors.brand.withOpacity(0.2),
          blurRadius: 16,
          offset: const Offset(0, 8),
        ),
      ],
    ),
    child: Column(
      children: [
        CircleAvatar(
          radius: 30,
          backgroundColor: Colors.white.withOpacity(0.15),
          child: Icon(icon, color: Colors.white, size: 32),
        ),
        const SizedBox(height: 16),
        Text(
          title,
          style: GoogleFonts.outfit(
            fontSize: 22,
            fontWeight: FontWeight.w800,
            color: Colors.white,
            letterSpacing: -0.2,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          subtitle,
          style: GoogleFonts.outfit(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: Colors.white.withOpacity(0.85),
          ),
        ),
      ],
    ),
  );
}

Widget _buildSection({
  required IconData icon,
  required String title,
  required String content,
}) {
  return Container(
    margin: const EdgeInsets.only(bottom: 16),
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(AppRadius.md),
      border: Border.all(color: AppColors.border),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.02),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: AppColors.brand, size: 20),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                title,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
            ),
          ],
        ),
        const Divider(height: 24),
        Text(
          content,
          style: GoogleFonts.outfit(
            fontSize: 14,
            height: 1.5,
            color: AppColors.textPrimary.withOpacity(0.8),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    ),
  );
}
