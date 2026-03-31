import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:tahfeex/model/models.dart';
import 'package:tahfeex/resources/resources.dart';
import 'package:tahfeex/service/states/states.dart';
import 'package:tahfeex/shared/constants/constants.dart';
import 'package:tahfeex/screens/journey_template_screen.dart';
import 'package:tahfeex/screens/journey_detail_screen.dart';
import 'package:tahfeex/widgets/animated_progress_bar.dart';
import 'package:tahfeex/widgets/app_route.dart';

class JourneyListScreen extends StatelessWidget {
  const JourneyListScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider<JourneyListCubit>(
      create: (_) => JourneyListCubit(),
      child: const _JourneyListView(),
    );
  }
}

class _JourneyListView extends StatelessWidget {
  const _JourneyListView();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<JourneyListCubit, JourneyListState>(
      builder: (context, state) {
        final cubit = context.read<JourneyListCubit>();
        final myUid = FirebaseAuth.instance.currentUser?.uid ?? '';
        return Scaffold(
          appBar: AppBar(
            title: const Text('My Journeys'),
            actions: [
              if (state.isLoading && state.journeys != null)
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
          floatingActionButton: _buildFab(context, state, cubit, myUid),
          body: _buildBody(context, state, cubit, myUid),
        );
      },
    );
  }

  Widget _buildFab(BuildContext context, JourneyListState state,
      JourneyListCubit cubit, String myUid) {
    final atCap = cubit.atCap(myUid);
    final fab = FloatingActionButton.extended(
      backgroundColor:
          atCap ? Colors.grey[400] : AppColors.primaryColor,
      onPressed: atCap ? null : () => _openCreate(context, cubit),
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text('New Journey',
          style: TextStyle(color: Colors.white)),
    );
    if (atCap) {
      return Tooltip(
        message:
            'You are in 5 active journeys. Complete or abandon one to create a new one.',
        child: fab,
      );
    }
    return fab;
  }

  Widget _buildBody(BuildContext context, JourneyListState state,
      JourneyListCubit cubit, String myUid) {
    if (state.isLoading && state.journeys == null) {
      return const Center(
        child: CircularProgressIndicator(color: AppColors.primaryColor),
      );
    }
    if (state.error != null && state.journeys == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.cloud_off, size: 48, color: Colors.grey),
              const SizedBox(height: 12),
              Text(state.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: cubit.load,
                child: const Text('Retry'),
              ),
            ],
          ),
        ),
      );
    }
    if (state.journeys?.isEmpty ?? false) {
      return JourneyEmptyState(onCreateTap: () => _openCreate(context, cubit));
    }
    return RefreshIndicator(
      color: AppColors.primaryColor,
      onRefresh: cubit.load,
      child: ListView.separated(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
        itemCount: state.journeys!.length,
        separatorBuilder: (_, __) => const SizedBox(height: 12),
        itemBuilder: (_, i) => JourneyCard(
          journey: state.journeys![i],
          myUid: myUid,
          onTap: () => _openDetail(context, cubit, state.journeys![i].id),
        ),
      ),
    );
  }

  Future<void> _openCreate(
      BuildContext context, JourneyListCubit cubit) async {
    final journeys = cubit.state.journeys ?? [];
    final created = await Navigator.push<bool>(
      context,
      AppRoute(
        builder: (_) => JourneyTemplateScreen(existingJourneys: journeys),
      ),
    );
    if (created == true) cubit.load();
  }

  Future<void> _openDetail(
      BuildContext context, JourneyListCubit cubit, String id) async {
    await Navigator.push(
      context,
      AppRoute(builder: (_) => JourneyDetailScreen(journeyId: id)),
    );
    cubit.load();
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Empty state
// ─────────────────────────────────────────────────────────────────────────────

class JourneyEmptyState extends StatelessWidget {
  final VoidCallback onCreateTap;
  const JourneyEmptyState({required this.onCreateTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Begin with a short journey.\nConsistency matters more than speed.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 17,
                height: 1.65,
                color: AppColors.textPrimary,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              height: AppSizes.buttonHeight,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                  ),
                  elevation: 0,
                ),
                onPressed: onCreateTap,
                child: const Text('Start a Journey',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Journey card
// ─────────────────────────────────────────────────────────────────────────────

class JourneyCard extends StatelessWidget {
  final Journey journey;
  final String myUid;
  final VoidCallback onTap;
  /// When provided, shows a "Continue" button on the card for quick access
  /// to the journey screen without opening the detail page first.
  final VoidCallback? onContinue;

  const JourneyCard({
    required this.journey,
    required this.myUid,
    required this.onTap,
    this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final myMember = journey.memberFor(myUid);
    final completedCount = myMember?.completedCount ?? 0;
    final progressFraction = myMember != null
        ? journey.progressFractionFor(myMember)
        : 0.0;
    final progressPercent = (progressFraction * 100).toInt();
    final myStatus = myMember?.status ?? journey.status;
    final isGroupJourney = journey.memberCount > 1 || journey.allowJoining;

    return Card(
      elevation: 2,
      shape:
          RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title row + status badge + group badge
              Row(
                children: [
                  Expanded(
                    child: Text(
                      journey.title,
                      style: Theme.of(context)
                          .textTheme
                          .titleMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (isGroupJourney) ...[
                    _GroupBadge(count: journey.memberCount),
                    const SizedBox(width: 6),
                  ],
                  JourneyStatusBadge(status: myStatus),
                ],
              ),

              // Overdue warning (based on member's own delayed status)
              if (myMember?.isDelayed == true) ...[
                const SizedBox(height: 4),
                Text(
                  '${journey.daysOverdue} day${journey.daysOverdue == 1 ? '' : 's'} past deadline',
                  style: const TextStyle(
                      color: Colors.orange,
                      fontSize: 12,
                      fontWeight: FontWeight.w500),
                ),
              ],

              const SizedBox(height: 10),

              // Dimension chips
              Wrap(
                spacing: 6,
                runSpacing: 4,
                children: journey.dimensions
                    .map((d) => JourneyDimensionChip(dimension: d))
                    .toList(),
              ),

              const SizedBox(height: 12),

              // Progress bar (your progress)
              AnimatedProgressBar(
                value: progressFraction,
                minHeight: 6,
                color: _progressColor(myStatus),
              ),
              const SizedBox(height: 6),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    '$completedCount / ${journey.totalAyahs} ayahs',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[600]),
                  ),
                  Text(
                    '$progressPercent%',
                    style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _progressColor(myStatus)),
                  ),
                ],
              ),

              const SizedBox(height: 8),

              // Date range
              Row(
                children: [
                  Icon(Icons.calendar_today_outlined,
                      size: 12, color: Colors.grey[500]),
                  const SizedBox(width: 4),
                  Text(
                    '${_fmtDate(journey.startDate)} → ${_fmtDate(journey.endDate)}',
                    style: TextStyle(
                        fontSize: 12, color: Colors.grey[500]),
                  ),
                ],
              ),

              // Continue shortcut (only if member and actionable)
              if (onContinue != null && myMember?.isActionable == true) ...[
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primaryColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8)),
                    ),
                    onPressed: onContinue,
                    icon: const Icon(Icons.play_arrow_rounded, size: 18),
                    label: const Text('Continue',
                        style: TextStyle(
                            fontSize: 13, fontWeight: FontWeight.w600)),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Color _progressColor(String status) {
    return switch (status) {
      'completed' => Colors.teal,
      'delayed'   => Colors.orange,
      'abandoned' => Colors.red[300]!,
      _           => AppColors.primaryColor,
    };
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Group badge
// ─────────────────────────────────────────────────────────────────────────────

class _GroupBadge extends StatelessWidget {
  final int count;
  const _GroupBadge({required this.count});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.blue[50],
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.blue[200]!),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.people_outline, size: 12, color: Colors.blue[700]),
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

// ─────────────────────────────────────────────────────────────────────────────
// Shared widgets (exported so detail screen can reuse)
// ─────────────────────────────────────────────────────────────────────────────

class JourneyStatusBadge extends StatelessWidget {
  final String status;
  const JourneyStatusBadge({super.key, required this.status});

  @override
  Widget build(BuildContext context) {
    final (label, bg, fg) = switch (status) {
      'active'    => ('Active',    Colors.green[100]!,  Colors.green[800]!),
      'paused'    => ('Paused',    Colors.grey[200]!,   Colors.grey[700]!),
      'delayed'   => ('Delayed',   Colors.orange[100]!, Colors.orange[800]!),
      'completed' => ('Completed', Colors.teal[100]!,   Colors.teal[800]!),
      'abandoned' => ('Abandoned', Colors.red[100]!,    Colors.red[800]!),
      _           => (status,      Colors.grey[100]!,   Colors.grey[700]!),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg)),
    );
  }
}

class JourneyDimensionChip extends StatelessWidget {
  final String dimension;
  const JourneyDimensionChip({required this.dimension});

  @override
  Widget build(BuildContext context) {
    final label = switch (dimension) {
      'read'        => 'Read',
      'memorize'    => 'Memorize',
      'translate'   => 'Translate',
      'commentary'  => 'Commentary',
      _             => dimension,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.primaryColor.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: AppColors.primaryColor.withOpacity(0.3)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              color: AppColors.primaryColor,
              fontWeight: FontWeight.w600)),
    );
  }
}

// Exported so other files can use without re-importing
String _fmtDate(DateTime d) {
  const m = [
    'Jan','Feb','Mar','Apr','May','Jun',
    'Jul','Aug','Sep','Oct','Nov','Dec'
  ];
  return '${d.day} ${m[d.month - 1]} ${d.year}';
}

/// Accessible from other journey screens via the barrel export.
String journeyFmtDate(DateTime d) => _fmtDate(d);
