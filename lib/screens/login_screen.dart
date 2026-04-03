import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:tahfeex/resources/resources.dart';
import 'package:tahfeex/screens/legal_screen.dart';
import 'package:tahfeex/service/auth_service.dart';
import 'package:tahfeex/shared/constants/constants.dart';
import 'package:tahfeex/widgets/app_route.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen>
    with SingleTickerProviderStateMixin {
  // ── Animation ─────────────────────────────────────────────────────────────

  late final AnimationController _ctrl;

  // Decorative arcs drawn in
  late final Animation<double> _arcs;
  // Emblem scale-in with elastic overshoot
  late final Animation<double> _emblemScale;
  late final Animation<double> _emblemFade;
  // Title + gold bar slide up
  late final Animation<double> _titleFade;
  late final Animation<Offset> _titleSlide;
  // Tagline fade
  late final Animation<double> _tagFade;
  // Button + footer slide up from below
  late final Animation<double> _btnFade;
  late final Animation<Offset> _btnSlide;

  // ── State ──────────────────────────────────────────────────────────────────

  bool _loading = false;
  String? _error;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _arcs = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.0, 0.55, curve: Curves.easeInOut),
    );

    _emblemFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.25, 0.5, curve: Curves.easeOut),
    );
    _emblemScale = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.25, 0.65, curve: Curves.elasticOut),
    );

    final titleCurve = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.45, 0.72, curve: Curves.easeOutCubic),
    );
    _titleFade  = titleCurve;
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, 0.25),
      end: Offset.zero,
    ).animate(titleCurve);

    _tagFade = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.60, 0.85, curve: Curves.easeOut),
    );

    final btnCurve = CurvedAnimation(
      parent: _ctrl,
      curve: const Interval(0.72, 1.0, curve: Curves.easeOutCubic),
    );
    _btnFade  = btnCurve;
    _btnSlide = Tween<Offset>(
      begin: const Offset(0, 0.4),
      end: Offset.zero,
    ).animate(btnCurve);

    _ctrl.forward();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // ── Sign in ────────────────────────────────────────────────────────────────

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error   = null;
    });
    try {
      final user = await AuthService().signInWithGoogle();
      if (user == null && mounted) setState(() => _loading = false);
    } catch (e) {
      debugPrint('[LoginScreen] sign-in error: $e');
      if (mounted) setState(() { _loading = false; _error = e.toString(); });
    }
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Rich green background gradient ────────────────────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0.05, -0.45),
                radius: 1.35,
                colors: [Color(0xFF3E6B1C), AppColors.primary],
                stops: [0.0, 1.0],
              ),
            ),
          ),

          // ── Decorative arcs ───────────────────────────────────────────────
          AnimatedBuilder(
            animation: _arcs,
            builder: (_, __) => CustomPaint(
              painter: _ArcsPainter(_arcs.value),
              child: const SizedBox.expand(),
            ),
          ),

          // ── Content ───────────────────────────────────────────────────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(
                  horizontal: AppSizes.pagePadding),
              child: Column(
                children: [
                  const Spacer(flex: 3),

                  // ── Emblem ───────────────────────────────────────────────
                  FadeTransition(
                    opacity: _emblemFade,
                    child: ScaleTransition(
                      scale: _emblemScale,
                      child: const _Emblem(),
                    ),
                  ),

                  const SizedBox(height: 32),

                  // ── App name + gold rule ──────────────────────────────────
                  FadeTransition(
                    opacity: _titleFade,
                    child: SlideTransition(
                      position: _titleSlide,
                      child: Column(
                        children: [
                          const Text(
                            'Divine Traveler',
                            style: TextStyle(
                              fontSize: 38,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 10),
                          Container(
                            width: 56,
                            height: 2,
                            decoration: BoxDecoration(
                              color: AppColors.gold,
                              borderRadius: BorderRadius.circular(1),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  // ── Tagline ───────────────────────────────────────────────
                  FadeTransition(
                    opacity: _tagFade,
                    child: const Text(
                      'Read. Reflect. Journey\nthrough the divine word.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 15,
                        color: Colors.white60,
                        height: 1.7,
                        fontWeight: FontWeight.w300,
                        letterSpacing: 0.3,
                      ),
                    ),
                  ),

                  const Spacer(flex: 4),

                  // ── Button + footer ───────────────────────────────────────
                  FadeTransition(
                    opacity: _btnFade,
                    child: SlideTransition(
                      position: _btnSlide,
                      child: Column(
                        children: [
                          // Error banner
                          if (_error != null) ...[
                            Container(
                              margin: const EdgeInsets.only(bottom: 14),
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                color: Colors.white.withValues(alpha: 0.08),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(
                                    color:
                                        Colors.red[300]!.withValues(alpha: 0.5)),
                              ),
                              child: Row(
                                children: [
                                  Icon(Icons.error_outline,
                                      color: Colors.red[300], size: 16),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      _error!,
                                      style: TextStyle(
                                          color: Colors.red[200],
                                          fontSize: 12),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],

                          // Sign-in button
                          SizedBox(
                            width: double.infinity,
                            height: AppSizes.buttonHeight,
                            child: ElevatedButton(
                              onPressed: _loading ? null : _signIn,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.white,
                                foregroundColor: AppColors.textPrimary,
                                disabledBackgroundColor:
                                    Colors.white.withValues(alpha: 0.7),
                                elevation: 0,
                                shadowColor: Colors.transparent,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(
                                      AppSizes.buttonRadius),
                                ),
                              ),
                              child: _loading
                                  ? const SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary,
                                      ),
                                    )
                                  : const Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.center,
                                      children: [
                                        _GoogleLogo(),
                                        SizedBox(width: 12),
                                        Text(
                                          'Continue with Google',
                                          style: TextStyle(
                                            fontSize: 15,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                      ],
                                    ),
                            ),
                          ),

                          const SizedBox(height: 20),

                          RichText(
                            textAlign: TextAlign.center,
                            text: TextSpan(
                              style: const TextStyle(
                                fontSize: 11,
                                color: Colors.white30,
                                letterSpacing: 0.2,
                              ),
                              children: [
                                const TextSpan(
                                    text: 'By continuing you agree to our '),
                                TextSpan(
                                  text: 'Terms & Conditions',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    decoration: TextDecoration.underline,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () => Navigator.push(
                                          context,
                                          AppRoute(
                                            builder: (_) => const LegalScreen(
                                              document: LegalDocument
                                                  .termsAndConditions,
                                            ),
                                          ),
                                        ),
                                ),
                                const TextSpan(text: ' and '),
                                TextSpan(
                                  text: 'Privacy Policy',
                                  style: const TextStyle(
                                    color: Colors.white54,
                                    decoration: TextDecoration.underline,
                                  ),
                                  recognizer: TapGestureRecognizer()
                                    ..onTap = () => Navigator.push(
                                          context,
                                          AppRoute(
                                            builder: (_) => const LegalScreen(
                                              document:
                                                  LegalDocument.privacyPolicy,
                                            ),
                                          ),
                                        ),
                                ),
                                const TextSpan(text: '.'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 36),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ── Emblem ─────────────────────────────────────────────────────────────────────

class _Emblem extends StatelessWidget {
  const _Emblem();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 112,
      height: 112,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(
            color: AppColors.gold.withValues(alpha: 0.55), width: 1.0),
      ),
      child: Padding(
        padding: const EdgeInsets.all(7),
        child: Container(
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: Colors.white.withValues(alpha: 0.10),
            border: Border.all(
                color: AppColors.gold.withValues(alpha: 0.25), width: 0.5),
          ),
          child: ClipOval(
            child: Image.asset(
              'assets/logo.png',
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => const Icon(
                Icons.menu_book_rounded,
                size: 46,
                color: Colors.white,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Decorative arcs painter ────────────────────────────────────────────────────
// Draws three large circles that sweep in like a pen, plus a subtle gold ring.

class _ArcsPainter extends CustomPainter {
  final double progress; // 0 → 1

  const _ArcsPainter(this.progress);

  @override
  void paint(Canvas canvas, Size size) {
    void arc(Offset center, double radius, Color color,
        {double strokeWidth = 1.0, double delay = 0.0}) {
      final p = ((progress - delay) / (1.0 - delay)).clamp(0.0, 1.0);
      if (p <= 0) return;
      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        -pi / 2,
        2 * pi * p,
        false,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = strokeWidth
          ..strokeCap = StrokeCap.round,
      );
    }

    // Large circle — top-right, mostly off-screen
    arc(
      Offset(size.width * 1.05, -size.height * 0.02),
      size.width * 0.78,
      Colors.white.withValues(alpha: 0.07),
      strokeWidth: 1.0,
    );

    // Large circle — bottom-left
    arc(
      Offset(-size.width * 0.12, size.height * 1.04),
      size.width * 0.68,
      Colors.white.withValues(alpha: 0.05),
      strokeWidth: 0.8,
      delay: 0.1,
    );

    // Medium circle — right edge, mid-height
    arc(
      Offset(size.width * 1.1, size.height * 0.55),
      size.width * 0.42,
      Colors.white.withValues(alpha: 0.04),
      strokeWidth: 0.6,
      delay: 0.2,
    );

    // Subtle gold halo around where the emblem will appear
    arc(
      Offset(size.width * 0.5, size.height * 0.30),
      size.width * 0.23,
      AppColors.gold.withValues(alpha: 0.12),
      strokeWidth: 0.8,
      delay: 0.35,
    );
  }

  @override
  bool shouldRepaint(_ArcsPainter old) => old.progress != progress;
}

// ── Google logo (CustomPainter) ────────────────────────────────────────────────

class _GoogleLogo extends StatelessWidget {
  const _GoogleLogo();

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(22, 22),
      painter: _GoogleLogoPainter(),
    );
  }
}

class _GoogleLogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final cx = size.width / 2;
    final cy = size.height / 2;
    final r  = size.width / 2;

    final blue   = Paint()..color = const Color(0xFF4285F4);
    final green  = Paint()..color = const Color(0xFF34A853);
    final yellow = Paint()..color = const Color(0xFFFBBC05);
    final red    = Paint()..color = const Color(0xFFEA4335);
    final white  = Paint()..color = Colors.white;

    canvas.drawCircle(Offset(cx, cy), r, blue);

    void sector(double startDeg, double sweepDeg, Paint paint) {
      final path = Path()
        ..moveTo(cx, cy)
        ..arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: r),
            startDeg * pi / 180, sweepDeg * pi / 180, false)
        ..close();
      canvas.drawPath(path, paint);
    }

    sector(225, 90, red);
    sector(315, 90, yellow);
    sector(45, 90, green);

    canvas.drawCircle(Offset(cx, cy), r * 0.60, white);
    canvas.drawRect(Rect.fromLTWH(cx, cy - r * 0.13, r, r * 0.26), white);
  }

  @override
  bool shouldRepaint(_GoogleLogoPainter old) => false;
}
