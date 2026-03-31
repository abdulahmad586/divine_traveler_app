import 'dart:math';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:path_provider/path_provider.dart';
import 'package:quran/quran.dart';
import 'package:tahfeex/firebase_options.dart';
import 'package:tahfeex/model/models.dart';
import 'package:tahfeex/resources/resources.dart';
import 'package:tahfeex/screens/screens.dart';
import 'package:tahfeex/service/alarm_service.dart';
import 'package:tahfeex/service/repositories/user_repository.dart';
import 'package:tahfeex/service/services.dart';
import 'package:tahfeex/service/states/app_settings_state.dart';
import 'package:tahfeex/service/states/states.dart';
import 'package:tahfeex/shared/connections/connections.dart';
import 'package:tahfeex/shared/constants/constants.dart';
import 'package:tahfeex/shared/progression/user_progression.dart';
import 'package:tahfeex/widgets/animated_progress_bar.dart';
import 'package:tahfeex/widgets/app_route.dart';

// Top-level navigator key used to route FCM notification taps from outside
// the widget tree.
final _navigatorKey = GlobalKey<NavigatorState>();

// Must be a top-level function — called when an FCM message arrives while the
// app is in the background or terminated.
@pragma('vm:entry-point')
Future<void> _onBackgroundMessage(RemoteMessage message) async {
  // No UI work needed here — the OS notification handles display.
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Set the background message handler before anything else.
  FirebaseMessaging.onBackgroundMessage(_onBackgroundMessage);

  // Hive + app storage.
  final appStoreBoxPath = (await getApplicationSupportDirectory()).path;
  await AppConfig.configure(appStoreBoxPath);
  await AlarmService.init();

  DioClient().setBaseUrl(ApiConstants.devBaseUrl);

  try {
    await AuthService().signInSilently();
  } catch (e) {
    debugPrint('[main] silent sign-in failed (non-fatal): $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<MainCubit>(create: (_) => MainCubit()),
        BlocProvider<SettingsCubit>(create: (_) => SettingsCubit()),
      ],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        color: AppColors.primary,
        navigatorKey: _navigatorKey,
        routes: const {},
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(
            seedColor: AppColors.primary,
            surface: AppColors.surface,
          ),
          scaffoldBackgroundColor: AppColors.surface,
          cardColor: AppColors.cardSurface,
          cardTheme: CardThemeData(
            color: AppColors.cardSurface,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppSizes.cardRadius),
              side: const BorderSide(color: AppColors.border),
            ),
          ),
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            iconTheme: IconThemeData(color: Colors.white),
            elevation: 0,
          ),
          textTheme: const TextTheme(
            bodyMedium: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: AppColors.textPrimary,
            ),
            bodySmall: TextStyle(
              fontSize: 12,
              color: AppColors.textSecondary,
            ),
            labelSmall: TextStyle(
              fontSize: 11,
              color: AppColors.textSecondary,
            ),
          ),
          dividerColor: AppColors.border,
          progressIndicatorTheme: const ProgressIndicatorThemeData(
            color: AppColors.primaryMuted,
            linearTrackColor: AppColors.border,
          ),
        ),
        home: StreamBuilder<User?>(
          stream: FirebaseAuth.instance.authStateChanges(),
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const _SplashScreen();
            }

            final user = snapshot.data;
            if (user != null) {
              DioClient().setTokenProvider(() => user.getIdToken());
              return const HomeScreen();
            }

            return const LoginScreen();
          },
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Splash screen
// ──────────────────────────────────────────────────────────────────────────────

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppColors.surface,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.primary),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Home screen — bottom nav shell
// ──────────────────────────────────────────────────────────────────────────────

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    _setupFcm();
    _handleInitialMessage();
  }

  // ── FCM setup ───────────────────────────────────────────────────────────

  Future<void> _setupFcm() async {
    // iOS: request permission before registering the token.
    await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    await _registerFcmToken();

    // Re-register whenever the token rotates.
    FirebaseMessaging.instance.onTokenRefresh
        .listen((_) => _registerFcmToken());

    // App in foreground and user taps the notification.
    FirebaseMessaging.onMessageOpenedApp.listen(_routeMessage);
  }

  Future<void> _registerFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await UserRepository().updateFcmToken(token);
      }
    } catch (e) {
      debugPrint('[FCM] token registration failed (non-fatal): $e');
    }
  }

  // App was terminated and opened via a notification tap.
  Future<void> _handleInitialMessage() async {
    final message = await FirebaseMessaging.instance.getInitialMessage();
    if (message != null) _routeMessage(message);
  }

  void _routeMessage(RemoteMessage message) {
    final journeyId = message.data['journeyId'] as String?;
    if (journeyId == null) return;
    _navigatorKey.currentState?.push(
      AppRoute(builder: (_) => JourneyDetailScreen(journeyId: journeyId)),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<JourneyListCubit>(create: (_) => JourneyListCubit()),
        BlocProvider<CompanionsCubit>(create: (_) => CompanionsCubit()),
      ],
      child: const _HomeView(),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Home view — no bottom nav, contextual navigation
// ──────────────────────────────────────────────────────────────────────────────

class _HomeView extends StatelessWidget {
  const _HomeView();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final myUid = user?.uid ?? '';

    return BlocBuilder<JourneyListCubit, JourneyListState>(
      builder: (context, state) {
        final cubit = context.read<JourneyListCubit>();
        return Scaffold(
          body: SafeArea(
            child: RefreshIndicator(
              color: AppColors.primary,
              onRefresh: cubit.load,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(
                  AppSizes.pagePadding,
                  28,
                  AppSizes.pagePadding,
                  40,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _HomeHeader(user: user),
                    const SizedBox(height: AppSizes.sectionGap),
                    const _DailyAyahCard(),
                    const SizedBox(height: AppSizes.sectionGap),
                    _buildContent(context, state, cubit, myUid),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildContent(BuildContext context, JourneyListState state,
      JourneyListCubit cubit, String myUid) {
    if (state.isLoading && state.journeys == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 60),
          child: CircularProgressIndicator(color: AppColors.primary),
        ),
      );
    }

    if (state.error != null && state.journeys == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [
              const Icon(Icons.cloud_off,
                  size: 40, color: AppColors.textSecondary),
              const SizedBox(height: 12),
              Text(state.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 16),
              OutlinedButton(onPressed: cubit.load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    final journeys = state.journeys ?? [];
    final active = journeys
        .where((j) => j.memberFor(myUid)?.isActionable == true)
        .toList();

    if (active.isEmpty) {
      return _HomeEmptyState(onStartTap: () => _openCreate(context, cubit));
    }

    final primary = active.first;
    final moreCount = active.length - 1;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Current journey card ───────────────────────────────────────────
        _CurrentJourneyCard(
          journey: primary,
          myUid: myUid,
          onTap: () => _openDetail(context, cubit, primary.id),
          onContinue: () => _openJourney(context, cubit, primary.id),
        ),

        if (moreCount > 0) ...[
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () => Navigator.push(
              context,
              AppRoute(builder: (_) => const JourneyListScreen()),
            ).then((_) => cubit.load()),
            child: Text(
              '$moreCount more journey${moreCount > 1 ? 's' : ''}',
              style: const TextStyle(
                fontSize: 13,
                color: AppColors.primaryMuted,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],

        const SizedBox(height: AppSizes.sectionGap),

        // ── Start a Journey ────────────────────────────────────────────────
        SizedBox(
          width: double.infinity,
          child: OutlinedButton(
            onPressed: () => _openCreate(context, cubit),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: const BorderSide(color: AppColors.primary),
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
              ),
            ),
            child: const Text('Start a Journey',
                style: TextStyle(fontWeight: FontWeight.w600)),
          ),
        ),

        const SizedBox(height: 12),

        // ── View Companions ────────────────────────────────────────────────
        if (UserProgression().hasShownConsistency)
          BlocBuilder<CompanionsCubit, CompanionsState>(
            builder: (context, companionsState) {
              return SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    AppRoute(builder: (_) => const CompanionsScreen()),
                  ),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.textSecondary,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Text('View Companions',
                          style: TextStyle(fontSize: 14)),
                      if (companionsState.incomingCount > 0) ...[
                        const SizedBox(width: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: const BoxDecoration(
                            color: Colors.red,
                            shape: BoxShape.circle,
                          ),
                          child: Text(
                            '${companionsState.incomingCount}',
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              );
            },
          ),

        // ── Study tools ────────────────────────────────────────────────────
        const SizedBox(height: AppSizes.sectionGap),
        const Divider(height: 1, color: AppColors.border),
        const SizedBox(height: AppSizes.sectionGap),
        const _StudyToolsRow(),
      ],
    );
  }

  Future<void> _openCreate(BuildContext context, JourneyListCubit cubit) async {
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

  Future<void> _openJourney(
      BuildContext context, JourneyListCubit cubit, String id) async {
    await Navigator.push(
      context,
      AppRoute(builder: (_) => QuranJourneyScreen(journeyId: id)),
    );
    cubit.load();
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Home header — greeting + tappable avatar
// ──────────────────────────────────────────────────────────────────────────────

class _HomeHeader extends StatelessWidget {
  final User? user;
  const _HomeHeader({required this.user});

  @override
  Widget build(BuildContext context) {
    final displayName = user?.displayName?.trim();
    final firstName = (displayName != null && displayName.isNotEmpty)
        ? displayName.split(' ').first
        : null;
    final photoUrl = user?.photoURL;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Assalamu Alaikum',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              if (firstName != null) ...[
                const SizedBox(height: 2),
                Text(
                  firstName,
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ],
          ),
        ),
        GestureDetector(
          onTap: () => Navigator.push(
            context,
            AppRoute(builder: (_) => const MyProfileScreen()),
          ),
          child: CircleAvatar(
            radius: 22,
            backgroundColor: AppColors.primary.withValues(alpha: 0.12),
            backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
            child: photoUrl == null
                ? Text(
                    (firstName ?? user?.email ?? 'U')
                        .substring(0, 1)
                        .toUpperCase(),
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: AppColors.primary,
                    ),
                  )
                : null,
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Current journey card — dominant, full-width
// ──────────────────────────────────────────────────────────────────────────────

class _CurrentJourneyCard extends StatelessWidget {
  final Journey journey;
  final String myUid;
  final VoidCallback onTap;
  final VoidCallback onContinue;

  const _CurrentJourneyCard({
    required this.journey,
    required this.myUid,
    required this.onTap,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final myMember = journey.memberFor(myUid);
    final completed = myMember?.completedCount ?? 0;
    final total = journey.totalAyahs;
    final fraction = total > 0 ? completed / total : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.cardSurface,
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          border:
              const Border.fromBorderSide(BorderSide(color: AppColors.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'CURRENT JOURNEY',
              style: TextStyle(
                fontSize: 10,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
                letterSpacing: 0.8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              journey.title,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 16),
            AnimatedProgressBar(
              value: fraction,
              minHeight: 6,
              backgroundColor: AppColors.border,
              color: AppColors.primaryMuted,
            ),
            const SizedBox(height: 8),
            Text(
              '$completed of $total ayahs',
              style:
                  const TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: AppSizes.buttonHeight,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppSizes.buttonRadius),
                  ),
                  elevation: 0,
                ),
                onPressed: onContinue,
                icon: const Icon(Icons.arrow_forward, size: 18),
                label: const Text('Continue',
                    style:
                        TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Study tools row — three standalone tools accessible from home
// ──────────────────────────────────────────────────────────────────────────────

class _StudyToolsRow extends StatelessWidget {
  const _StudyToolsRow();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        _ToolTile(
          icon: Icons.menu_book_outlined,
          label: 'Quran Reader',
          onTap: () => Navigator.push(
            context,
            AppRoute(builder: (_) => const QuranReader()),
          ),
        ),
        const SizedBox(width: 10),
        _ToolTile(
          icon: Icons.psychology_outlined,
          label: 'Memorization',
          onTap: () => Navigator.push(
            context,
            AppRoute(builder: (_) => const MemorizationScreen()),
          ),
        ),
        const SizedBox(width: 10),
        _ToolTile(
          icon: Icons.auto_stories_outlined,
          label: 'Tafsir',
          onTap: () => Navigator.push(
            context,
            AppRoute(builder: (_) => const TafseerScreen()),
          ),
        ),
      ],
    );
  }
}

class _ToolTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _ToolTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.cardSurface,
            borderRadius: BorderRadius.circular(AppSizes.cardRadius),
            border: const Border.fromBorderSide(
                BorderSide(color: AppColors.border)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 24, color: AppColors.primary),
              const SizedBox(height: 6),
              Text(
                label,
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w500,
                  color: AppColors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Empty state
// ──────────────────────────────────────────────────────────────────────────────

class _HomeEmptyState extends StatelessWidget {
  final VoidCallback onStartTap;
  const _HomeEmptyState({required this.onStartTap});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
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
              onPressed: onStartTap,
              child: const Text('Start a Journey',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
          ),
          const SizedBox(height: AppSizes.sectionGap),
          const Divider(height: 1, color: AppColors.border),
          const SizedBox(height: AppSizes.sectionGap),
          const _StudyToolsRow(),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Daily Ayah card — seed-based random ayah, same all day, animated entrance
// ──────────────────────────────────────────────────────────────────────────────

class _DailyAyahCard extends StatefulWidget {
  const _DailyAyahCard();

  @override
  State<_DailyAyahCard> createState() => _DailyAyahCardState();
}

class _DailyAyahCardState extends State<_DailyAyahCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _fade;
  late final Animation<Offset> _slide;
  late final Animation<double> _bar;

  late final int _surah;
  late final int _ayah;

  @override
  void initState() {
    super.initState();

    // Same ayah all day, changes at midnight
    final now = DateTime.now();
    final seed = now.year * 10000 + now.month * 100 + now.day;
    final rng = Random(seed);
    _surah = rng.nextInt(114) + 1;
    _ayah = rng.nextInt(getVerseCount(_surah)) + 1;

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    );

    final eased = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.75, curve: Curves.easeOutCubic),
    );
    _fade = eased;
    _slide = Tween<Offset>(
      begin: const Offset(0, 0.06),
      end: Offset.zero,
    ).animate(eased);
    _bar = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.15, 1.0, curve: Curves.easeOutCubic),
    );

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _readThisAyah(BuildContext context) {
    final page = getPageNumber(_surah, _ayah);
    context.read<MainCubit>().updateCurrentPage(page);
    context.read<MainCubit>().updateCurrentVerse(_ayah);
    Navigator.push(context, AppRoute(builder: (_) => const QuranReader()));
  }

  @override
  Widget build(BuildContext context) {
    final arabic = getVerse(_surah, _ayah);
    final translation =
        getVerseTranslation(_surah, _ayah, translation: Translation.enSaheeh);
    final surahName = getSurahName(_surah);

    return FadeTransition(
      opacity: _fade,
      child: SlideTransition(
        position: _slide,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(AppSizes.cardRadius),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.cardSurface,
              borderRadius: BorderRadius.circular(AppSizes.cardRadius),
              border: const Border.fromBorderSide(
                  BorderSide(color: AppColors.border)),
            ),
            child: Stack(
              children: [
                // Content — left padding reserves space for the bar
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 16, 14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // "AYAH OF THE DAY" label
                      Row(
                        children: [
                          Container(
                            width: 6,
                            height: 6,
                            decoration: const BoxDecoration(
                              color: AppColors.gold,
                              shape: BoxShape.circle,
                            ),
                          ),
                          const SizedBox(width: 7),
                          const Text(
                            'AYAH OF THE DAY',
                            style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textSecondary,
                              letterSpacing: 1.1,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 14),

                      // Arabic text
                      SizedBox(
                        width: double.infinity,
                        child: Text(
                          arabic,
                          textAlign: TextAlign.right,
                          style: GoogleFonts.lateef(
                            fontSize: 28,
                            color: AppColors.textPrimary,
                            height: 1.9,
                          ),
                        ),
                      ),

                      const SizedBox(height: 12),
                      const Divider(color: AppColors.border, height: 1),
                      const SizedBox(height: 12),

                      // Translation (italic, quoted)
                      Text(
                        '\u201c$translation\u201d',
                        style: const TextStyle(
                          fontSize: 13,
                          height: 1.65,
                          color: AppColors.textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                      ),

                      const SizedBox(height: 14),

                      // Reference + Read link
                      Row(
                        children: [
                          Text(
                            '$surahName · $_surah:$_ayah',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: AppColors.primaryMuted,
                            ),
                          ),
                          const Spacer(),
                          GestureDetector(
                            onTap: () => _readThisAyah(context),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'Read',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.primary,
                                  ),
                                ),
                                SizedBox(width: 3),
                                Icon(Icons.arrow_forward_rounded,
                                    size: 13, color: AppColors.primary),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
