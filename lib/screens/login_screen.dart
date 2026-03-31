import 'package:flutter/material.dart';
import 'package:tahfeex/resources/resources.dart';
import 'package:tahfeex/service/auth_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  bool _loading = false;
  String? _error;

  Future<void> _signIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final user = await AuthService().signInWithGoogle();
      if (user == null && mounted) {
        // User cancelled the picker — just reset.
        setState(() => _loading = false);
      }
      // On success the auth gate (StreamBuilder in main.dart) automatically
      // navigates to HomeScreen; no explicit Navigator call needed here.
    } catch (e) {
      debugPrint('[LoginScreen] sign-in error: $e');
      if (mounted) {
        setState(() {
          _loading = false;
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            children: [
              SizedBox(height: size.height * 0.12),

              // ── Logo ───────────────────────────────────────────────────
              Container(
                width: 96,
                height: 96,
                decoration: BoxDecoration(
                  color: AppColors.primaryColor.withOpacity(0.08),
                  shape: BoxShape.circle,
                ),
                child: ClipOval(
                  child: Image.asset(
                    'assets/logo.png',
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const Icon(
                      Icons.menu_book_rounded,
                      size: 52,
                      color: AppColors.primaryColor,
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 24),

              // ── App name ───────────────────────────────────────────────
              const Text(
                'Tahfeex',
                style: TextStyle(
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primaryColor,
                  letterSpacing: 1,
                ),
              ),

              const SizedBox(height: 8),

              Text(
                'Your Quran memorization companion',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 15,
                  color: Colors.grey[600],
                ),
              ),

              const Spacer(),

              // ── Error banner ───────────────────────────────────────────
              if (_error != null) ...[
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline,
                          color: Colors.red, size: 18),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _error!,
                          style: const TextStyle(
                              color: Colors.red, fontSize: 13),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
              ],

              // ── Sign-in button ─────────────────────────────────────────
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _loading ? null : _signIn,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black87,
                    elevation: 1,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(8),
                      side: BorderSide(color: Colors.grey[300]!),
                    ),
                  ),
                  child: _loading
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primaryColor,
                          ),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            // Google "G" logo
                            _GoogleLogo(),
                            const SizedBox(width: 12),
                            const Text(
                              'Continue with Google',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ],
                        ),
                ),
              ),

              const SizedBox(height: 16),

              Text(
                'By continuing you agree to our Terms of Service.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 11, color: Colors.grey[500]),
              ),

              SizedBox(height: size.height * 0.06),
            ],
          ),
        ),
      ),
    );
  }
}

/// Simple hand-drawn Google "G" using a CustomPainter so we don't need
/// an asset file.  Replace with an SVG if you prefer.
class _GoogleLogo extends StatelessWidget {
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
    final r = size.width / 2;

    final bluePaint   = Paint()..color = const Color(0xFF4285F4);
    final greenPaint  = Paint()..color = const Color(0xFF34A853);
    final yellowPaint = Paint()..color = const Color(0xFFFBBC05);
    final redPaint    = Paint()..color = const Color(0xFFEA4335);
    final whitePaint  = Paint()..color = Colors.white;

    // Full circle
    canvas.drawCircle(Offset(cx, cy), r, bluePaint);

    // Red (top-left arc)
    final redPath = Path()
      ..moveTo(cx, cy)
      ..arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: r),
          _deg(225), _deg(90), false)
      ..close();
    canvas.drawPath(redPath, redPaint);

    // Yellow (bottom arc)
    final yellowPath = Path()
      ..moveTo(cx, cy)
      ..arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: r),
          _deg(315), _deg(90), false)
      ..close();
    canvas.drawPath(yellowPath, yellowPaint);

    // Green (top-right arc)
    final greenPath = Path()
      ..moveTo(cx, cy)
      ..arcTo(Rect.fromCircle(center: Offset(cx, cy), radius: r),
          _deg(45), _deg(90), false)
      ..close();
    canvas.drawPath(greenPath, greenPaint);

    // Inner white circle
    canvas.drawCircle(Offset(cx, cy), r * 0.60, whitePaint);

    // White horizontal bar (for the crossbar of the G)
    canvas.drawRect(
      Rect.fromLTWH(cx, cy - r * 0.13, r, r * 0.26),
      whitePaint,
    );
  }

  double _deg(double deg) => deg * 3.14159265 / 180;

  @override
  bool shouldRepaint(_GoogleLogoPainter old) => false;
}
