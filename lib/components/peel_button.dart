import 'dart:math';
import 'package:flutter/material.dart';

class PeelButton extends StatefulWidget {
  final VoidCallback? onTap;
  final String text;
  final String? price;
  final bool isLoading;
  final bool isEnabled;
  final Color? color;
  final List<Color>? gradientColors; // Added parameter
  final double height;
  final double borderRadius;

  const PeelButton({
    super.key,
    required this.onTap,
    required this.text,
    this.price,
    this.isLoading = false,
    this.isEnabled = true,
    this.color,
    this.gradientColors, // Added to constructor
    this.height = 56,
    this.borderRadius = 30,
  });

  @override
  State<PeelButton> createState() => _PeelButtonState();
}

class _PeelButtonState extends State<PeelButton> with TickerProviderStateMixin {
  late AnimationController _rippleController;
  late AnimationController _tiltController;
  late Animation<double> _rippleAnimation;

  Offset _tapPosition = Offset.zero;
  Offset _tilt = Offset.zero;

  @override
  void initState() {
    super.initState();
    _rippleController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _rippleAnimation = CurvedAnimation(
      parent: _rippleController,
      curve: Curves.easeOutExpo,
    );

    _tiltController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _rippleController.dispose();
    _tiltController.dispose();
    super.dispose();
  }

  void _handlePanUpdate(DragUpdateDetails details) {
    if (!widget.isEnabled || widget.isLoading) return;
    _updateTilt(details.localPosition);
  }

  void _handleTapDown(TapDownDetails details) {
    if (!widget.isEnabled || widget.isLoading) return;
    setState(() {
      _tapPosition = details.localPosition;
    });
    _updateTilt(details.localPosition);
    _rippleController.forward(from: 0.0);
  }

  void _updateTilt(Offset localPos) {
    final centerX = context.size!.width / 2;
    final centerY = context.size!.height / 2;
    setState(() {
      _tilt = Offset(
        (localPos.dx - centerX) / centerX,
        (localPos.dy - centerY) / centerY,
      );
    });
    _tiltController.forward();
  }

  void _handleTapUp(TapUpDetails details) {
    if (!widget.isEnabled || widget.isLoading) return;
    _resetTilt();
    widget.onTap?.call();
  }

  void _handleTapCancel() {
    _resetTilt();
  }

  void _resetTilt() {
    setState(() {
      _tilt = Offset.zero;
    });
    _tiltController.reverse();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = widget.color ?? theme.primaryColor;
    final disabledColor = Colors.grey[300]!;

    return MouseRegion(
      onEnter: (_) => _tiltController.forward(),
      onExit: (_) => _resetTilt(),
      child: GestureDetector(
        onTapDown: _handleTapDown,
        onTapUp: _handleTapUp,
        onTapCancel: _handleTapCancel,
        onPanUpdate: _handlePanUpdate,
        onPanEnd: (_) => _resetTilt(),
        child: AnimatedBuilder(
          animation: _tiltController,
          builder: (context, child) {
            return Transform(
              transform: Matrix4.identity()
                ..setEntry(3, 2, 0.001) // perspective
                ..rotateX(-_tilt.dy * 0.1 * _tiltController.value)
                ..rotateY(_tilt.dx * 0.1 * _tiltController.value)
                ..scale(1.0 - (0.02 * _tiltController.value)),
              alignment: Alignment.center,
              child: child,
            );
          },
          child: Container(
            height: widget.height,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: !widget.isEnabled
                    ? [disabledColor, disabledColor]
                    : widget.gradientColors ??
                          [
                            primaryColor,
                            primaryColor.withBlue(
                              min(255, primaryColor.blue + 30),
                            ),
                          ],
              ),
              boxShadow: widget.isEnabled
                  ? [
                      BoxShadow(
                        color: primaryColor.withOpacity(0.3),
                        spreadRadius: 0,
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ]
                  : [],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(widget.borderRadius),
              child: Stack(
                children: [
                  // Ripple Effect
                  AnimatedBuilder(
                    animation: _rippleAnimation,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: _CirclurPeelPainter(
                          position: _tapPosition,
                          progress: _rippleAnimation.value,
                          color: Colors.white.withOpacity(0.3),
                        ),
                        size: Size.infinite,
                      );
                    },
                  ),

                  // Subtle Shine
                  _ContinuousShine(isEnabled: widget.isEnabled),

                  // Content
                  Center(
                    child: widget.isLoading
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              valueColor: AlwaysStoppedAnimation<Color>(
                                Colors.white,
                              ),
                              strokeWidth: 2,
                            ),
                          )
                        : _buildContent(),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildContent() {
    return AnimatedSwitcher(
      duration: const Duration(milliseconds: 300),
      child: Row(
        key: ValueKey(widget.text + (widget.price ?? "")),
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.shopping_bag_outlined,
            color: widget.isEnabled
                ? Colors.white.withOpacity(0.9)
                : Colors.grey[500],
            size: widget.height > 40 ? 18 : 14,
          ),
          const SizedBox(width: 8),
          Text(
            widget.text,
            style: TextStyle(
              color: widget.isEnabled ? Colors.white : Colors.grey[600],
              fontSize: widget.height > 40 ? 15 : 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          if (widget.price != null) ...[
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Container(
                height: 12,
                width: 1,
                color: Colors.white.withOpacity(0.3),
              ),
            ),
            Text(
              widget.price!,
              style: TextStyle(
                color: Colors.white,
                fontSize: widget.height > 40 ? 15 : 12,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _CirclurPeelPainter extends CustomPainter {
  final Offset position;
  final double progress;
  final Color color;

  _CirclurPeelPainter({
    required this.position,
    required this.progress,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (progress == 0 || progress == 1) return;

    final paint = Paint()
      ..color = color.withOpacity(color.opacity * (1 - progress))
      ..style = PaintingStyle.fill;

    double radius = max(size.width, size.height) * 1.5 * progress;
    canvas.drawCircle(position, radius, paint);
  }

  @override
  bool shouldRepaint(_CirclurPeelPainter oldDelegate) => true;
}

class _ContinuousShine extends StatefulWidget {
  final bool isEnabled;
  const _ContinuousShine({required this.isEnabled});

  @override
  State<_ContinuousShine> createState() => _ContinuousShineState();
}

class _ContinuousShineState extends State<_ContinuousShine>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.isEnabled) return const SizedBox.shrink();
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return FractionallySizedBox(
          widthFactor: 2,
          child: Transform.rotate(
            angle: -pi / 4,
            child: Transform.translate(
              offset: Offset(-1 + (_controller.value * 2), 0) * 200,
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0),
                      Colors.white.withOpacity(0.05),
                      Colors.white.withOpacity(0.2),
                      Colors.white.withOpacity(0.05),
                      Colors.white.withOpacity(0),
                    ],
                    stops: const [0.1, 0.45, 0.5, 0.55, 0.9],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
