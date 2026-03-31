import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran/quran.dart';
import 'package:tahfeex/model/companion_models.dart';
import 'package:tahfeex/model/journey_model.dart';
import 'package:tahfeex/resources/resources.dart';
import 'package:tahfeex/screens/journey_detail_screen.dart';
import 'package:tahfeex/service/states/states.dart';

class UserProfileScreen extends StatelessWidget {
  final String username;
  const UserProfileScreen({super.key, required this.username});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<UserProfileCubit>(
      create: (_) => UserProfileCubit(username),
      child: const _UserProfileView(),
    );
  }
}

class _UserProfileView extends StatelessWidget {
  const _UserProfileView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<UserProfileCubit, UserProfileState>(
      builder: (context, state) {
        final cubit = context.read<UserProfileCubit>();

        if (state.isLoading && state.profile == null) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primaryColor),
            ),
          );
        }

        if (state.error != null && state.profile == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.person_off_outlined,
                      size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
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

        final profile = state.profile!;

        return Scaffold(
          appBar: AppBar(
            title: Text('@${profile.username}'),
            actions: [
              if (state.isLoading || state.isActing)
                const Padding(
                  padding: EdgeInsets.only(right: 8),
                  child: Center(
                    child: SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white),
                    ),
                  ),
                ),
              PopupMenuButton<String>(
                onSelected: (value) =>
                    _onMenuAction(context, cubit, profile, value),
                itemBuilder: (_) => [
                  if (profile.relationship?.isBlocked == true)
                    const PopupMenuItem(
                      value: 'unblock',
                      child: Text('Unblock'),
                    )
                  else
                    const PopupMenuItem(
                      value: 'block',
                      child: Text('Block',
                          style: TextStyle(color: Colors.red)),
                    ),
                ],
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
                  // ── Avatar + name ──────────────────────────────────────
                  Center(
                    child: Column(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor:
                              AppColors.primaryColor.withValues(alpha: 0.15),
                          child: Text(
                            profile.initial,
                            style: const TextStyle(
                              fontSize: 32,
                              fontWeight: FontWeight.bold,
                              color: AppColors.primaryColor,
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text(
                          profile.name,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.bold),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '@${profile.username}',
                          style: TextStyle(
                              fontSize: 13, color: Colors.grey[600]),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),

                  // ── Stats ──────────────────────────────────────────────
                  Row(
                    children: [
                      Expanded(
                        child: _StatBox(
                          value: '${profile.stats.totalCompanions}',
                          label: 'Companions',
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StatBox(
                          value: '${profile.stats.completedAyahs}',
                          label: 'Ayahs done',
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Relationship action button ──────────────────────────
                  if (profile.relationship != null)
                    _RelationshipButton(
                      state: state,
                      relationship: profile.relationship!,
                      cubit: cubit,
                    ),

                  if (state.actionError != null) ...[
                    const SizedBox(height: 8),
                    Text(state.actionError!,
                        style:
                            const TextStyle(color: Colors.red, fontSize: 12)),
                  ],

                  // ── Journeys (companions only) ──────────────────────────
                  if (profile.relationship?.isCompanion == true &&
                      profile.journeys != null) ...[
                    const SizedBox(height: 28),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        'JOURNEYS',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Colors.grey[500],
                          letterSpacing: 0.8,
                        ),
                      ),
                    ),
                    if (profile.journeys!.isEmpty)
                      Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 20),
                          child: Text(
                            'No active journeys',
                            style: TextStyle(color: Colors.grey[500]),
                          ),
                        ),
                      )
                    else
                      ...profile.journeys!.map(
                        (j) => Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: _JourneyTile(
                            journey: j,
                            profileUsername: profile.username,
                          ),
                        ),
                      ),
                  ],
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Future<void> _onMenuAction(
    BuildContext context,
    UserProfileCubit cubit,
    UserProfile profile,
    String value,
  ) async {
    if (value == 'block') {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Block this user?'),
          content: const Text(
              'They will be removed as a companion and cannot send you requests.'),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel')),
            TextButton(
              style: TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Block'),
            ),
          ],
        ),
      );
      if (confirmed == true) await cubit.block();
    } else if (value == 'unblock') {
      await cubit.unblock();
    }
  }
}

// ── Relationship button ───────────────────────────────────────────────────────

class _RelationshipButton extends StatelessWidget {
  final UserProfileState state;
  final UserRelationship relationship;
  final UserProfileCubit cubit;

  const _RelationshipButton({
    required this.state,
    required this.relationship,
    required this.cubit,
  });

