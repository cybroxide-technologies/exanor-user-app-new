import 'package:flutter/material.dart';

class TicketPainter extends CustomPainter {
  final Color color;
  final Color borderColor;
  final double borderWidth;
  final double holeRadius;
  final double cornerRadius;
  final double splitX;

  TicketPainter({
    required this.color,
    required this.borderColor,
    this.borderWidth = 1.0,
    required this.holeRadius,
    required this.cornerRadius,
    required this.splitX,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.fill;

    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    final path = Path();
    // Start top left
    path.moveTo(cornerRadius, 0);
    // Top line to notch
    path.lineTo(splitX - holeRadius, 0);
    // Top Notch
    path.arcToPoint(
      Offset(splitX + holeRadius, 0),
      radius: Radius.circular(holeRadius),
      clockwise: false,
    );
    // Top line to right
    path.lineTo(size.width - cornerRadius, 0);
    // Top right corner
    path.arcToPoint(
      Offset(size.width, cornerRadius),
      radius: Radius.circular(cornerRadius),
    );
    // Right line
    path.lineTo(size.width, size.height - cornerRadius);
    // Bottom right corner
    path.arcToPoint(
      Offset(size.width - cornerRadius, size.height),
      radius: Radius.circular(cornerRadius),
    );
    // Bottom line to notch
    path.lineTo(splitX + holeRadius, size.height);
    // Bottom Notch
    path.arcToPoint(
      Offset(splitX - holeRadius, size.height),
      radius: Radius.circular(holeRadius),
      clockwise: false,
    );
    // Bottom line to left
    path.lineTo(cornerRadius, size.height);
    // Bottom left corner
    path.arcToPoint(
      Offset(0, size.height - cornerRadius),
      radius: Radius.circular(cornerRadius),
    );
    // Left line
    path.lineTo(0, cornerRadius);
    // Top left corner
    path.arcToPoint(
      Offset(cornerRadius, 0),
      radius: Radius.circular(cornerRadius),
    );

    path.close();

    // Draw Shadow
    canvas.drawShadow(path, Colors.black.withOpacity(0.08), 8.0, true);

    canvas.drawPath(path, paint);
    canvas.drawPath(path, borderPaint);

    // Draw Dashed Line
    final dashPaint = Paint()
      ..color = borderColor.withOpacity(0.5)
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    double dashHeight = 4;
    double dashSpace = 4;
    double startY = holeRadius + 4;
    double endY = size.height - holeRadius - 4;

    double currentY = startY;
    while (currentY < endY) {
      canvas.drawLine(
        Offset(splitX, currentY),
        Offset(splitX, currentY + dashHeight),
        dashPaint,
      );
      currentY += dashHeight + dashSpace;
    }
  }

  @override
  bool shouldRepaint(covariant TicketPainter oldDelegate) {
    return oldDelegate.color != color ||
        oldDelegate.borderColor != borderColor ||
        oldDelegate.splitX != splitX;
  }
}
