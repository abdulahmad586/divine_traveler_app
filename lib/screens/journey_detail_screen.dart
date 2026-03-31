import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:quran/quran.dart';
import 'package:tahfeex/model/journey_alarm.dart';
import 'package:tahfeex/model/models.dart';
import 'package:tahfeex/resources/resources.dart';
import 'package:tahfeex/screens/journey_list_screen.dart';
import 'package:tahfeex/screens/quran_journey_screen.dart';
import 'package:tahfeex/service/alarm_service.dart';
import 'package:tahfeex/service/app_storage.dart';
import 'package:tahfeex/service/states/states.dart';
import 'package:tahfeex/widgets/animated_progress_bar.dart';
import 'package:tahfeex/widgets/app_route.dart';


class JourneyDetailScreen extends StatelessWidget {
  final String journeyId;
  const JourneyDetailScreen({super.key, required this.journeyId});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<JourneyDetailCubit>(
      create: (_) => JourneyDetailCubit(journeyId),
      child: const _JourneyDetailView(),
    );
  }
}

class _JourneyDetailView extends StatelessWidget {
  const _JourneyDetailView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JourneyDetailCubit, JourneyDetailState>(
      builder: (context, state) {
        final cubit = context.read<JourneyDetailCubit>();

        if (state.isLoading && state.journey == null) {
          return const Scaffold(
            body: Center(
              child: CircularProgressIndicator(
                  color: AppColors.primaryColor),
            ),
          );
        }

        if (state.error != null && state.journey == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.error_outline,
                      size: 48, color: Colors.grey),
                  const SizedBox(height: 12),
                  Text(state.error!,
                      textAlign: TextAlign.center,
                      style: const TextStyle(color: Colors.grey)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                      onPressed: cubit.load,
                      child: const Text('Retry')),
                ],
              ),
            ),
          );
        }

        final j = state.journey!;
        final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
        final isCreator = j.isCreatorOf(myUid);
        final isMember = j.isMemberOf(myUid);
        final myMember = j.memberFor(myUid);

        return Scaffold(
          appBar: AppBar(
            title: Text(j.title, overflow: TextOverflow.ellipsis),
            actions: [
              if (state.isLoading)
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
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Header card ─────────────────────────────────────────
                  _HeaderCard(journey: j),
                  const SizedBox(height: 20),

                  // ── Join button (non-member, open journey) ───────────────
                  if (!isMember && j.allowJoining) ...[
                    _JoinButton(cubit: cubit),
                    const SizedBox(height: 20),
                  ],

                  // ── My progress ─────────────────────────────────────────
                  _sectionLabel(context, 'My progress'),
                  _ProgressCard(journey: j, myMember: myMember),
                  const SizedBox(height: 20),

                  // ── Members section (group journeys) ─────────────────────
                  if (j.members.length > 1 || j.allowJoining) ...[
                    _sectionLabel(context, 'Companions'),
                    _MembersSection(
                      journey: j,
                      myUid: myUid,
                      isCreator: isCreator,
                      isMember: isMember,
                      cubit: cubit,
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Allow joining toggle (creator only) ───────────────────
                  if (isCreator) ...[
                    _sectionLabel(context, 'Group settings'),
                    _AllowJoiningTile(journey: j, cubit: cubit),
                    const SizedBox(height: 20),
                  ],

                  // ── Range ───────────────────────────────────────────────
                  _sectionLabel(context, 'Verse range'),
                  _InfoCard(
                    children: [
                      _InfoRow(
                        icon: Icons.my_location,
                        label: 'Start',
                        value:
                            'Surah ${j.startSurah} (${getSurahName(j.startSurah)}), Ayah ${j.startAyah}',
                      ),
                      const Divider(height: 16),
                      _InfoRow(
                        icon: Icons.flag_outlined,
                        label: 'End',
                        value:
                            'Surah ${j.endSurah} (${getSurahName(j.endSurah)}), Ayah ${j.endAyah}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Timeline ────────────────────────────────────────────
                  _sectionLabel(context, 'Timeline'),
                  _InfoCard(
                    children: [
                      _InfoRow(
                          icon: Icons.play_circle_outline,
                          label: 'Start date',
                          value: journeyFmtDate(j.startDate)),
                      const Divider(height: 16),
                      _InfoRow(
                          icon: Icons.flag,
                          label: 'Target end date',
                          value: journeyFmtDate(j.endDate)),
                      const Divider(height: 16),
                      _InfoRow(
                          icon: Icons.access_time,
                          label: 'Created',
                          value: journeyFmtDate(j.createdAt)),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // ── Study alarms (members only) ───────────────────────────
                  if (isMember) ...[
                    _sectionLabel(context, 'Study alarms'),
                    _AlarmsSection(
                      journeyId: j.id,
                      journeyTitle: j.title,
                    ),
                    const SizedBox(height: 20),
                  ],

                  // ── Completed ayahs (my progress) ────────────────────────
                  if (myMember != null) ...[
                    _sectionLabel(context, 'Completed ayahs'),
                    _CompletedAyahsSection(journey: j, myMember: myMember),
                    const SizedBox(height: 28),
                  ],

                  // ── Member actions (pause/resume/abandon/leave) ───────────
                  if (myMember != null && myMember.isActionable)
                    _MemberActions(journey: j, myMember: myMember, isCreator: isCreator, cubit: cubit),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _sectionLabel(BuildContext context, String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Text(
          text.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.grey[500],
            letterSpacing: 0.8,
          ),
        ),
      );
}

// ─────────────────────────────────────────────────────────────────────────────
// Header card
// ─────────────────────────────────────────────────────────────────────────────

class _HeaderCard extends StatelessWidget {
  final Journey journey;
  const _HeaderCard({required this.journey});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: AppColors.primaryColor.withOpacity(0.06),
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    journey.title,
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                const SizedBox(width: 8),
                if (journey.memberCount > 1 || journey.allowJoining) ...[
                  _GroupChip(count: journey.memberCount),
                  const SizedBox(width: 6),
                ],
                JourneyStatusBadge(status: journey.status),
              ],
            ),
            if (journey.isDelayed) ...[
              const SizedBox(height: 6),
              Row(
                children: [
                  const Icon(Icons.warning_amber_rounded,
                      color: Colors.orange, size: 16),
                  const SizedBox(width: 4),
                  Text(
                    '${journey.daysOverdue} day${journey.daysOverdue == 1 ? '' : 's'} past deadline',
                    style: const TextStyle(
                        color: Colors.orange, fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: journey.dimensions
                  .map((d) => _DimChip(d))
                  .toList(),
            ),
          ],
        ),
      ),
    );
  }
}

class _GroupChip extends StatelessWidget {
  final int count;
  const _GroupChip({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline, size: 13, color: Colors.blue[700]),
          const SizedBox(width: 3),
          Text('$count',
              style: TextStyle(
                  fontSize: 11,
                  color: Colors.blue[700],
                  fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}

class _DimChip extends StatelessWidget {
  final String dim;
  const _DimChip(this.dim);

  @override
  Widget build(BuildContext context) {
    final label = switch (dim) {
      'read'        => 'Read',
      'memorize'    => 'Memorize',
      'translate'   => 'Translate',
      'commentary'  => 'Commentary',
      _             => dim,
    };
    return Chip(
      label: Text(label,
          style: TextStyle(
              fontSize: 12,
              color: AppColors.primaryColor,
              fontWeight: FontWeight.w600)),
      backgroundColor: AppColors.primaryColor.withOpacity(0.1),
      side: BorderSide(color: AppColors.primaryColor.withOpacity(0.3)),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
      padding: const EdgeInsets.symmetric(horizontal: 4),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Join button
// ─────────────────────────────────────────────────────────────────────────────

class _JoinButton extends StatefulWidget {
  final JourneyDetailCubit cubit;
  const _JoinButton({required this.cubit});

  @override
  State<_JoinButton> createState() => _JoinButtonState();
}

class _JoinButtonState extends State<_JoinButton> {
  bool _joining = false;

  Future<void> _join() async {
    setState(() => _joining = true);
    try {
      await widget.cubit.join();
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    } finally {
      if (mounted) setState(() => _joining = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryColor,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
        onPressed: _joining ? null : _join,
        icon: _joining
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white))
            : const Icon(Icons.group_add_outlined),
        label: const Text('Join Journey',
            style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Progress card
// ─────────────────────────────────────────────────────────────────────────────

class _ProgressCard extends StatelessWidget {
  final Journey journey;
  final JourneyMember? myMember;
  const _ProgressCard({required this.journey, required this.myMember});

  @override
  Widget build(BuildContext context) {
    if (myMember == null) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey[200]!)),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: Text(
              'Join this journey to track your progress.',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ),
        ),
      );
    }

    final fraction = journey.progressFractionFor(myMember!);
    final percent = journey.progressPercentFor(myMember!);
    final color = myMember!.isCompleted
        ? Colors.teal
        : myMember!.isDelayed
            ? Colors.orange
            : AppColors.primaryColor;

    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Row(
          children: [
            SizedBox(
              width: 72,
              height: 72,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CircularProgressIndicator(
                    value: fraction,
                    strokeWidth: 7,
                    backgroundColor: Colors.grey[200],
                    color: color,
                  ),
                  Text(
                    '$percent%',
                    style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.bold,
                        color: color),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${myMember!.completedCount} of ${journey.totalAyahs} ayahs',
                    style: Theme.of(context)
                        .textTheme
                        .titleMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$percent% complete',
                    style: TextStyle(
                        color: Colors.grey[600], fontSize: 13),
                  ),
                  const SizedBox(height: 10),
                  AnimatedProgressBar(
                    value: fraction,
                    minHeight: 6,
                    color: color,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Members section
// ─────────────────────────────────────────────────────────────────────────────

class _MembersSection extends StatelessWidget {
  final Journey journey;
  final String myUid;
  final bool isCreator;
  final bool isMember;
  final JourneyDetailCubit cubit;

  const _MembersSection({
    required this.journey,
    required this.myUid,
    required this.isCreator,
    required this.isMember,
    required this.cubit,
  });

  @override
  Widget build(BuildContext context) {
    // Show other members only
    final others = journey.members.where((m) => m.userId != myUid).toList();

    if (others.isEmpty) {
      return Card(
        elevation: 0,
        shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
            side: BorderSide(color: Colors.grey[200]!)),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Center(
            child: Text(
              journey.allowJoining
                  ? 'No companions yet. Share this journey with a companion.'
                  : 'Solo journey.',
              style: TextStyle(color: Colors.grey[500], fontSize: 13),
            ),
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey[200]!)),
      child: Column(
        children: others.asMap().entries.map((entry) {
          final i = entry.key;
          final member = entry.value;
          final fraction = journey.progressFractionFor(member);
          final percent = (fraction * 100).toInt();

          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 18,
                      backgroundColor:
                          AppColors.primaryColor.withValues(alpha: 0.15),
                      child: Text(
                        (member.name.isNotEmpty ? member.name : member.username)
                            .substring(0, 1)
                            .toUpperCase(),
                        style: const TextStyle(
                            color: AppColors.primaryColor,
                            fontWeight: FontWeight.bold,
                            fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Flexible(
                                child: Text(
                                  member.name.isNotEmpty
                                      ? member.name
                                      : '@${member.username}',
                                  style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              if (member.username.isNotEmpty) ...[
                                const SizedBox(width: 4),
                                Text(
                                  '@${member.username}',
                                  style: TextStyle(
                                      fontSize: 11, color: Colors.grey[500]),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                              const SizedBox(width: 6),
                              JourneyStatusBadge(status: member.status),
                              if (isCreator && member.userId == journey.creatorId)
                                Padding(
                                  padding: const EdgeInsets.only(left: 4),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                        horizontal: 5, vertical: 2),
                                    decoration: BoxDecoration(
                                      color: Colors.amber[50],
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text('Creator',
                                        style: TextStyle(
                                            fontSize: 10,
                                            color: Colors.amber[800])),
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          AnimatedProgressBar(
                            value: fraction,
                            minHeight: 5,
                            borderRadius: BorderRadius.circular(3),
                            color: fraction >= 1.0
                                ? Colors.teal
                                : AppColors.primaryColor,
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${member.completedCount} of ${journey.totalAyahs} ayahs',
                            style: TextStyle(
                                fontSize: 11, color: Colors.grey[500]),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                    // Nudge button (only for members)
                    if (isMember)
                      IconButton(
                        icon: const Icon(Icons.notifications_outlined, size: 20),
                        color: AppColors.primaryColor,
                        tooltip: 'Send a gentle reminder',
                        onPressed: () => _nudge(context, member.userId),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    // Remove button (only for creator)
                    if (isCreator) ...[
                      const SizedBox(width: 8),
                      IconButton(
                        icon: Icon(Icons.person_remove_outlined,
                            size: 20, color: Colors.red[300]),
                        tooltip: 'Remove member',
                        onPressed: () =>
                            _confirmRemove(context, member.userId),
                        padding: EdgeInsets.zero,
                        constraints: const BoxConstraints(),
                      ),
                    ],
                  ],
                ),
              ),
              if (i < others.length - 1)
                Divider(
                    height: 1, indent: 14, endIndent: 14,
                    color: Colors.grey[200]),
            ],
          );
        }).toList(),
      ),
    );
  }

  Future<void> _nudge(BuildContext context, String memberId) async {
    try {
      await cubit.nudge(memberId);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('A gentle reminder sent.')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _confirmRemove(BuildContext context, String memberId) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove member?'),
        content: const Text(
            'Their progress will be permanently deleted.'),
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
    if (confirmed == true) {
      try {
        await cubit.removeMember(memberId);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Allow joining toggle (creator only)
// ─────────────────────────────────────────────────────────────────────────────

class _AllowJoiningTile extends StatelessWidget {
  final Journey journey;
  final JourneyDetailCubit cubit;
  const _AllowJoiningTile({required this.journey, required this.cubit});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey[200]!)),
      child: SwitchListTile(
        title: const Text('Open to companions',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
        subtitle: Text(
          journey.allowJoining
              ? 'Your companions can join this journey.'
              : 'Only current members can participate.',
          style: TextStyle(fontSize: 12, color: Colors.grey[600]),
        ),
        value: journey.allowJoining,
        activeColor: AppColors.primaryColor,
        onChanged: (value) async {
          try {
            await cubit.toggleAllowJoining(allowJoining: value);
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context)
                  .showSnackBar(SnackBar(content: Text(e.toString())));
            }
          }
        },
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Completed ayahs section
// ─────────────────────────────────────────────────────────────────────────────

class _CompletedAyahsSection extends StatelessWidget {
  final Journey journey;
  final JourneyMember myMember;
  const _CompletedAyahsSection({required this.journey, required this.myMember});

  @override
  Widget build(BuildContext context) {
    // Large ranges: per-surah summary rows
    if (journey.totalAyahs > 500) {
      return _SurahSummaryList(journey: journey, myMember: myMember);
    }
    // Small ranges: dot grid per surah
    return _AyahDotGrid(journey: journey, myMember: myMember);
  }
}

class _SurahSummaryList extends StatelessWidget {
  final Journey journey;
  final JourneyMember myMember;
  const _SurahSummaryList({required this.journey, required this.myMember});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey[200]!)),
      child: Column(
        children: List.generate(
          journey.endSurah - journey.startSurah + 1,
          (i) {
            final surah = journey.startSurah + i;
            final total = journey.ayahsInSurahRange(surah);
            final done  = journey.doneInSurah(myMember, surah);
            final frac  = total > 0 ? done / total : 0.0;
            return _SurahSummaryRow(
              surah: surah,
              done: done,
              total: total,
              fraction: frac,
              isLast: i == journey.endSurah - journey.startSurah,
            );
          },
        ),
      ),
    );
  }
}

class _SurahSummaryRow extends StatelessWidget {
  final int surah, done, total;
  final double fraction;
  final bool isLast;

  const _SurahSummaryRow({
    required this.surah,
    required this.done,
    required this.total,
    required this.fraction,
    required this.isLast,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$surah · ${getSurahName(surah)}',
                      style: const TextStyle(
                          fontWeight: FontWeight.w600, fontSize: 13),
                    ),
                    const SizedBox(height: 4),
                    AnimatedProgressBar(
                      value: fraction,
                      minHeight: 5,
                      borderRadius: BorderRadius.circular(3),
                      color: fraction >= 1.0
                          ? Colors.teal
                          : AppColors.primaryColor,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Text(
                '$done/$total',
                style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
        if (!isLast)
          Divider(height: 1, indent: 14, endIndent: 14,
              color: Colors.grey[200]),
      ],
    );
  }
}

class _AyahDotGrid extends StatelessWidget {
  final Journey journey;
  final JourneyMember myMember;
  const _AyahDotGrid({required this.journey, required this.myMember});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey[200]!)),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: List.generate(
            journey.endSurah - journey.startSurah + 1,
            (i) {
              final surah = journey.startSurah + i;
              final minA = surah == journey.startSurah
                  ? journey.startAyah
                  : 1;
              final maxA = surah == journey.endSurah
                  ? journey.endAyah
                  : ayahCounts[surah];
              return _SurahDotRow(
                  myMember: myMember,
                  surah: surah,
                  minAyah: minA,
                  maxAyah: maxA);
            },
          ),
        ),
      ),
    );
  }
}

class _SurahDotRow extends StatelessWidget {
  final JourneyMember myMember;
  final int surah, minAyah, maxAyah;

  const _SurahDotRow({
    required this.myMember,
    required this.surah,
    required this.minAyah,
    required this.maxAyah,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$surah · ${getSurahName(surah)}',
            style: const TextStyle(
                fontSize: 12, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: List.generate(maxAyah - minAyah + 1, (i) {
              final ayah = minAyah + i;
              final done = myMember.isAyahDone(surah, ayah);
              return Tooltip(
                message: 'Ayah $ayah',
                child: Container(
                  width: 20,
                  height: 20,
                  decoration: BoxDecoration(
                    color: done
                        ? AppColors.primaryColor
                        : Colors.grey[200],
                    shape: BoxShape.circle,
                  ),
                  child: done
                      ? null
                      : Center(
                          child: Text(
                            '$ayah',
                            style: TextStyle(
                                fontSize: 8, color: Colors.grey[500]),
                          ),
                        ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Member actions (pause / resume / abandon / leave)
// ─────────────────────────────────────────────────────────────────────────────

class _MemberActions extends StatelessWidget {
  final Journey journey;
  final JourneyMember myMember;
  final bool isCreator;
  final JourneyDetailCubit cubit;

  const _MemberActions({
    required this.journey,
    required this.myMember,
    required this.isCreator,
    required this.cubit,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Continue journey
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primaryColor,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 14),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => _openJourneyScreen(context),
          icon: const Icon(Icons.play_arrow_rounded),
          label: const Text('Continue Journey',
              style: TextStyle(
                  fontSize: 15, fontWeight: FontWeight.bold)),
        ),
        const SizedBox(height: 10),

        // Pause / Resume
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            foregroundColor: Colors.grey[700],
            side: BorderSide(color: Colors.grey[400]!),
            padding: const EdgeInsets.symmetric(vertical: 12),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10)),
          ),
          onPressed: () => _togglePause(context),
          icon: Icon(myMember.isPaused
              ? Icons.play_circle_outline
              : Icons.pause_circle_outline),
          label: Text(myMember.isPaused ? 'Resume Journey' : 'Pause Journey'),
        ),
        const SizedBox(height: 10),

        // Abandon
        TextButton(
          style: TextButton.styleFrom(
            foregroundColor: Colors.red[400],
          ),
          onPressed: () => _confirmAbandon(context),
          child: const Text('Abandon Journey'),
        ),

        // Leave (for non-creators who are members)
        if (!isCreator) ...[
          const SizedBox(height: 4),
          TextButton(
            style: TextButton.styleFrom(
              foregroundColor: Colors.grey[600],
            ),
            onPressed: () => _confirmLeave(context),
            child: const Text('Leave Journey'),
          ),
        ],
      ],
    );
  }

  Future<void> _openJourneyScreen(BuildContext context) async {
    await Navigator.push(
      context,
      AppRoute(
          builder: (_) => QuranJourneyScreen(journeyId: journey.id)),
    );
    cubit.load(); // refresh detail after returning
  }

  Future<void> _togglePause(BuildContext context) async {
    try {
      if (myMember.isPaused) {
        await cubit.resume();
      } else {
        await cubit.pause();
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(e.toString())));
      }
    }
  }

  Future<void> _confirmAbandon(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Abandon this journey?'),
        content: const Text(
            'This cannot be undone. You will no longer be able to update progress.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              style:
                  TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Abandon')),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await cubit.abandon();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }
  }

  Future<void> _confirmLeave(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Leave this journey?'),
        content: const Text(
            'Your progress will be permanently deleted.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
              style:
                  TextButton.styleFrom(foregroundColor: Colors.red),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Leave')),
        ],
      ),
    );
    if (confirmed == true) {
      try {
        await cubit.leave();
        if (context.mounted) Navigator.pop(context);
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context)
              .showSnackBar(SnackBar(content: Text(e.toString())));
        }
      }
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Small shared helpers
// ─────────────────────────────────────────────────────────────────────────────

class _InfoCard extends StatelessWidget {
  final List<Widget> children;
  const _InfoCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: Colors.grey[200]!)),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: children),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label, value;
  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: Colors.grey[500]),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label,
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.grey[500],
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 2),
            Text(value,
                style: const TextStyle(
                    fontSize: 13, fontWeight: FontWeight.w500)),
          ],
        ),
      ],
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Study alarms section
// ─────────────────────────────────────────────────────────────────────────────

class _AlarmsSection extends StatefulWidget {
  final String journeyId;
  final String journeyTitle;

  const _AlarmsSection({
    required this.journeyId,
    required this.journeyTitle,
  });

  @override
  State<_AlarmsSection> createState() => _AlarmsSectionState();
}

class _AlarmsSectionState extends State<_AlarmsSection> {
  final _storage = AppStorage();
  List<JourneyAlarm> _alarms = [];

  @override
  void initState() {
    super.initState();
    _alarms = JourneyAlarm.fromJsonArray(_storage.getAlarms(widget.journeyId));
  }

  void _persist() {
    _storage.setAlarms(
        widget.journeyId, JourneyAlarm.toJsonArray(_alarms));
  }

  Future<void> _addAlarm() async {
    // Step 1: pick time
    final time = await showTimePicker(
      context: context,
      initialTime: const TimeOfDay(hour: 8, minute: 0),
      helpText: 'Study alarm time',
    );
    if (time == null || !mounted) return;

    // Step 2: pick days
    final days = await _showDayPicker(initial: [1, 2, 3, 4, 5]);
    if (!mounted) return;

    // Step 3: request permissions
    final granted = await AlarmService.requestPermissions();
    if (!mounted) return;
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        duration: Duration(seconds: 5),
        content: Text(
          'Please grant "Alarms & reminders" access in the settings page that just opened, then add the alarm again.',
        ),
      ));
      return;
    }

    final alarm = JourneyAlarm(
      id: 'alarm_${DateTime.now().millisecondsSinceEpoch}',
      journeyId: widget.journeyId,
      journeyTitle: widget.journeyTitle,
      hour: time.hour,
      minute: time.minute,
      days: days,
    );

    await AlarmService.schedule(alarm);
    setState(() => _alarms.add(alarm));
    _persist();
  }

  Future<List<int>> _showDayPicker({required List<int> initial}) async {
    final result = await showDialog<List<int>>(
      context: context,
      builder: (_) => _DayPickerDialog(initialDays: initial),
    );
    return result ?? initial;
  }

  Future<void> _toggle(int index) async {
    final updated =
        _alarms[index].copyWith(enabled: !_alarms[index].enabled);
    if (updated.enabled) {
      await AlarmService.schedule(updated);
    } else {
      await AlarmService.cancel(updated);
    }
    setState(() => _alarms[index] = updated);
    _persist();
  }

  Future<void> _delete(int index) async {
    await AlarmService.cancel(_alarms[index]);
    setState(() => _alarms.removeAt(index));
    _persist();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ..._alarms.asMap().entries.map((e) => Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _AlarmTile(
                    alarm: e.value,
                    onToggle: () => _toggle(e.key),
                    onDelete: () => _delete(e.key),
                  ),
                  if (e.key < _alarms.length - 1)
                    Divider(
                        height: 1,
                        indent: 16,
                        endIndent: 16,
                        color: Colors.grey[200]),
                ],
              )),
          if (_alarms.isNotEmpty)
            Divider(height: 1, color: Colors.grey[200]),
          TextButton.icon(
            onPressed: _addAlarm,
            icon: const Icon(Icons.add_alarm_outlined, size: 18),
            label: const Text('Add alarm'),
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primaryColor,
              padding:
                  const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            ),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Single alarm tile
// ─────────────────────────────────────────────────────────────────────────────

class _AlarmTile extends StatelessWidget {
  final JourneyAlarm alarm;
  final VoidCallback onToggle;
  final VoidCallback onDelete;

  const _AlarmTile({
    required this.alarm,
    required this.onToggle,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final dimmed = !alarm.enabled;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  alarm.timeLabel,
                  style: TextStyle(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: dimmed ? Colors.grey[400] : Colors.black87,
                    height: 1.1,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  alarm.daysLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: dimmed ? Colors.grey[400] : Colors.grey[600],
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline,
                size: 20, color: Colors.grey[400]),
            onPressed: onDelete,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
          ),
          const SizedBox(width: 10),
          Switch(
            value: alarm.enabled,
            onChanged: (_) => onToggle(),
            activeColor: AppColors.primaryColor,
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Day-of-week picker dialog
// ─────────────────────────────────────────────────────────────────────────────

class _DayPickerDialog extends StatefulWidget {
  final List<int> initialDays;
  const _DayPickerDialog({required this.initialDays});

  @override
  State<_DayPickerDialog> createState() => _DayPickerDialogState();
}

class _DayPickerDialogState extends State<_DayPickerDialog> {
  late Set<int> _selected;

  static const _labels = {
    1: 'Mon', 2: 'Tue', 3: 'Wed',
    4: 'Thu', 5: 'Fri', 6: 'Sat', 7: 'Sun',
  };

  @override
  void initState() {
    super.initState();
    _selected = widget.initialDays.toSet();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Repeat on'),
      content: Wrap(
        spacing: 8,
        runSpacing: 8,
        children: _labels.entries.map((e) {
          final on = _selected.contains(e.key);
          return FilterChip(
            label: Text(e.value),
            selected: on,
            onSelected: (v) => setState(
                () => v ? _selected.add(e.key) : _selected.remove(e.key)),
            selectedColor: AppColors.primaryColor.withOpacity(0.15),
            checkmarkColor: AppColors.primaryColor,
            labelStyle: TextStyle(
              color: on ? AppColors.primaryColor : Colors.grey[700],
              fontWeight: on ? FontWeight.w700 : FontWeight.normal,
            ),
          );
        }).toList(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () =>
              Navigator.pop(context, _selected.toList()),
          child: const Text('Save'),
        ),
      ],
    );
  }
}
