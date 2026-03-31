import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tahfeex/model/app_user_model.dart';
import 'package:tahfeex/resources/resources.dart';
import 'package:tahfeex/screens/incoming_requests_screen.dart';
import 'package:tahfeex/screens/user_profile_screen.dart';
import 'package:tahfeex/service/states/states.dart';
import 'package:tahfeex/shared/constants/constants.dart';
import 'package:tahfeex/shared/models/models.dart';
import 'package:tahfeex/widgets/app_route.dart';

class CompanionsScreen extends StatelessWidget {
  const CompanionsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<CompanionsCubit, CompanionsState>(
      builder: (context, state) {
        final cubit = context.read<CompanionsCubit>();
        return Scaffold(
          appBar: AppBar(
            title: const Text('Companions'),
            actions: [
              if (state.isLoading && state.companions != null)
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
            child: _buildBody(context, state, cubit),
          ),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    CompanionsState state,
    CompanionsCubit cubit,
  ) {
    if (state.isLoading && state.companions == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      );
    }

    if (state.error != null && state.companions == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
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

    final companions = state.companions ?? [];

    return ListView(
      physics: const AlwaysScrollableScrollPhysics(),
      children: [
        // ── Add companion button ───────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: OutlinedButton.icon(
            onPressed: () => _showAddDialog(context, cubit),
            icon: const Icon(Icons.person_add_outlined),
            label: const Text('Add Companion'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 12),
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10)),
            ),
          ),
        ),

        // ── Incoming requests card ─────────────────────────────────────────
        if (state.incomingCount > 0)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: InkWell(
              onTap: () => _openIncoming(context, cubit),
              borderRadius: BorderRadius.circular(AppSizes.cardRadius),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.06),
                  borderRadius: BorderRadius.circular(AppSizes.cardRadius),
                  border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.25)),
                ),
                child: Row(
                  children: [
                    Icon(Icons.people_outline,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        '${state.incomingCount} pending companion ${state.incomingCount == 1 ? 'request' : 'requests'}',
                        style: const TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textPrimary),
                      ),
                    ),
                    const Icon(Icons.chevron_right,
                        size: 18, color: AppColors.textSecondary),
                  ],
                ),
              ),
            ),
          ),

        if (companions.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 60, horizontal: 32),
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.people_outline,
                      size: 52, color: AppColors.textSecondary),
                  SizedBox(height: 12),
                  Text(
                    'Companions join you on the path.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary),
                  ),
                  SizedBox(height: 6),
                  Text(
                    'Invite someone when you\'re ready.',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 13, color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
          )
        else
          ...companions.map(
            (c) => _CompanionTile(
              companion: c,
              onTap: () => _openProfile(context, cubit, c.username),
            ),
          ),
      ],
    );
  }

  Future<void> _showAddDialog(
      BuildContext context, CompanionsCubit cubit) async {
    await showDialog<void>(
      context: context,
      builder: (_) => _AddCompanionDialog(cubit: cubit),
    );
  }

  Future<void> _openProfile(
      BuildContext context, CompanionsCubit cubit, String username) async {
    await Navigator.push(
      context,
      AppRoute(builder: (_) => UserProfileScreen(username: username)),
    );
    cubit.load(); // refresh after returning (companion may have been removed)
  }

  Future<void> _openIncoming(
      BuildContext context, CompanionsCubit cubit) async {
    await Navigator.push(
      context,
      AppRoute(
        builder: (_) => BlocProvider.value(
          value: cubit,
          child: const IncomingRequestsScreen(),
        ),
      ),
    );
    cubit.load();
  }
}

// ── Companion tile ────────────────────────────────────────────────────────────

class _CompanionTile extends StatelessWidget {
  final AppUser companion;
  final VoidCallback onTap;

  const _CompanionTile({required this.companion, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: AppColors.primary.withValues(alpha: 0.15),
        child: Text(
          companion.initial,
          style: const TextStyle(
              color: AppColors.primary, fontWeight: FontWeight.bold),
        ),
      ),
      title: Text(companion.name,
          style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text('@${companion.username}',
          style: TextStyle(fontSize: 12, color: Colors.grey[600])),
      trailing: const Icon(Icons.chevron_right, color: Colors.grey),
      onTap: onTap,
    );
  }
}

// ── Add companion dialog ──────────────────────────────────────────────────────

class _AddCompanionDialog extends StatefulWidget {
  final CompanionsCubit cubit;
  const _AddCompanionDialog({required this.cubit});

  @override
  State<_AddCompanionDialog> createState() => _AddCompanionDialogState();
}

class _AddCompanionDialogState extends State<_AddCompanionDialog> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final username = _controller.text.trim();
    if (username.isEmpty) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final autoAccepted = await widget.cubit.sendRequest(username);
      if (!mounted) return;
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(autoAccepted
            ? 'You and @$username are now companions!'
            : 'Request sent to @$username'),
        backgroundColor:
            autoAccepted ? Colors.teal : null,
      ));
    } on ApiException catch (e) {
      setState(() {
        _loading = false;
        if (e.isAlreadyCompanions) {
          _error = 'You are already companions with @$username';
        } else if (e.isRequestAlreadySent) {
          _error = 'You already sent a request to @$username';
        } else if (e.isForbidden) {
          _error = '@$username is not accepting companion requests';
        } else if (e.isNotFound) {
          _error = 'No user found with username @$username';
        } else {
          _error = e.message;
        }
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
      title: const Text('Add Companion'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _controller,
            autofocus: true,
            decoration: const InputDecoration(
              hintText: 'Enter username',
              prefixText: '@',
              border: OutlineInputBorder(),
            ),
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _submit(),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(_error!,
                style:
                    const TextStyle(color: Colors.red, fontSize: 13)),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: _loading ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _loading ? null : _submit,
          style: FilledButton.styleFrom(
              backgroundColor: AppColors.primary),
          child: _loading
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Text('Send Request'),
        ),
      ],
    );
  }
}
