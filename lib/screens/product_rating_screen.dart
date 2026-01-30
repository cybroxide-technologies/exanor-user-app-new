import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:exanor/services/api_service.dart';

class ProductRatingScreen extends StatefulWidget {
  final String orderId;
  final String productId;
  final String productName;
  final String? productImage;
  final double? initialRating;

  const ProductRatingScreen({
    super.key,
    required this.orderId,
    required this.productId,
    required this.productName,
    this.productImage,
    this.initialRating,
  });

  @override
  State<ProductRatingScreen> createState() => _ProductRatingScreenState();
}

class _ProductRatingScreenState extends State<ProductRatingScreen>
    with SingleTickerProviderStateMixin {
  double _ratingValue = 0.5; // 0.0 to 1.0 (Mapped to 1-5)
  late AnimationController _controller;
  late Animation<double> _eyeBlinkAnimation;
  final TextEditingController _reviewController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void initState() {
    super.initState();

    // Initialize with initialRating if provided
    if (widget.initialRating != null) {
      // Map 1.0-5.0 back to 0.0-1.0
      // Formula: val = (rating - 1.0) / 4.0
      _ratingValue = ((widget.initialRating! - 1.0) / 4.0).clamp(0.0, 1.0);
    }

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3000),
    )..repeat(reverse: true);

    // Random blink effect
    _eyeBlinkAnimation = TweenSequence<double>([
      TweenSequenceItem(tween: ConstantTween(1.0), weight: 95),
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 0.1), weight: 2.5),
      TweenSequenceItem(tween: Tween(begin: 0.1, end: 1.0), weight: 2.5),
    ]).animate(_controller);
  }

  @override
  void dispose() {
    _controller.dispose();
    _reviewController.dispose();
    super.dispose();
  }

  Color _getBackgroundColor(double value) {
    if (value < 0.5) {
      return Color.lerp(
        const Color(0xFFFFC0CB),
        const Color(0xFFF5F5DC),
        value * 2,
      )!; // Pink to Beige
    } else {
      return Color.lerp(
        const Color(0xFFF5F5DC),
        const Color(0xFF90EE90),
        (value - 0.5) * 2,
      )!; // Beige to Green
    }
  }

  String _getMoodText(double value) {
    if (value <= 0.2) return "Hideous";
    if (value <= 0.4) return "Bad";
    if (value <= 0.6) return "Okay";
    if (value <= 0.8) return "Good";
    return "Amazing";
  }

  double _getApiRating(double value) {
    // Map 0.0-1.0 to 1.0-5.0
    return 1.0 + (value * 4.0);
  }

  Future<void> _submitRating() async {
    setState(() {
      _isSubmitting = true;
    });

    try {
      final rating = _getApiRating(_ratingValue);
      final review = _reviewController.text.trim();

      await ApiService.post(
        '/review-product/',
        body: {
          "order_id": widget.orderId,
          "product_id": widget.productId,
          "rating": rating,
          "review": review,
        },
        useBearerToken: true,
      );

      if (!mounted) return;

      // Return success
      Navigator.pop(context, rating);
    } catch (e) {
      if (!mounted) return;

      String errorMessage = "Failed to submit review";
      if (e is ApiException &&
          e.response != null &&
          e.response!['data'] is Map &&
          e.response!['data']['response'] != null) {
        errorMessage = e.response!['data']['response'].toString();
      }

      if (errorMessage.contains("Review already submitted")) {
        // Treat as success if already submitted
        Navigator.pop(context, _getApiRating(_ratingValue));
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(errorMessage), backgroundColor: Colors.red),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bgColor = _getBackgroundColor(_ratingValue);
    const textColor = Colors.black87;

    return Scaffold(
      backgroundColor: bgColor,
      resizeToAvoidBottomInset: true,
      body: SafeArea(
        child: Stack(
          children: [
            SingleChildScrollView(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  minHeight:
                      MediaQuery.of(context).size.height -
                      MediaQuery.of(context).padding.top,
                ),
                child: IntrinsicHeight(
                  child: Column(
                    children: [
                      const SizedBox(height: 60), // Space for close button
                      const Spacer(flex: 1),

                      // Product Name Header
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 30),
                        child: Text(
                          "How was\n${widget.productName}?",
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            fontSize: 28, // Slightly smaller for product names
                            fontWeight: FontWeight.bold,
                            height: 1.2,
                            color: textColor,
                          ),
                          maxLines: 3,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),

                      const SizedBox(height: 20),
                      Text(
                        _getMoodText(_ratingValue),
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          color: textColor.withOpacity(0.7),
                        ),
                      ),
                      const Spacer(flex: 1),
                      // The Face
                      AnimatedBuilder(
                        animation: _eyeBlinkAnimation,
                        builder: (context, child) {
                          return SizedBox(
                            width: 250,
                            height: 250,
                            child: CustomPaint(
                              painter: _FacePainter(
                                rating: _ratingValue,
                                eyeOpenness: _eyeBlinkAnimation.value,
                              ),
                            ),
                          );
                        },
                      ),
                      const Spacer(flex: 1),
                      // Slider
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: SliderTheme(
                          data: SliderTheme.of(context).copyWith(
                            trackHeight: 2,
                            activeTrackColor: Colors.black12,
                            inactiveTrackColor: Colors.black12,
                            thumbColor: Colors.black,
                            thumbShape: const RoundSliderThumbShape(
                              enabledThumbRadius: 12,
                              elevation: 5,
                            ),
                            overlayColor: Colors.black.withOpacity(0.1),
                          ),
                          child: Slider(
                            value: _ratingValue,
                            onChanged: (val) {
                              setState(() {
                                _ratingValue = val;
                              });
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 20),
                      // Review Text Field
                      // Minimal Review Input
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 40),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(20),
                          child: BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
                            child: TextField(
                              controller: _reviewController,
                              decoration: InputDecoration(
                                hintText: "Write a review (optional)...",
                                hintStyle: TextStyle(
                                  color: Colors.black.withOpacity(0.4),
                                  fontSize: 15,
                                ),
                                filled: true,
                                fillColor: Colors.white.withOpacity(0.3),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 16,
                                ),
                                enabledBorder: InputBorder.none,
                                focusedBorder: InputBorder.none,
                              ),
                              maxLines: 2,
                              minLines: 1,
                              style: const TextStyle(
                                color: Colors.black87,
                                fontSize: 16,
                              ),
                              textCapitalization: TextCapitalization.sentences,
                            ),
                          ),
                        ),
                      ),
                      const Spacer(flex: 2),
                      // Done Button
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 40,
                          vertical: 20,
                        ),
                        child: SizedBox(
                          width: double.infinity,
                          height: 56,
                          child: ElevatedButton(
                            onPressed: _isSubmitting ? null : _submitRating,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.black,
                              foregroundColor: Colors.white,
                              disabledBackgroundColor: Colors.black54,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: _isSubmitting
                                ? const SizedBox(
                                    width: 24,
                                    height: 24,
                                    child: CircularProgressIndicator(
                                      color: Colors.white,
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Text(
                                    "Rate Product",
                                    style: TextStyle(
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            // Floating Close Button
            // Floating Back Button
            Positioned(
              left: 20,
              top: 20,
              child: Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: Colors.black.withOpacity(0.1),
                    width: 1,
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      child: const Icon(
                        Icons.arrow_back_ios_new_rounded,
                        size: 18,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FacePainter extends CustomPainter {
  final double rating;
  final double eyeOpenness;

  _FacePainter({required this.rating, required this.eyeOpenness});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.black
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4.0
      ..strokeCap = StrokeCap.round;

    final fillPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    // Center point
    final center = Offset(size.width / 2, size.height / 2);

    final eyeOffset = size.width * 0.2;
    final eyeY = size.height * 0.35;
    const eyeRadius = 15.0;
    final pupilOffset = (rating - 0.5) * 10;
    final pupilPaint = Paint()..color = Colors.black;

    // Left Eye
    canvas.save();
    canvas.translate(center.dx - eyeOffset, eyeY);
    canvas.scale(1.0, eyeOpenness);
    canvas.drawCircle(Offset.zero, eyeRadius * 1.5, fillPaint);
    canvas.drawCircle(Offset.zero, eyeRadius * 1.5, paint);
    canvas.drawCircle(Offset(pupilOffset, 0), 4, pupilPaint);
    canvas.restore();

    // Right Eye
    canvas.save();
    canvas.translate(center.dx + eyeOffset, eyeY);
    canvas.scale(1.0, eyeOpenness);
    canvas.drawCircle(Offset.zero, eyeRadius * 1.5, fillPaint);
    canvas.drawCircle(Offset.zero, eyeRadius * 1.5, paint);
    canvas.drawCircle(Offset(pupilOffset, 0), 4, pupilPaint);
    canvas.restore();

    // Eyebrows
    final browY = eyeY - 40;
    const browWidth = 40.0;
    final browAngle = (0.5 - rating) * 0.8;

    canvas.save();
    canvas.translate(center.dx - eyeOffset, browY);
    canvas.rotate(-browAngle);
    canvas.drawLine(const Offset(-browWidth / 2, 0), const Offset(browWidth / 2, 0), paint);
    canvas.restore();

    canvas.save();
    canvas.translate(center.dx + eyeOffset, browY);
    canvas.rotate(browAngle);
    canvas.drawLine(const Offset(-browWidth / 2, 0), const Offset(browWidth / 2, 0), paint);
    canvas.restore();

    // Mouth
    final mouthY = size.height * 0.65;
    final mouthWidth = size.width * 0.4;
    const maxCurve = 60.0;
    final curveValue = (rating - 0.5) * 2 * maxCurve;

    final path = Path();
    path.moveTo(center.dx - mouthWidth / 2, mouthY);
    path.quadraticBezierTo(
      center.dx,
      mouthY + curveValue,
      center.dx + mouthWidth / 2,
      mouthY,
    );

    paint.strokeWidth = 5.0;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _FacePainter oldDelegate) {
    return oldDelegate.rating != rating ||
        oldDelegate.eyeOpenness != eyeOpenness;
  }
}
