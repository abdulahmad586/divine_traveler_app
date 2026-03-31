import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tahfeex/resources/resources.dart';
import 'package:tahfeex/screens/audio_surahs_screen.dart';
import 'package:tahfeex/screens/companions_screen.dart';
import 'package:tahfeex/screens/journey_list_screen.dart';
import 'package:tahfeex/service/auth_service.dart';
import 'package:tahfeex/service/states/states.dart';
import 'package:tahfeex/shared/constants/constants.dart';
import 'package:tahfeex/shared/models/models.dart';
import 'package:tahfeex/shared/progression/user_progression.dart';
import 'package:tahfeex/widgets/app_route.dart';

class MyProfileScreen extends StatelessWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<ProfileCubit>(
      create: (_) => ProfileCubit(),
      child: const _MyProfileView(),
    );
  }
}

class _MyProfileView extends StatelessWidget {
  const _MyProfileView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        final cubit = context.read<ProfileCubit>();

        if (state.isLoading && state.user == null) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          );
        }

        if (state.error != null && state.user == null) {
          return Scaffold(
            appBar: AppBar(title: const Text('My Profile')),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.cloud_off,
                      size: 40, color: AppColors.textSecondary),
                  const SizedBox(height: 10),
                  Text(state.error!,
                      textAlign: TextAlign.center,
                      style:
                          const TextStyle(color: AppColors.textSecondary)),
                  const SizedBox(height: 14),
                  OutlinedButton(
                      onPressed: cubit.load, child: const Text('Retry')),
                ],
              ),
            ),
          );
        }

        final user        = state.user!;
        final firebaseUser = FirebaseAuth.instance.currentUser;
        final photoUrl    = firebaseUser?.photoURL;

        return Scaffold(
          appBar: AppBar(
            title: const Text('My Profile'),
            actions: [
              if (state.isLoading || state.isSaving)
                const Padding(
                  padding: EdgeInsets.only(right: 16),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    ),
                  ),
                ),
            ],
          ),
          body: RefreshIndicator(
            color: AppColors.primary,
            onRefresh: cubit.load,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppSizes.pagePadding, 28,
                AppSizes.pagePadding, 40,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Avatar + name + email ────────────────────────────────
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor:
                              AppColors.primary.withValues(alpha: 0.12),
                          backgroundImage: photoUrl != null
                              ? NetworkImage(photoUrl)
                              : null,
                          child: photoUrl == null
                              ? Text(
                                  user.initial,
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primary,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          user.name,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          style: const TextStyle(
                              fontSize: 13,
                              color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '@${user.username}',
                          style: const TextStyle(
                            fontSize: 13,
                            color: AppColors.primaryMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── My Journeys ──────────────────────────────────────────
                  _sectionLabel('JOURNEYS'),
                  _NavRow(
                    icon: Icons.route_outlined,
                    label: 'My Journeys',
                    onTap: () => Navigator.push(
                      context,
                      AppRoute(
                          builder: (_) => const JourneyListScreen()),
                    ),
                  ),
                  const SizedBox(height: 8),
                  _NavRow(
                    icon: Icons.people_outline,
                    label: 'Companions',
                    subtitle: 'Journeying together',
                    onTap: () => Navigator.push(
                      context,
                      AppRoute(
                          builder: (_) => const CompanionsScreen()),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Contributions ────────────────────────────────────────
                  if (UserProgression().hasCompletedJourney) ...[
                    _sectionLabel('CONTRIBUTIONS'),
                    _NavRow(
                      icon: Icons.headphones_outlined,
                      label: 'Audio Recordings',
                      subtitle: 'Manage your contributed recitations',
                      onTap: () => Navigator.push(
                        context,
                        AppRoute(
                            builder: (_) => const AudioSurahScreen()),
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Account ──────────────────────────────────────────────
                  _sectionLabel('ACCOUNT'),
                  _InfoCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Username',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '@${user.username}',
                                style: const TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        TextButton(
                          onPressed: () => _showEditUsernameDialog(
                              context, cubit, user.username),
                          child: const Text('Change'),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Settings ─────────────────────────────────────────────
                  _sectionLabel('SETTINGS'),
                  _InfoCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Allow companion requests',
                                style: TextStyle(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w500,
                                    color: AppColors.textPrimary),
                              ),
                              const SizedBox(height: 2),
                              const Text(
                                'Others can send you companion requests',
                                style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: user.allowFriendRequests,
                          onChanged: state.isSaving
                              ? null
                              : (_) => cubit.toggleAllowFriendRequests(),
                          activeTrackColor: AppColors.primary,
                        ),
                      ],
                    ),
                  ),

                  if (state.saveError != null) ...[
                    const SizedBox(height: 8),
                    Text(state.saveError!,
                        style: const TextStyle(
                            color: Colors.red, fontSize: 12)),
                  ],
                  const SizedBox(height: 32),

                  // ── Sign out ─────────────────────────────────────────────
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      onPressed: () => AuthService().signOut(),
                      icon: const Icon(Icons.logout),
                      label: const Text('Sign Out'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: Colors.red[400],
                        side: BorderSide(color: Colors.red[300]!),
                        padding:
                            const EdgeInsets.symmetric(vertical: 12),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(10)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sectionLabel(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text,
          style: const TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: AppColors.textSecondary,
            letterSpacing: 0.8,
          ),
        ),
      );

  Future<void> _showEditUsernameDialog(
    BuildContext context,
    ProfileCubit cubit,
    String current,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _EditUsernameDialog(cubit: cubit, current: current),
    );
  }
}

// ── Navigation row ────────────────────────────────────────────────────────────

class _NavRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? subtitle;
  final VoidCallback onTap;

  const _NavRow({
    required this.icon,
    required this.label,
    required this.onTap,
    this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(12),
          border: const Border.fromBorderSide(
              BorderSide(color: AppColors.border)),
        ),
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textPrimary,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 2),
                    Text(
                      subtitle!,
                      style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary),
                    ),
                  ],
                ],
              ),
            ),
            const Icon(Icons.chevron_right,
                size: 20, color: AppColors.textSecondary),
          ],
        ),
      ),
    );
  }
}

// ── Edit username dialog ──────────────────────────────────────────────────────

class _EditUsernameDialog extends StatefulWidget {
  final ProfileCubit cubit;
  final String current;
  const _EditUsernameDialog({required this.cubit, required this.current});

  @override
  State<_EditUsernameDialog> createState() => _EditUsernameDialogState();
}

class _EditUsernameDialogState extends State<_EditUsernameDialog> {
  late final TextEditingController _controller;
  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.current);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final value = _controller.text.trim();
    if (value == widget.current) {
      Navigator.pop(context);
      return;
    }
    setState(() { _loading = true; _error = null; });
    try {
      await widget.cubit.updateUsername(value);
      if (!mounted) return;
      Navigator.pop(context);
    } on ApiException catch (e) {
      setState(() {
        _loading = false;
        _error = e.isUsernameTaken
            ? 'This username is already taken'
            : e.message;
      });
    } catch (e) {
      setState(() { _loading = false; _error = e.toString(); });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Change Username'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'new_username',
              prefixText: '@',
              border: OutlineInputBorder(),
              helperText: '3–40 chars · letters, numbers, . _ -',
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _save(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style: const TextStyle(color: Colors.red, fontSize: 13)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loading ? null : _save,
          style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary),
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}

// ── Shared card wrapper ───────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final Widget child;
  const _InfoCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: AppColors.cardSurface,
        borderRadius: BorderRadius.circular(12),
        border: const Border.fromBorderSide(
            BorderSide(color: AppColors.border)),
      ),
      child: child,
    );
  }
}
