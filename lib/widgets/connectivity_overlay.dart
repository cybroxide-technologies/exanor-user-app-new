import 'dart:async';
import 'dart:math' as math;
import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';

class ConnectivityOverlay extends StatefulWidget {
  final Widget child;

  const ConnectivityOverlay({super.key, required this.child});

  @override
  State<ConnectivityOverlay> createState() => _ConnectivityOverlayState();
}

class _ConnectivityOverlayState extends State<ConnectivityOverlay> {
  late StreamSubscription<List<ConnectivityResult>> _connectivitySubscription;
  bool _isOffline = false;
  bool _isChecking = false;

  @override
  void initState() {
    super.initState();
    _initConnectivity();
    _connectivitySubscription = Connectivity().onConnectivityChanged.listen(
      _updateConnectionStatus,
    );
  }

  @override
  void dispose() {
    _connectivitySubscription.cancel();
    super.dispose();
  }

  Future<void> _initConnectivity() async {
    try {
      final results = await Connectivity().checkConnectivity();
      _updateConnectionStatus(results);
    } catch (e) {
      debugPrint('Couldn\'t check connectivity status: $e');
    }
  }

  void _updateConnectionStatus(List<ConnectivityResult> results) {
    bool isConnected = results.any(
      (result) =>
          result == ConnectivityResult.mobile ||
          result == ConnectivityResult.wifi ||
          result == ConnectivityResult.ethernet ||
          result == ConnectivityResult.vpn,
    );

    if (mounted) {
      if (!isConnected) {
        // Only show offline screen if connection is lost.
        // Do NOT automatically hide it when connection returns.
        setState(() {
          _isOffline = true;
        });
      }
    }
  }

  Future<void> _handleTryAgain() async {
    if (_isChecking) return;

    setState(() {
      _isChecking = true;
    });

    // Simulated network check delay
    await Future.delayed(const Duration(milliseconds: 1500));

    try {
      final results = await Connectivity().checkConnectivity();
      bool isConnected = results.any(
        (result) => result != ConnectivityResult.none,
      );

      if (mounted) {
        setState(() {
          _isChecking = false;
        });

        if (isConnected) {
          setState(() {
            _isOffline = false;
          });

          // Force UI to rebuild
          (context as Element).markNeedsBuild();
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text("Still no internet connection"),
              behavior: SnackBarBehavior.floating,
              backgroundColor: const Color(0xFF6C5CE7), // Purple to match UFO
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
              ),
              margin: const EdgeInsets.all(16),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isChecking = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        widget.child,
        if (_isOffline) const Positioned.fill(child: _OfflinePage()),
      ],
    );
  }
}

class _OfflinePage extends StatelessWidget {
  const _OfflinePage();

