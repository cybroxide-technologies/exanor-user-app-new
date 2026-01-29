import 'dart:ui';

import 'package:exanor/components/translation_widget.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class SwipeToPayButton extends StatefulWidget {
  final VoidCallback onSwipeCompleted;
  final bool isEnabled;
  final bool isLoading;
  final String text; // Ignored if amount is present, or used as prefix
  final String? amount;
  final Color? color;

  const SwipeToPayButton({
    super.key,
    required this.onSwipeCompleted,
    this.isEnabled = true,
    this.isLoading = false,
    this.text = 'Swipe to pay',
    this.amount,
    this.color,
  });

  @override
  State<SwipeToPayButton> createState() => _SwipeToPayButtonState();
}

class _SwipeToPayButtonState extends State<SwipeToPayButton>
    with TickerProviderStateMixin {
  // Animation Controllers
  late AnimationController _successController;
  late AnimationController _nudgeController;

  // State
  double _dragValue = 0.0;
  double _maxWidth = 0.0;
  bool _isDragging = false;
  bool _isCompleted = false;

  @override
  void initState() {
    super.initState();

    // 2. Success Morph Animation
    _successController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 400),
    );

    // 3. Nudge Animation (Subtle arrow movement)
    _nudgeController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _successController.dispose();
    _nudgeController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SwipeToPayButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.isLoading && oldWidget.isLoading) {
      if (mounted) {
        setState(() {
          _isCompleted = false;
          _dragValue = 0.0;
          _successController.reset();
          _nudgeController.repeat(reverse: true);
        });
      }
    }
  }

  void _onDragStart(DragStartDetails details) {
    if (!widget.isEnabled || widget.isLoading || _isCompleted) return;
    setState(() {
      _isDragging = true;
    });
    _nudgeController.stop(); // Stop nudge while dragging
    _nudgeController.value = 0.0; // Reset to center
    HapticFeedback.selectionClick();
  }

  void _onDragUpdate(DragUpdateDetails details) {
    if (!widget.isEnabled || widget.isLoading || _isCompleted) return;
    setState(() {
      _dragValue = (_dragValue + details.delta.dx).clamp(0.0, _maxWidth);
    });
  }

  void _onDragEnd(DragEndDetails details) {
    if (!widget.isEnabled || widget.isLoading || _isCompleted) return;
    setState(() {
      _isDragging = false;
    });

    if (_dragValue > _maxWidth * 0.75) {
      _handleSuccess();
    } else {
      _snapBack();
      _nudgeController.repeat(reverse: true); // Resume nudge
    }
  }

  void _handleSuccess() {
    setState(() {
      _isCompleted = true;
      _dragValue = _maxWidth;
    });
    HapticFeedback.mediumImpact();
    _successController.forward().then((_) {
      widget.onSwipeCompleted();
    });
  }

  void _snapBack() {
    HapticFeedback.lightImpact();
    final start = _dragValue;
    AnimationController snapController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    Animation<double> animation = CurvedAnimation(
      parent: snapController,
      curve: Curves.easeOutCubic,
    );

    animation.addListener(() {
      setState(() {
        _dragValue = start * (1.0 - animation.value);
      });
    });

    snapController.forward().then((_) => snapController.dispose());
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final primaryColor = widget.color ?? theme.colorScheme.primary;
    const buttonHeight = 60.0;

    return LayoutBuilder(
      builder: (context, constraints) {
        final fullWidth = constraints.maxWidth;
        final targetWidth = _isCompleted ? buttonHeight : fullWidth;

        return AnimatedBuilder(
          animation: _successController,
          builder: (context, child) {
            final currentWidth = lerpDouble(
              fullWidth,
              targetWidth,
              _successController.value,
            )!;

            _maxWidth = fullWidth - buttonHeight;
            final borderRadius = BorderRadius.circular(30);
            final isDark = theme.brightness == Brightness.dark;

            return Align(
              alignment: Alignment.center,
              child: SizedBox(
                width: currentWidth,
                height: buttonHeight,
                child: Stack(
                  children: [
                    // 1. Base Track (Clean, Modern, "Cutout" logic)
                    Container(
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.grey[900]
                            : const Color(0xFFF5F5F5),
                        borderRadius: borderRadius,
                        // Subtle inner-like styling via border/shadow
                        border: Border.all(
                          color: isDark ? Colors.grey[800]! : Colors.grey[300]!,
                        ),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.05),
                            blurRadius: 4,
                            spreadRadius: 0,
                            offset: const Offset(0, 2),
                            blurStyle: BlurStyle.inner, // Creates depth
                          ),
                        ],
                      ),
                    ),

                    // 2. Active Fill (Solid Primary)
                    if (!_isCompleted)
                      Container(
                        width: buttonHeight + _dragValue,
                        height: buttonHeight,
                        decoration: BoxDecoration(
                          borderRadius: borderRadius,
                          color: primaryColor,
                          boxShadow: [
                            if (_dragValue > 0)
                              BoxShadow(
                                color: primaryColor.withOpacity(0.4),
                                blurRadius: 10,
                                offset: const Offset(2, 0),
                              ),
                          ],
                        ),
                      ),

                    // 3. Text (High Contrast)
                    if (!_isCompleted)
                      Center(
                        child: Opacity(
                          opacity: (1.0 - (_dragValue / _maxWidth)).clamp(
                            0.0,
                            1.0,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              TranslatedText(
                                widget.text,
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: theme.colorScheme.onSurface
                                      .withOpacity(0.6),
                                  letterSpacing: 0.5,
                                ),
                              ),
                              if (widget.amount != null) ...[
                                const SizedBox(width: 8),
                                TranslatedText(
                                  widget.amount!,
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: theme.colorScheme.onSurface
                                        .withOpacity(0.6),
                                    letterSpacing: 0.5,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                      ),

                    // 4. Slider Thumb (Crisp White)
                    Positioned(
                      left: _isCompleted ? 0 : _dragValue,
                      top: 0,
                      bottom: 0,
                      child: GestureDetector(
                        onHorizontalDragStart: _onDragStart,
                        onHorizontalDragUpdate: _onDragUpdate,
                        onHorizontalDragEnd: _onDragEnd,
                        child: AnimatedBuilder(
                          animation: _nudgeController,
                          builder: (context, child) {
                            return Container(
                              width: buttonHeight,
                              height: buttonHeight,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isCompleted
                                    ? Colors.green
                                    : Colors.white,
                                border: Border.all(
                                  color: Colors.grey.withOpacity(0.1),
                                  width: 1,
                                ),
                                boxShadow: [
                                  // Clean, realistic shadow
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.15),
                                    blurRadius: 6,
                                    spreadRadius: 1,
                                    offset: const Offset(0, 3),
                                  ),
                                  BoxShadow(
                                    color: Colors.black.withOpacity(0.05),
                                    blurRadius: 2,
                                    offset: const Offset(0, 1),
                                  ),
                                ],
                              ),
                              child: Center(
                                child: _isCompleted
                                    ? const Icon(
                                        Icons.check,
                                        color: Colors.white,
                                      )
                                    : widget.isLoading
                                    ? Padding(
                                        padding: const EdgeInsets.all(16.0),
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2.5,
                                          valueColor: AlwaysStoppedAnimation(
                                            primaryColor,
                                          ),
                                        ),
                                      )
                                    : Transform.translate(
                                        offset: Offset(
                                          _nudgeController.value * 3,
                                          0,
                                        ),
                                        child: Icon(
                                          Icons.arrow_forward_rounded,
                                          color: primaryColor,
                                          size: 26,
                                        ),
                                      ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}
