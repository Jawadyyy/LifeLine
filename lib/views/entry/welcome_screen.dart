import 'package:flutter/material.dart';
import 'package:flutter_gen/gen_l10n/app_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:lifeline/views/auth/login_screen.dart';

/// Onboarding palette, ported from the "Lifeline Welcome" design.
const Color _accent = Color(0xFFDB4527);
const List<Color> _headerGrad = [Color(0xFFF1743D), Color(0xFFDB4527)];
const List<Color> _buttonGrad = [Color(0xFFEC5E32), Color(0xFFD5402A)];
const Color _ink = Color(0xFF3A322C);
const Color _muted = Color(0xFF7C736C);
const Color _dotIdle = Color(0xFFE7E1DB);
const Color _bg = Color(0xFFFCFBF9);

/// One onboarding page. Each entry is a separate [PageView] child so swiping
/// between them stays smooth (content is not swapped in place).
class _Onboard {
  final String eyebrow;
  final String title;
  final String heading;
  final String body;
  final IconData icon;
  const _Onboard({
    required this.eyebrow,
    required this.title,
    required this.heading,
    required this.body,
    required this.icon,
  });
}

/// Builds the onboarding pages from the active locale's strings. Not const so
/// the copy follows the user's language choice.
List<_Onboard> _buildPages(AppLocalizations l) => [
      _Onboard(
        eyebrow: l.onboardEyebrow1,
        title: l.appName,
        heading: l.onboardHeading1,
        body: l.onboardBody1,
        icon: Icons.favorite,
      ),
      _Onboard(
        eyebrow: l.onboardEyebrow2,
        title: l.onboardTitle2,
        heading: l.onboardHeading2,
        body: l.onboardBody2,
        icon: Icons.location_on,
      ),
      _Onboard(
        eyebrow: l.onboardEyebrow3,
        title: l.onboardTitle3,
        heading: l.onboardHeading3,
        body: l.onboardBody3,
        icon: Icons.verified_user,
      ),
    ];

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen>
    with SingleTickerProviderStateMixin {
  final PageController _controller = PageController();
  late final AnimationController _pulse;
  int _index = 0;
  List<_Onboard> _pages = const [];

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    )..repeat(reverse: true);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Rebuild the onboarding copy whenever the locale changes.
    _pages = _buildPages(AppLocalizations.of(context));
  }

  @override
  void dispose() {
    _controller.dispose();
    _pulse.dispose();
    super.dispose();
  }

  void _goTo(int i) => _controller.animateToPage(
        i,
        duration: const Duration(milliseconds: 350),
        curve: Curves.easeInOut,
      );

  void _next() {
    if (_index >= _pages.length - 1) {
      _finish();
    } else {
      _goTo(_index + 1);
    }
  }

  void _finish() {
    Navigator.of(context).push(
      PageRouteBuilder(
        pageBuilder: (_, __, ___) => const LoginScreen(),
        transitionsBuilder: (_, animation, __, child) =>
            FadeTransition(opacity: animation, child: child),
        transitionDuration: const Duration(milliseconds: 500),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    final bool last = _index == _pages.length - 1;

    return Scaffold(
      backgroundColor: _bg,
      body: Column(
        children: [
          // Swipeable content — one real page per dot. Fills all space above
          // the controls, so the split adapts to any screen height.
          Expanded(
            child: PageView.builder(
              controller: _controller,
              itemCount: _pages.length,
              onPageChanged: (i) => setState(() => _index = i),
              itemBuilder: (_, i) => _PageBody(page: _pages[i], pulse: _pulse),
            ),
          ),

          // Controls sit on the same background as the sheet, so they read as
          // one continuous surface without any hard-coded overlap padding.
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(28, 8, 28, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Row(
                    children: [
                      for (int i = 0; i < _pages.length; i++)
                        GestureDetector(
                          onTap: () => _goTo(i),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 250),
                            curve: Curves.easeInOut,
                            width: i == _index ? 22 : 7,
                            height: 7,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: i == _index ? _accent : _dotIdle,
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _CtaButton(
                    label: last ? l.getStarted : l.continueLabel,
                    onTap: _next,
                  ),
                  // Reserve the skip row's height on every page so the button
                  // doesn't jump when it hides on the last page.
                  SizedBox(
                    height: 34,
                    child: IgnorePointer(
                      ignoring: last,
                      child: AnimatedOpacity(
                        opacity: last ? 0 : 1,
                        duration: const Duration(milliseconds: 200),
                        child: TextButton(
                          onPressed: _finish,
                          child: Text(
                            l.skip,
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              color: _muted,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// The gradient header (icon + eyebrow + title) and white sheet (heading +
/// body) for a single onboarding page. Sizes itself to the height it is given,
/// so it works across phone sizes without overflowing.
class _PageBody extends StatelessWidget {
  const _PageBody({required this.page, required this.pulse});

  final _Onboard page;
  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final double headerH = c.maxHeight * 0.55;
        return Stack(
          children: [
            // Gradient header.
            Container(
              height: headerH + 24,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: _headerGrad,
                ),
              ),
              child: SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
                  // scaleDown keeps the icon + title inside short headers
                  // instead of overflowing on small screens.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: SizedBox(
                      width: c.maxWidth - 48,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _PulseIcon(icon: page.icon, pulse: pulse),
                          const SizedBox(height: 22),
                          Text(
                            page.eyebrow.toUpperCase(),
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 2.0,
                              color: Colors.white.withOpacity(0.85),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            page.title,
                            textAlign: TextAlign.center,
                            style: GoogleFonts.nunito(
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              height: 1.05,
                              letterSpacing: -0.4,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // White sheet, overlapping the header by 24px with a rounded top.
            Positioned(
              top: headerH - 24,
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                decoration: const BoxDecoration(
                  color: _bg,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                padding: const EdgeInsets.fromLTRB(28, 20, 28, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 36,
                        height: 4,
                        decoration: BoxDecoration(
                          color: _dotIdle,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 28),
                    // Scrolls rather than overflows if a device is very short
                    // or the OS text scale is cranked up.
                    Expanded(
                      child: SingleChildScrollView(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              page.heading,
                              style: GoogleFonts.nunito(
                                fontSize: 26,
                                fontWeight: FontWeight.w700,
                                letterSpacing: -0.3,
                                color: _ink,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Text(
                              page.body,
                              style: GoogleFonts.nunito(
                                fontSize: 15.5,
                                height: 1.6,
                                color: _muted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Glass icon disc with a slow pulsing halo, matching the design's pulseGlow.
class _PulseIcon extends StatelessWidget {
  const _PulseIcon({required this.icon, required this.pulse});

  final IconData icon;
  final AnimationController pulse;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 104,
      height: 104,
      child: Stack(
        alignment: Alignment.center,
        children: [
          AnimatedBuilder(
            animation: pulse,
            builder: (_, __) {
              final t = pulse.value;
              return Opacity(
                opacity: 0.55 + 0.35 * t,
                child: Transform.scale(
                  scale: 1.0 + 0.06 * t,
                  child: Container(
                    width: 104,
                    height: 104,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withOpacity(0.18),
                    ),
                  ),
                ),
              );
            },
          ),
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white.withOpacity(0.16),
              border: Border.all(color: Colors.white.withOpacity(0.4), width: 1.5),
            ),
            child: Icon(icon, color: Colors.white, size: 40),
          ),
        ],
      ),
    );
  }
}

class _CtaButton extends StatelessWidget {
  const _CtaButton({required this.label, required this.onTap});

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 58,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(29),
          gradient: const LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: _buttonGrad,
          ),
          boxShadow: [
            BoxShadow(
              color: _accent.withOpacity(0.4),
              blurRadius: 24,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              label,
              style: GoogleFonts.nunito(
                fontSize: 17,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.arrow_forward, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }
}
