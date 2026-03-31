import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tahfeex/resources/resources.dart';
import 'package:tahfeex/service/auth_service.dart';
import 'package:tahfeex/service/states/states.dart';
import 'package:tahfeex/shared/models/models.dart';

class MyProfileScreen extends StatelessWidget {
  const MyProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<ProfileCubit, ProfileState>(
      builder: (context, state) {
        final cubit = context.read<ProfileCubit>();

        if (state.isLoading && state.user == null) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primaryColor),
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
                  const Icon(Icons.cloud_off, size: 40, color: Colors.grey),
                  const SizedBox(height: 10),
                  Text(state.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 14),
                  OutlinedButton(
                      onPressed: cubit.load, child: const Text('Retry')),
                ],
              ),
            ),
          );
        }

        final user = state.user!;
        final firebaseUser = FirebaseAuth.instance.currentUser;
        final photoUrl = firebaseUser?.photoURL;

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
            color: AppColors.primaryColor,
            onRefresh: cubit.load,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 28, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Avatar + name ────────────────────────────────────────
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor:
                              AppColors.primaryColor.withValues(alpha: 0.15),
                          backgroundImage: photoUrl != null
                              ? NetworkImage(photoUrl)
                              : null,
                          child: photoUrl == null
                              ? Text(
                                  user.initial,
                                  style: const TextStyle(
                                    fontSize: 32,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.primaryColor,
                                  ),
                                )
                              : null,
                        ),
                        const SizedBox(height: 12),
                        Text(
                          user.name,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          user.email,
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 32),

                  // ── Username ─────────────────────────────────────────────
                  _sectionLabel('USERNAME'),
                  _InfoCard(
                    child: Row(
                      children: [
                        Expanded(
                          child: Text(
                            '@${user.username}',
                            style: const TextStyle(
                                fontSize: 15, fontWeight: FontWeight.w500),
                          ),
                        ),
                        TextButton(
                          onPressed: () =>
                              _showEditUsernameDialog(context, cubit, user.username),
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
                                    fontWeight: FontWeight.w500),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Others can send you companion requests',
                                style: TextStyle(
                                    fontSize: 12, color: Colors.grey[600]),
                              ),
                            ],
                          ),
                        ),
                        Switch(
                          value: user.allowFriendRequests,
                          onChanged: state.isSaving
                              ? null
                              : (_) => cubit.toggleAllowFriendRequests(),
                          activeTrackColor: AppColors.primaryColor,
                        ),
                      ],
                    ),
                  ),

                  if (state.saveError != null) ...[
                    const SizedBox(height: 8),
                    Text(state.saveError!,
                        style:
                            const TextStyle(color: Colors.red, fontSize: 12)),
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
                        padding: const EdgeInsets.symmetric(vertical: 12),
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
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.grey[500],
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
    setState(() {
      _loading = true;
      _error = null;
    });
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
      setState(() {
        _loading = false;
        _error = e.toString();
      });
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
              backgroundColor: AppColors.primaryColor),
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
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: child,
    );
  }
}