  @override
  Widget build(BuildContext context) {
    final parentState = context
        .findAncestorStateOfType<_ConnectivityOverlayState>();
    final isChecking = parentState?._isChecking ?? false;

    return Scaffold(
      backgroundColor: const Color(0xFFFDFDFD),
      body: SafeArea(
        child: Column(
          children: [
            const Spacer(flex: 2),
            // UFO Scene
            const Center(child: UfoAbductionScene()),
            const Spacer(flex: 1),

            // Header Text
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 40.0),
              child: Column(
                children: [
                  const Text(
                    "Connection Lost",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF2D3436),
                      fontFamily: 'Inter',
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    "We've lost contact with the server.\nPlease check your internet connection.",
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 15,
                      color: Colors.grey[600],
                      height: 1.5,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(flex: 2),

            // Try Again Button
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 32.0,
                vertical: 24,
              ),
              child: SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: isChecking
                      ? null
                      : () => parentState?._handleTryAgain(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF2D3436),
                    foregroundColor: Colors.white,
                    elevation: 4,
                    shadowColor: const Color(0xFF2D3436).withOpacity(0.3),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: isChecking
                      ? const SizedBox(
                          width: 24,
                          height: 24,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              Colors.white,
                            ),
                          ),
                        )
                      : const Text(
                          "TRY AGAIN",
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 0.5,
                          ),
                        ),
                ),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// ENHANCED UFO SCENE
// ---------------------------------------------------------------------------
class UfoAbductionScene extends StatefulWidget {
  const UfoAbductionScene({super.key});

  @override
  State<UfoAbductionScene> createState() => _UfoAbductionSceneState();
}

class _UfoAbductionSceneState extends State<UfoAbductionScene>
    with TickerProviderStateMixin {
  late AnimationController _hoverController;
  late AnimationController _beamController;

  @override
  void initState() {
    super.initState();
    _hoverController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _beamController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat();
  }

  @override
  void dispose() {
    _hoverController.dispose();
    _beamController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320,
      height: 400,
      child: AnimatedBuilder(
        animation: Listenable.merge([_hoverController, _beamController]),
        builder: (context, child) {
          final hoverVal = _hoverController.value;
          final beamVal = _beamController.value;

          // Complex hover motion
          final dx = math.sin(hoverVal * math.pi * 2) * 20;
          final dy = math.cos(hoverVal * math.pi * 2) * 15;
          final tilt = math.sin(hoverVal * math.pi) * 0.05;

          return Stack(
            alignment: Alignment.center,
            children: [
              // 1. Ground Shadow (Scales with UFO height)
              Positioned(
                bottom: 60,
                // Track horizontal movement (dx)
                left: 160 + dx - 60,
                child: Transform.scale(
                  // Inverted logic: Closer to ground (higher dy) -> Larger shadow
                  scale: 0.8 + ((dy + 15) / 30) * 0.2, // Range: 0.8 to 1.0
                  child: Container(
                    width: 120,
                    height: 20,
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(
                        0.1,
                      ), // Slightly darker for better visibility
                      borderRadius: BorderRadius.circular(100),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.1),
                          blurRadius: 10,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                ),
              ),

              // 2. The Beam (Enhanced)
              Positioned(
                top: 130 + dy,
                left: 160 + dx - 60, // Centered regarding beam width
                child: CustomPaint(
                  size: const Size(120, 220),
                  painter: EnhancedBeamPainter(pulse: beamVal),
                ),
              ),

              // 3. Floating Particles in Beam
              Positioned(
                top: 150 + dy,
                left: 160 + dx - 40,
                child: SizedBox(
                  width: 80,
                  height: 200,
                  child: BeamParticles(controller: _beamController),
                ),
              ),

              // 4. The Abducted Icon
              Positioned(
                top: 220 + dy + math.sin(beamVal * math.pi * 2) * 5,
                left: 160 + dx - 28,
                child: Transform.rotate(
                  // Use sine wave for smooth continuous rocking instead of linear jump
                  angle: math.sin(beamVal * math.pi * 2) * 0.15,
                  child: Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF6C5CE7).withOpacity(0.3),
                          blurRadius: 20,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: const Icon(
                      Icons.wifi_off_rounded,
                      color: Color(0xFF6C5CE7),
                      size: 32,
                    ),
                  ),
                ),
              ),

              // 5. The UFO Body
              Positioned(
                top: 60 + dy,
                left: 160 + dx - 90,
                child: Transform.rotate(
                  angle: tilt,
                  child: PremiumUfoWidget(lightPhase: beamVal),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class BeamParticles extends StatelessWidget {
  final AnimationController controller;

  const BeamParticles({super.key, required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, child) {
        return Stack(
          children: List.generate(5, (index) {
            // Pseudo-random movement based on time + index
            final t = (controller.value + index * 0.2) % 1.0;
            final y = 200 * (1 - t); // Move up
            final x = 40 + math.sin(t * 10 + index) * 20;

            return Positioned(
              top: y,
              left: x,
              child: Opacity(
                opacity: math.sin(t * math.pi), // Fade in/out
                child: Container(
                  width: 4,
                  height: 4,
                  decoration: const BoxDecoration(
                    color: Colors.white,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}

class EnhancedBeamPainter extends CustomPainter {
  final double pulse;

  EnhancedBeamPainter({required this.pulse});

  @override
  void paint(Canvas canvas, Size size) {
    final path = Path();
    const topWidth = 40.0;
    const bottomWidth = 100.0;

    path.moveTo(size.width / 2 - topWidth / 2, 0);
    path.lineTo(size.width / 2 + topWidth / 2, 0);
    path.lineTo(size.width / 2 + bottomWidth / 2, size.height);
    path.lineTo(size.width / 2 - bottomWidth / 2, size.height);
    path.close();

    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        stops: const [0.0, 0.8, 1.0],
        colors: [
          const Color(0xFFA29BFE).withOpacity(0.6), // Top alpha
          const Color(0xFFA29BFE).withOpacity(0.1),
          const Color(0xFFA29BFE).withOpacity(0.0),
        ],
      ).createShader(Rect.fromLTWH(0, 0, size.width, size.height));

    canvas.drawPath(path, paint);

    // Add scanning line
    final scanY = size.height * pulse;
    final scanWidth = topWidth + (bottomWidth - topWidth) * pulse;

    final scanPaint = Paint()
      ..color = Colors.white
          .withOpacity(0.3 * (1 - pulse)) // Fade out at bottom
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    canvas.drawLine(
      Offset((size.width - scanWidth) / 2, scanY),
      Offset((size.width + scanWidth) / 2, scanY),
      scanPaint,
    );
  }

  @override
  bool shouldRepaint(EnhancedBeamPainter oldDelegate) => true;
}

class PremiumUfoWidget extends StatelessWidget {
  final double lightPhase;

  const PremiumUfoWidget({super.key, required this.lightPhase});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 180,
      height: 100,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Glass Dome (Back part)
          Positioned(
            top: 0,
            child: Container(
              width: 80,
              height: 60,
              decoration: BoxDecoration(
                color: const Color(0xFFDFE6E9),
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFF2D3436), width: 3),
              ),
            ),
          ),

          // Alien/Cockpit content could go here

          // Saucer Body Main
          Positioned(
            top: 35,
            child: Container(
              width: 180,
              height: 55,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFF6C5CE7), // Lighter purple top
                    Color(0xFF4834D4), // Darker purple bottom
                  ],
                ),
                borderRadius: BorderRadius.circular(100),
                border: Border.all(color: const Color(0xFF2D3436), width: 3),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    offset: const Offset(0, 4),
                    blurRadius: 4,
                  ),
                ],
              ),
            ),
          ),

          // Glass Dome (Front shine)
          Positioned(
            top: 5,
            left: 60,
            child: Container(
              width: 25,
              height: 25,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
            ),
          ),

          // Lights Ring
          Positioned(
            top: 58,
            child: SizedBox(
              width: 150,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: List.generate(5, (index) {
                  // Running light effect
                  final active = ((lightPhase * 5).floor() % 5) == index;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 100),
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: active
                          ? const Color(0xFF00B894)
                          : const Color(0xFF55EFC4),
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: const Color(0xFF2D3436),
                        width: 1.5,
                      ),
                      boxShadow: active
                          ? [
                              BoxShadow(
                                color: const Color(0xFF00B894).withOpacity(0.8),
                                blurRadius: 6,
                                spreadRadius: 2,
                              ),
                            ]
                          : [],
                    ),
                  );
                }),
              ),
            ),
          ),

          // Engine / Bottom Thruster
          Positioned(
            bottom: 0,
            child: Container(
              width: 60,
              height: 15,
              decoration: BoxDecoration(
                color: const Color(0xFFFAB1A0),
                borderRadius: const BorderRadius.only(
                  bottomLeft: Radius.circular(20),
                  bottomRight: Radius.circular(20),
                ),
                border: Border.all(color: const Color(0xFF2D3436), width: 3),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
