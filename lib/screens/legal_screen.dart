import 'package:flutter/material.dart';
import 'package:tahfeex/resources/resources.dart';

// ─────────────────────────────────────────────────────────────────────────────
// Shared legal content screen — used for both Privacy Policy and T&C.
// ─────────────────────────────────────────────────────────────────────────────

enum LegalDocument { privacyPolicy, termsAndConditions }

class LegalScreen extends StatelessWidget {
  final LegalDocument document;
  const LegalScreen({super.key, required this.document});

  @override
  Widget build(BuildContext context) {
    final isPrivacy = document == LegalDocument.privacyPolicy;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        title: Text(isPrivacy ? 'Privacy Policy' : 'Terms & Conditions'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 28, 20, 48),
        children: isPrivacy ? _privacySections : _termsSections,
      ),
    );
  }
}

// ── Section widget ────────────────────────────────────────────────────────────

class _Section extends StatelessWidget {
  final String? heading;
  final String body;
  const _Section({this.heading, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (heading != null) ...[
            Text(
              heading!,
              style: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
                letterSpacing: 0.1,
              ),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            body,
            textAlign: TextAlign.justify,
            style: const TextStyle(
              fontSize: 14,
              height: 1.75,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

Widget _effectiveDate(String date) => Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Text(
        'Effective date: $date',
        style: const TextStyle(
          fontSize: 12,
          color: AppColors.textSecondary,
          fontStyle: FontStyle.italic,
        ),
      ),
    );

// ─────────────────────────────────────────────────────────────────────────────
// Privacy Policy content
// ─────────────────────────────────────────────────────────────────────────────

const _privacySections = <Widget>[
  _Section(
    body:
        'Your privacy matters to us. This policy explains what information Divine Traveler collects, how it is used, and the choices you have.',
  ),
  _Section(
    heading: '1. Information We Collect',
    body:
        'We collect the information you provide when you create an account via Google Sign-In, '
        'including your name, email address, and profile photo. We also collect data you generate '
        'while using the app — such as your reading journeys, daily progress, and companion connections.',
  ),
  _Section(
    heading: '2. How We Use Your Information',
    body:
        'We use your information to provide and improve the app\'s features, sync your progress '
        'across devices, send you notifications you have opted into, and support companion '
        'features that connect you with other users.',
  ),
  _Section(
    heading: '3. Data Sharing',
    body:
        'We do not sell your personal information. We may share data with trusted service '
        'providers (such as Firebase/Google) solely to operate the app. Your journey progress '
        'may be visible to companions you explicitly add.',
  ),
  _Section(
    heading: '4. Data Retention',
    body:
        'We retain your data for as long as your account is active. You may delete your account '
        'at any time from your profile settings, which will permanently remove your data from '
        'our systems.',
  ),
  _Section(
    heading: '5. Security',
    body:
        'We use industry-standard security practices including encrypted transport (HTTPS) and '
        'Firebase Authentication. No method of transmission or storage is 100% secure, but we '
        'take reasonable measures to protect your information.',
  ),
  _Section(
    heading: '6. Children\'s Privacy',
    body:
        'Divine Traveler is not directed at children under 13. We do not knowingly collect '
        'personal information from children under 13. If you believe we have inadvertently '
        'collected such information, please contact us so we can remove it.',
  ),
  _Section(
    heading: '7. Changes to This Policy',
    body:
        'We may update this Privacy Policy from time to time. We will notify you of significant '
        'changes through the app or by email. Continued use of the app after changes constitutes '
        'your acceptance of the updated policy.',
  ),
  _Section(
    heading: '8. Contact Us',
    body:
        'If you have questions or concerns about this Privacy Policy, please reach out to us at '
        'support@divinetraveler.app.',
  ),
];

// ─────────────────────────────────────────────────────────────────────────────
// Terms & Conditions content
// ─────────────────────────────────────────────────────────────────────────────

const _termsSections = <Widget>[
  _Section(
    body:
        'Please read these Terms and Conditions carefully before using Divine Traveler. '
        'By creating an account or using the app, you agree to be bound by these terms.',
  ),
  _Section(
    heading: '1. Acceptance of Terms',
    body:
        'By accessing or using Divine Traveler, you confirm that you are at least 13 years '
        'of age and agree to these Terms. If you do not agree, please do not use the app.',
  ),
  _Section(
    heading: '2. Your Account',
    body:
        'You are responsible for maintaining the confidentiality of your account and for all '
        'activities that occur under it. You agree to provide accurate information and to '
        'notify us immediately of any unauthorised use.',
  ),
  _Section(
    heading: '3. Acceptable Use',
    body:
        'You agree to use the app only for lawful purposes and in a manner that does not '
        'infringe the rights of others. You must not upload, post, or transmit any content '
        'that is offensive, defamatory, or in violation of any applicable law.',
  ),
  _Section(
    heading: '4. Intellectual Property',
    body:
        'The app, including its design, code, and original content, is owned by Divine Traveler '
        'and protected by applicable intellectual property laws. Quranic text and translations '
        'are used under their respective open licences.',
  ),
  _Section(
    heading: '5. Companion Features',
    body:
        'The companion system allows you to connect with other users to share progress and '
        'send encouragements. You agree not to harass, spam, or misuse these features. We '
        'reserve the right to remove connections or accounts that violate this policy.',
  ),
  _Section(
    heading: '6. Disclaimer of Warranties',
    body:
        'The app is provided "as is" without warranties of any kind, express or implied. We '
        'do not guarantee that the app will be uninterrupted, error-free, or free of viruses '
        'or other harmful components.',
  ),
  _Section(
    heading: '7. Limitation of Liability',
    body:
        'To the fullest extent permitted by law, Divine Traveler shall not be liable for any '
        'indirect, incidental, or consequential damages arising from your use of the app.',
  ),
  _Section(
    heading: '8. Termination',
    body:
        'We reserve the right to suspend or terminate your account at our discretion if you '
        'violate these Terms. You may also delete your account at any time from your profile.',
  ),
  _Section(
    heading: '9. Changes to Terms',
    body:
        'We may revise these Terms from time to time. We will notify you of material changes '
        'through the app. Your continued use of the app after changes constitutes acceptance.',
  ),
  _Section(
    heading: '10. Contact',
    body:
        'For questions about these Terms, contact us at support@divinetraveler.app.',
  ),
];
