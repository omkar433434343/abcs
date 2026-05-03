import 'package:flutter/material.dart';

class AppLogoMark extends StatelessWidget {
  final double size;
  const AppLogoMark({super.key, this.size = 28});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _LogoPainter(),
      ),
    );
  }
}

class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final orange = Paint()..color = const Color(0xFFFF8A3D);
    final green = Paint()..color = const Color(0xFF00C56E);

    final top = Path()
      ..moveTo(size.width * 0.55, size.height * 0.12)
      ..lineTo(size.width * 0.92, size.height * 0.04)
      ..lineTo(size.width * 0.38, size.height * 0.58)
      ..close();

    final bottom = Path()
      ..moveTo(size.width * 0.08, size.height * 0.96)
      ..lineTo(size.width * 0.70, size.height * 0.70)
      ..lineTo(size.width * 0.84, size.height * 0.28)
      ..close();

    canvas.drawPath(top, orange);
    canvas.drawPath(bottom, green);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
