import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:quran/quran.dart';
import 'package:tahfeex/resources/resources.dart';
import 'package:tahfeex/screens/legal_screen.dart';
import 'package:tahfeex/service/states/app_settings_state.dart';
import 'package:tahfeex/shared/constants/constants.dart';
import 'package:tahfeex/widgets/app_route.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  // null = not yet checked
  AuthorizationStatus? _notifStatus;

  @override
  void initState() {
    super.initState();
    _checkNotifPermission();
  }

  Future<void> _checkNotifPermission() async {
    final settings =
        await FirebaseMessaging.instance.getNotificationSettings();
    if (mounted) {
      setState(() => _notifStatus = settings.authorizationStatus);
    }
  }

  bool get _systemNotifAllowed =>
      _notifStatus == AuthorizationStatus.authorized ||
      _notifStatus == AuthorizationStatus.provisional;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: BlocBuilder<SettingsCubit, SettingsState>(
        builder: (context, state) {
          final cubit = context.read<SettingsCubit>();
          final arabicSize  = (state.arabicTextSize  ?? 24).toDouble().clamp(16.0, 48.0);
          final englishSize = (state.englishTextSize ?? 14).toDouble().clamp(11.0, 22.0);

          return SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(
              AppSizes.pagePadding, 24,
              AppSizes.pagePadding, 40,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [

                // ── Reading ─────────────────────────────────────────────────
                _sectionLabel('READING'),
                _SettingsCard(
                  children: [
                    // Arabic font size
                    _SliderRow(
                      label: 'Arabic text size',
                      value: arabicSize,
                      min: 16,
                      max: 48,
                      onChanged: (v) =>
                          cubit.updateArabicTextSize(v.round()),
                      preview: Text(
                        getVerse(1, 1),
                        textAlign: TextAlign.right,
                        style: GoogleFonts.amiriQuran(
                          fontSize: arabicSize,
                          color: AppColors.textPrimary,
                          height: 1.8,
                        ),
                      ),
                    ),
                    const _Hairline(),
                    // Translation font size
                    _SliderRow(
                      label: 'Translation text size',
                      value: englishSize,
                      min: 11,
                      max: 22,
                      onChanged: (v) =>
                          cubit.updateEnglishTextSize(v.round()),
                      preview: Text(
                        getVerseTranslation(1, 1),
                        style: TextStyle(
                          fontSize: englishSize,
                          color: AppColors.textSecondary,
                          height: 1.6,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // ── Notifications ────────────────────────────────────────────
                _sectionLabel('NOTIFICATIONS'),

                // System permission banner
                if (_notifStatus != null && !_systemNotifAllowed)
                  _PermissionBanner(onRefresh: _checkNotifPermission),

                _SettingsCard(
                  children: [
                    _ToggleRow(
                      icon: Icons.alarm_outlined,
                      label: 'Journey reminders',
                      subtitle: 'Scheduled alarms for your reading goals',
                      value: state.journeyRemindersEnabled,
                      enabled: _systemNotifAllowed,
                      onChanged: cubit.setJourneyReminders,
                    ),
                    const _Hairline(),
                    _ToggleRow(
                      icon: Icons.notifications_outlined,
                      label: 'Companion nudges',
                      subtitle: 'When a companion encourages you',
                      value: state.nudgeNotificationsEnabled,
                      enabled: _systemNotifAllowed,
                      onChanged: cubit.setNudgeNotifications,
                    ),
                    const _Hairline(),
                    _ToggleRow(
                      icon: Icons.people_outline,
                      label: 'Companion activity',
                      subtitle: 'When a companion makes progress',
                      value: state.companionActivityEnabled,
                      enabled: _systemNotifAllowed,
                      onChanged: cubit.setCompanionActivity,
                    ),
                  ],
                ),
                const SizedBox(height: 28),

                // ── About ────────────────────────────────────────────────────
                _sectionLabel('ABOUT'),
                _SettingsCard(
                  children: [
                    _InfoRow(label: 'Version', value: '1.0.0'),
                    const _Hairline(),
                    _LinkRow(
                      label: 'Privacy Policy',
                      onTap: () => Navigator.push(
                        context,
                        AppRoute(
                          builder: (_) => const LegalScreen(
                            document: LegalDocument.privacyPolicy,
                          ),
                        ),
                      ),
                    ),
                    const _Hairline(),
                    _LinkRow(
                      label: 'Terms & Conditions',
                      onTap: () => Navigator.push(
                        context,
                        AppRoute(
                          builder: (_) => const LegalScreen(
                            document: LegalDocument.termsAndConditions,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.8,
            color: AppColors.textSecondary,
          ),
        ),
      );
}

// ── Card wrapper ──────────────────────────────────────────────────────────────

class _SettingsCard extends StatelessWidget {
  final List<Widget> children;
  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        border: const Border.fromBorderSide(BorderSide(color: AppColors.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _Hairline extends StatelessWidget {
  const _Hairline();
  @override
  Widget build(BuildContext context) =>
      const Divider(height: 1, indent: 16, endIndent: 16, color: AppColors.border);
}

// ── Slider row with live preview ──────────────────────────────────────────────

class _SliderRow extends StatelessWidget {
  final String label;
  final double value;
  final double min;
  final double max;
  final ValueChanged<double> onChanged;
  final Widget preview;

  const _SliderRow({
    required this.label,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    required this.preview,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  value.round().toString(),
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ],
          ),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 2,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 8),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 16),
              activeTrackColor: AppColors.primary,
              inactiveTrackColor: AppColors.border,
              thumbColor: AppColors.primary,
              overlayColor: AppColors.primary.withValues(alpha: 0.12),
            ),
            child: Slider(
              value: value,
              min: min,
              max: max,
              divisions: (max - min).round(),
              onChanged: onChanged,
            ),
          ),
          // Live preview
          Container(
            width: double.infinity,
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
            decoration: BoxDecoration(
              color: const Color(0xFFFAF8F2),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: const Color(0xFFE4D9CA)),
            ),
            child: preview,
          ),
        ],
      ),
    );
  }
}

// ── Toggle row ────────────────────────────────────────────────────────────────

class _ToggleRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String subtitle;
  final bool value;
  final bool enabled;
  final ValueChanged<bool> onChanged;

  const _ToggleRow({
    required this.icon,
    required this.label,
    required this.subtitle,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon,
              size: 20,
              color: enabled ? AppColors.primary : AppColors.textSecondary),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: enabled
                        ? AppColors.textPrimary
                        : AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: const TextStyle(
                      fontSize: 12, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          Switch(
            value: value && enabled,
            onChanged: enabled ? onChanged : null,
            activeTrackColor: AppColors.primary,
          ),
        ],
      ),
    );
  }
}

// ── Info row (non-interactive) ────────────────────────────────────────────────

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;
  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Expanded(
            child: Text(label,
                style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary)),
          ),
          Text(value,
              style: const TextStyle(
                  fontSize: 14, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

// ── Link row (tappable, navigates away) ──────────────────────────────────────

class _LinkRow extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  const _LinkRow({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Row(
          children: [
            Expanded(
              child: Text(label,
                  style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary)),
            ),
            const Icon(Icons.chevron_right,
                size: 18, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ── Permission denied banner ──────────────────────────────────────────────────

class _PermissionBanner extends StatelessWidget {
  final VoidCallback onRefresh;
  const _PermissionBanner({required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.amber.shade50,
        borderRadius: BorderRadius.circular(AppSizes.cardRadius),
        border: Border.all(color: Colors.amber.shade200),
      ),
      child: Row(
        children: [
          Icon(Icons.notifications_off_outlined,
              size: 18, color: Colors.amber.shade700),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Notifications are disabled in system settings. Enable them to use these options.',
              style: TextStyle(
                  fontSize: 12,
                  color: Colors.amber.shade800,
                  height: 1.4),
            ),
          ),
          GestureDetector(
            onTap: onRefresh,
            child: Icon(Icons.refresh,
                size: 18, color: Colors.amber.shade700),
          ),
        ],
      ),
    );
  }
}