  @override
  Widget build(BuildContext context) {
    if (relationship.isBlocked) {
      return _actionButton(
        label: 'Unblock',
        icon: Icons.block,
        onPressed: cubit.unblock,
        color: Colors.grey[700]!,
        outlined: true,
      );
    }
    if (relationship.isCompanion) {
      return _actionButton(
        label: 'Remove Companion',
        icon: Icons.person_remove_outlined,
        onPressed: () => _confirmRemove(context),
        color: Colors.red[400]!,
        outlined: true,
      );
    }
    if (relationship.sentRequest) {
      return _actionButton(
        label: 'Request Sent',
        icon: Icons.schedule,
        onPressed: cubit.cancelRequest,
        color: Colors.grey[600]!,
        outlined: true,
      );
    }
    if (relationship.receivedRequest) {
      return _actionButton(
        label: 'Accept Request',
        icon: Icons.person_add,
        onPressed: cubit.acceptRequest,
        color: AppColors.primaryColor,
      );
    }
    // No relationship
    return _actionButton(
      label: 'Add Companion',
      icon: Icons.person_add_outlined,
      onPressed: cubit.sendRequest,
      color: AppColors.primaryColor,
    );
  }

  Widget _actionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    required Color color,
    bool outlined = false,
  }) {
    final child = Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (state.isActing)
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else ...[
          Icon(icon, size: 18),
          const SizedBox(width: 6),
          Text(label,
              style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ],
    );

    if (outlined) {
      return SizedBox(
        width: double.infinity,
        child: OutlinedButton(
          onPressed: state.isActing ? null : onPressed,
          style: OutlinedButton.styleFrom(
            foregroundColor: color,
            side: BorderSide(color: color),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          child: child,
        ),
      );
    }

    return SizedBox(
      width: double.infinity,
      child: FilledButton(
        onPressed: state.isActing ? null : onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: color,
          padding: const EdgeInsets.symmetric(vertical: 12),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(10)),
        ),
        child: child,
      ),
    );
  }

  Future<void> _confirmRemove(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove companion?'),
        content: const Text('You will no longer see each other\'s journeys.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed == true) await cubit.removeCompanion();
  }
}

// ── Stat box ──────────────────────────────────────────────────────────────────

class _StatBox extends StatelessWidget {
  final String value;
  final String label;
  const _StatBox({required this.value, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        children: [
          Text(value,
              style: const TextStyle(
                  fontSize: 22, fontWeight: FontWeight.bold)),
          const SizedBox(height: 2),
          Text(label,
              style:
                  TextStyle(fontSize: 12, color: Colors.grey[600])),
        ],
      ),
    );
  }
}

// ── Journey tile ──────────────────────────────────────────────────────────────

class _JourneyTile extends StatelessWidget {
  final Journey journey;
  /// The username of the profile being viewed — used to look up their member.
  final String profileUsername;
  const _JourneyTile({required this.journey, required this.profileUsername});

  @override
  Widget build(BuildContext context) {
    // Find the profile user's member entry.  We don't have their uid here,
    // so we use the first member that matches the aggregate status as a fallback,
    // or just show aggregate-level data.
    // Since JourneyDetail includes members, we pick the one whose completedCount
    // is highest or just use the first non-current-user member. For a companion's
    // profile, the journey belongs to them so we show aggregate progress.
    final completedCount = journey.members.isNotEmpty
        ? journey.members.first.completedCount
        : 0;
    final fraction = journey.totalAyahs > 0
        ? completedCount / journey.totalAyahs
        : 0.0;

    return GestureDetector(
      onTap: () => Navigator.push(
        context,
        MaterialPageRoute(
            builder: (_) => JourneyDetailScreen(journeyId: journey.id)),
      ),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.grey[200]!),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    journey.title,
                    style: const TextStyle(
                        fontWeight: FontWeight.w600, fontSize: 14),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                _StatusChip(status: journey.status),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              '${getSurahName(journey.startSurah)} → ${getSurahName(journey.endSurah)}',
              style: TextStyle(fontSize: 12, color: Colors.grey[600]),
            ),
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(3),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 5,
                backgroundColor: Colors.grey[200],
                color: fraction >= 1.0
                    ? Colors.teal
                    : AppColors.primaryColor,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '$completedCount/${journey.totalAyahs} ayahs',
              style:
                  TextStyle(fontSize: 11, color: Colors.grey[500]),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String status;
  const _StatusChip({required this.status});

  @override
  Widget build(BuildContext context) {
    final isCompleted = status == 'completed';
    final isPaused    = status == 'paused';
    final isAbandoned = status == 'abandoned';

    final (label, color) = isCompleted
        ? ('Completed', Colors.teal)
        : isPaused
            ? ('Paused', Colors.orange)
            : isAbandoned
                ? ('Abandoned', Colors.red)
                : ('Active', AppColors.primaryColor);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(
            fontSize: 11, color: color, fontWeight: FontWeight.w600),
      ),
    );
  }
}
