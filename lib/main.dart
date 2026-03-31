import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:path_provider/path_provider.dart';
import 'package:tahfeex/firebase_options.dart';
import 'package:tahfeex/resources/resources.dart';
import 'package:tahfeex/screens/screens.dart';
import 'package:tahfeex/service/alarm_service.dart';
import 'package:tahfeex/service/repositories/user_repository.dart';
import 'package:tahfeex/service/services.dart';
import 'package:tahfeex/service/states/app_settings_state.dart';
import 'package:tahfeex/service/states/states.dart';
import 'package:tahfeex/shared/connections/connections.dart';
import 'package:tahfeex/shared/constants/constants.dart';

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
        color: AppColors.primaryColor,
        navigatorKey: _navigatorKey,
        routes: const {},
        theme: ThemeData(
          colorScheme: ColorScheme.fromSeed(seedColor: AppColors.primaryColor),
          appBarTheme: const AppBarTheme(
            backgroundColor: AppColors.primaryColor,
            foregroundColor: Colors.white,
            iconTheme: IconThemeData(color: Colors.white),
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
      backgroundColor: Colors.white,
      body: Center(
        child: CircularProgressIndicator(color: AppColors.primaryColor),
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
  int _selectedIndex = 0;

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
      MaterialPageRoute(
          builder: (_) => JourneyDetailScreen(journeyId: journeyId)),
    );
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return MultiBlocProvider(
      providers: [
        BlocProvider<JourneyListCubit>(create: (_) => JourneyListCubit()),
        BlocProvider<ProfileCubit>(create: (_) => ProfileCubit()),
        BlocProvider<CompanionsCubit>(create: (_) => CompanionsCubit()),
      ],
      child: BlocBuilder<CompanionsCubit, CompanionsState>(
        builder: (context, companionsState) {
          return Scaffold(
            body: IndexedStack(
              index: _selectedIndex,
              children: const [
                _HomeTab(),
                CompanionsScreen(),
                MyProfileScreen(),
              ],
            ),
            bottomNavigationBar: BottomNavigationBar(
              currentIndex: _selectedIndex,
              onTap: (i) => setState(() => _selectedIndex = i),
              selectedItemColor: AppColors.primaryColor,
              unselectedItemColor: Colors.grey,
              items: [
                const BottomNavigationBarItem(
                  icon: Icon(Icons.home_outlined),
                  activeIcon: Icon(Icons.home),
                  label: 'Home',
                ),
                BottomNavigationBarItem(
                  icon: _badge(
                    Icons.people_outlined,
                    companionsState.incomingCount,
                  ),
                  activeIcon: _badge(
                    Icons.people,
                    companionsState.incomingCount,
                  ),
                  label: 'Companions',
                ),
                const BottomNavigationBarItem(
                  icon: Icon(Icons.person_outline),
                  activeIcon: Icon(Icons.person),
                  label: 'Profile',
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _badge(IconData icon, int count) {
    if (count == 0) return Icon(icon);
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Icon(icon),
        Positioned(
          top: -4,
          right: -4,
          child: Container(
            padding: const EdgeInsets.all(2),
            decoration:
                const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
            constraints: const BoxConstraints(minWidth: 14, minHeight: 14),
            child: Text(
              '$count',
              style: const TextStyle(
                  color: Colors.white,
                  fontSize: 8,
                  fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            ),
          ),
        ),
      ],
    );
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Home tab (study tools + journeys)
// ──────────────────────────────────────────────────────────────────────────────

class _HomeTab extends StatelessWidget {
  const _HomeTab();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final myUid = user?.uid ?? '';
    final displayName = user?.displayName?.trim();
    final firstName = displayName != null && displayName.isNotEmpty
        ? displayName.split(' ').first
        : null;
    final photoUrl = user?.photoURL;

    return BlocBuilder<JourneyListCubit, JourneyListState>(
      builder: (context, state) {
        final cubit = context.read<JourneyListCubit>();
        return Scaffold(
          appBar: AppBar(
            titleSpacing: 16,
            title: Row(
              children: [
                CircleAvatar(
                  radius: 17,
                  backgroundColor:
                      AppColors.primaryColor.withValues(alpha: 0.15),
                  backgroundImage:
                      photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null
                      ? Text(
                          (firstName ?? user?.email ?? 'U')
                              .substring(0, 1)
                              .toUpperCase(),
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primaryColor,
                          ),
                        )
                      : null,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: BlocBuilder<ProfileCubit, ProfileState>(
                    builder: (context, profileState) {
                      final username = profileState.user?.username;
                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'Assalamu Alaikum',
                            style:
                                TextStyle(fontSize: 11, color: Colors.white70),
                          ),
                          Text(
                            firstName ?? user?.email ?? 'Welcome',
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (username != null)
                            Text(
                              '@$username',
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white70,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
            actions: [
              if (state.isLoading && state.journeys != null)
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
            ],
          ),
          floatingActionButton: _buildFab(context, state, cubit),
          body: RefreshIndicator(
            color: AppColors.primaryColor,
            onRefresh: cubit.load,
            child: SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 100),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ── Study tools ─────────────────────────────────────────
                  Text(
                    'STUDY TOOLS',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: Colors.grey[500],
                      letterSpacing: 0.8,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: _StudyTile(
                          icon: Icons.menu_book_rounded,
                          label: 'Quran\nReading',
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const QuranReader())),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StudyTile(
                          icon: Icons.psychology_outlined,
                          label: 'Memorize',
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const MemorizationScreen())),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: _StudyTile(
                          icon: Icons.translate,
                          label: 'Tafseer',
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => const TafseerScreen())),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),

                  // ── Journeys ────────────────────────────────────────────
                  Row(
                    children: [
                      const Icon(Icons.route_outlined,
                          color: AppColors.primaryColor, size: 18),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          'MY JOURNEYS',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            color: Colors.grey[500],
                            letterSpacing: 0.8,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  _buildJourneys(context, state, cubit, myUid: myUid),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildJourneys(
      BuildContext context, JourneyListState state, JourneyListCubit cubit,
      {required String myUid}) {
    if (state.isLoading && state.journeys == null) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: CircularProgressIndicator(color: AppColors.primaryColor),
        ),
      );
    }

    if (state.error != null && state.journeys == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 32),
          child: Column(
            children: [
              const Icon(Icons.cloud_off, size: 40, color: Colors.grey),
              const SizedBox(height: 10),
              Text(state.error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.grey)),
              const SizedBox(height: 14),
              OutlinedButton(onPressed: cubit.load, child: const Text('Retry')),
            ],
          ),
        ),
      );
    }

    if (state.journeys?.isEmpty ?? false) {
      return JourneyEmptyState(onCreateTap: () => _openCreate(context, cubit));
    }

    return Column(
      children: [
        for (final journey in state.journeys!)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: JourneyCard(
              journey: journey,
              myUid: myUid,
              onTap: () => _openDetail(context, cubit, journey.id),
              onContinue: journey.memberFor(myUid)?.isActionable == true
                  ? () => _openJourney(context, cubit, journey.id)
                  : null,
            ),
          ),
      ],
    );
  }

  Widget _buildFab(
      BuildContext context, JourneyListState state, JourneyListCubit cubit) {
    final uid   = FirebaseAuth.instance.currentUser?.uid ?? '';
    final atCap = cubit.atCap(uid);
    final fab = FloatingActionButton.extended(
      backgroundColor: atCap ? Colors.grey[400] : AppColors.primaryColor,
      onPressed: atCap ? null : () => _openCreate(context, cubit),
      icon: const Icon(Icons.add, color: Colors.white),
      label: const Text('New Journey', style: TextStyle(color: Colors.white)),
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

  Future<void> _openCreate(BuildContext context, JourneyListCubit cubit) async {
    final created = await Navigator.push<bool>(
      context,
      MaterialPageRoute(builder: (_) => const CreateJourneyScreen()),
    );
    if (created == true) cubit.load();
  }

  Future<void> _openDetail(
      BuildContext context, JourneyListCubit cubit, String id) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => JourneyDetailScreen(journeyId: id)),
    );
    cubit.load();
  }

  Future<void> _openJourney(
      BuildContext context, JourneyListCubit cubit, String id) async {
    await Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => QuranJourneyScreen(journeyId: id)),
    );
    cubit.load();
  }
}

// ──────────────────────────────────────────────────────────────────────────────
// Study tool tile
// ──────────────────────────────────────────────────────────────────────────────

class _StudyTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _StudyTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: Colors.grey[200]!),
          boxShadow: [
            BoxShadow(
              color: Colors.grey.withValues(alpha: 0.08),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 32, color: AppColors.primaryColor),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }
}
