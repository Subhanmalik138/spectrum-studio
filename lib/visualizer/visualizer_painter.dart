import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/project.dart';

/// Minimal 3D vector with rotation + perspective projection. All six
/// templates are drawn from real 3D coordinates projected onto the canvas —
/// this is genuine 3D rendering, not a flat 2D imitation.
class Vec3 {
  double x, y, z;
  Vec3(this.x, this.y, this.z);

  Vec3 rotateX(double a) {
    final c = math.cos(a), s = math.sin(a);
    return Vec3(x, y * c - z * s, y * s + z * c);
  }

  Vec3 rotateY(double a) {
    final c = math.cos(a), s = math.sin(a);
    return Vec3(x * c + z * s, y, -x * s + z * c);
  }

  Vec3 rotateZ(double a) {
    final c = math.cos(a), s = math.sin(a);
    return Vec3(x * c - y * s, x * s + y * c, z);
  }
}

Offset _project(Vec3 v, Offset center, double scale) {
  // Perspective divide: objects further away (larger z) shrink.
  final f = 520 / (520 + v.z * 0.55);
  return Offset(center.dx + v.x * scale * f, center.dy + v.y * scale * f);
}

/// Deterministic hash-based pseudo-random in [0,1) for a given index —
/// stable across frames so particles don't flicker randomly.
double _hash01(int i) {
  var h = (i + 1) * 2654435761;
  h = (h ^ (h >> 13)) & 0xFFFFFFFF;
  h = (h * 2246822519) & 0xFFFFFFFF;
  return ((h ^ (h >> 16)) & 0xFFFFFFFF) / 4294967295.0;
}

class VisualizerPainter extends CustomPainter {
  final List<double> bands; // 64 real FFT band magnitudes, 0..1
  final double beat; // 0..1 beat pulse
  final VisualizerTemplate template;
  final VisualizerSettings settings;
  final ui.Image? background;
  final double time; // seconds, drives rotation/animation
  final String title;
  final String artist;

  VisualizerPainter({
    required this.bands,
    required this.beat,
    required this.template,
    required this.settings,
    required this.background,
    required this.time,
    required this.title,
    required this.artist,
  });

  double _band(int i) {
    if (bands.isEmpty) return 0;
    return bands[i % bands.length].clamp(0.0, 1.0);
  }

  double get _bass {
    if (bands.isEmpty) return 0;
    double s = 0;
    for (int i = 0; i < 10; i++) {
      s += bands[i];
    }
    return (s / 10).clamp(0.0, 1.0);
  }

  Paint _paint(Color c, {double width = 2, double glowSigma = 0}) {
    final p = Paint()
      ..color = c
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    if (glowSigma > 0.5) {
      p.maskFilter = MaskFilter.blur(BlurStyle.normal, glowSigma);
    }
    return p;
  }

  Paint _fill(Color c, {double glowSigma = 0}) {
    final p = Paint()..color = c;
    if (glowSigma > 0.5) {
      p.maskFilter = MaskFilter.blur(BlurStyle.normal, glowSigma);
    }
    return p;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final base = settings.colorValue;
    final center = Offset(
      size.width / 2 + settings.posX * size.width * 0.28,
      size.height / 2 + settings.posY * size.height * 0.28,
    );
    final unit = math.min(size.width, size.height) * 0.32 * settings.size;

    _paintBackground(canvas, size);

    final glowSigma = settings.glow * 16;
    switch (template) {
      case VisualizerTemplate.circularSpectrum:
        _circularSpectrum(canvas, center, unit, base, glowSigma);
        break;
      case VisualizerTemplate.rotatingBars:
        _rotatingBars(canvas, center, unit, base, glowSigma);
        break;
      case VisualizerTemplate.neonRings:
        _neonRings(canvas, center, unit, base, glowSigma);
        break;
      case VisualizerTemplate.glowingSphere:
        _glowingSphere(canvas, center, unit, base, glowSigma);
        break;
      case VisualizerTemplate.particles:
        _particles(canvas, center, unit, base, glowSigma);
        break;
      case VisualizerTemplate.waveformTunnel:
        _waveformTunnel(canvas, center, unit, base, glowSigma);
        break;
    }

    if (settings.showTitle) _paintText(canvas, size);
  }

  void _paintBackground(Canvas canvas, Size size) {
    // Fallback gradient when no background image was chosen.
    final rect = Offset.zero & size;
    if (background == null) {
      const grad = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFF14101F), Color(0xFF050308)],
      );
      canvas.drawRect(rect, Paint()..shader = grad.createShader(rect));
      return;
    }
    final img = background!;
    final imgSize =
        Size(img.width.toDouble(), img.height.toDouble());
    final scale = math.max(
      size.width / imgSize.width,
      size.height / imgSize.height,
    );
    final drawW = imgSize.width * scale;
    final drawH = imgSize.height * scale;
    final dst = Rect.fromLTWH(
      (size.width - drawW) / 2,
      (size.height - drawH) / 2,
      drawW,
      drawH,
    );
    final src = Rect.fromLTWH(0, 0, imgSize.width, imgSize.height);
    if (settings.backgroundBlur > 0.02) {
      canvas.saveLayer(
        rect,
        Paint()
          ..imageFilter = ui.ImageFilter.blur(
            sigmaX: settings.backgroundBlur * 28,
            sigmaY: settings.backgroundBlur * 28,
          ),
      );
      canvas.drawImageRect(img, src, dst, Paint());
      canvas.restore();
    } else {
      canvas.drawImageRect(img, src, dst, Paint());
    }
    canvas.drawRect(
      rect,
      Paint()..color = Colors.black.withOpacity(0.38),
    );
  }

  void _paintText(Canvas canvas, Size size) {
    if (title.isEmpty && artist.isEmpty) return;
    final y = switch (settings.textPlacement) {
      TextPlacement.top => size.height * 0.06,
      TextPlacement.center => size.height * 0.5,
      TextPlacement.bottom => size.height * 0.86,
    };
    final titlePainter = TextPainter(
      text: TextSpan(
        text: title,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 34,
          fontWeight: FontWeight.bold,
          shadows: [Shadow(color: Colors.black87, blurRadius: 12)],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width * 0.9);
    final artistPainter = TextPainter(
      text: TextSpan(
        text: artist,
        style: TextStyle(
          color: Colors.white.withOpacity(0.85),
          fontSize: 20,
          shadows: const [Shadow(color: Colors.black87, blurRadius: 10)],
        ),
      ),
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: size.width * 0.9);
    double top = y;
    if (settings.textPlacement == TextPlacement.center) {
      top = y - (titlePainter.height + artistPainter.height + 6) / 2;
    }
    titlePainter.paint(
      canvas,
      Offset((size.width - titlePainter.width) / 2, top),
    );
    artistPainter.paint(
      canvas,
      Offset((size.width - artistPainter.width) / 2, top + titlePainter.height + 6),
    );
  }

  void _glowLine(
    Canvas canvas,
    Offset a,
    Offset b,
    Color c,
    double width,
    double glowSigma,
  ) {
    if (glowSigma > 0.5) {
      canvas.drawLine(a, b, _paint(c.withOpacity(0.55), width: width + 3, glowSigma: glowSigma));
    }
    canvas.drawLine(a, b, _paint(c, width: width));
  }

  // ---- Templates -------------------------------------------------------

  void _circularSpectrum(
    Canvas canvas,
    Offset center,
    double unit,
    Color base,
    double glowSigma,
  ) {
    const n = 64;
    const tilt = 0.55;
    final rot = time * 0.25;
    final radius = unit * 0.85;
    for (int i = 0; i < n; i++) {
      final a = (i / n) * math.pi * 2 + rot;
      final v = _band(i);
      final r0 = radius;
      final r1 = radius + unit * 0.12 + v * unit * 1.15 + beat * unit * 0.08;
      final p0 = Vec3(math.cos(a) * r0, math.sin(a) * r0, 0)
          .rotateX(tilt)
          .rotateY(rot * 0.3);
      final p1 = Vec3(math.cos(a) * r1, math.sin(a) * r1, 0)
          .rotateX(tilt)
          .rotateY(rot * 0.3);
      final o0 = _project(p0, center, 1);
      final o1 = _project(p1, center, 1);
      final c = Color.lerp(base, Colors.white, v * 0.7)!;
      _glowLine(canvas, o0, o1, c, 3.5, glowSigma);
    }
    // Inner ring.
    final ring = Path();
    for (int i = 0; i <= 72; i++) {
      final a = (i / 72) * math.pi * 2;
      final p = Vec3(math.cos(a) * radius, math.sin(a) * radius, 0)
          .rotateX(tilt)
          .rotateY(rot * 0.3);
      final o = _project(p, center, 1);
      if (i == 0) {
        ring.moveTo(o.dx, o.dy);
      } else {
        ring.lineTo(o.dx, o.dy);
      }
    }
    canvas.drawPath(ring, _paint(base.withOpacity(0.8), width: 2, glowSigma: glowSigma));
  }

  void _rotatingBars(
    Canvas canvas,
    Offset center,
    double unit,
    Color base,
    double glowSigma,
  ) {
    const n = 48;
    final rot = time * 0.6;
    final radius = unit * 0.95;
    final items = <(double, Offset, Offset)>[];
    for (int i = 0; i < n; i++) {
      final a = (i / n) * math.pi * 2 + rot;
      final v = _band(i);
      final h = unit * 0.25 + v * unit * 1.3 + beat * unit * 0.1;
      final b = Vec3(math.cos(a) * radius, -unit * 0.55, math.sin(a) * radius)
          .rotateY(rot * 0.25);
      final t = Vec3(math.cos(a) * radius, -unit * 0.55 - h, math.sin(a) * radius)
          .rotateY(rot * 0.25);
      items.add((b.z, _project(b, center, 1), _project(t, center, 1)));
    }
    items.sort((x, y) => x.$1.compareTo(y.$1)); // far first
    for (int i = 0; i < items.length; i++) {
      final v = _band(i);
      final c = Color.lerp(base, Colors.white, v * 0.6)!;
      _glowLine(canvas, items[i].$2, items[i].$3, c, 4, glowSigma);
    }
  }

  void _neonRings(
    Canvas canvas,
    Offset center,
    double unit,
    Color base,
    double glowSigma,
  ) {
    for (int r = 0; r < 3; r++) {
      final pulse = (beat * (1 - r * 0.25)).clamp(0.0, 1.0);
      final radius = unit * (0.55 + r * 0.32) * (1 + pulse * 0.22 + _bass * 0.12);
      final tilt = 0.5 + r * 0.12;
      final path = Path();
      for (int i = 0; i <= 90; i++) {
        final a = (i / 90) * math.pi * 2 + time * (0.3 + r * 0.15);
        final wobble = 1 + _band((i + r * 12) % 64) * 0.18;
        final p = Vec3(math.cos(a) * radius * wobble, math.sin(a) * radius * wobble, 0)
            .rotateX(tilt)
            .rotateY(time * 0.2);
        final o = _project(p, center, 1);
        if (i == 0) {
          path.moveTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      final c = Color.lerp(base, Colors.white, 0.25 + r * 0.2)!;
      canvas.drawPath(
        path,
        _paint(c.withOpacity(0.9), width: 3, glowSigma: glowSigma),
      );
      canvas.drawPath(path, _paint(Colors.white.withOpacity(0.7), width: 1.2));
    }
    // Beat core dot.
    final coreR = unit * 0.1 * (1 + beat * 0.9);
    canvas.drawCircle(center, coreR, _fill(Colors.white, glowSigma: glowSigma));
    canvas.drawCircle(center, coreR * 0.55, _fill(base));
  }

  void _glowingSphere(
    Canvas canvas,
    Offset center,
    double unit,
    Color base,
    double glowSigma,
  ) {
    const count = 520;
    final golden = math.pi * (3 - math.sqrt(5));
    final items = <(double, Offset, double, Color)>[];
    for (int i = 0; i < count; i++) {
      final y = 1 - (i / (count - 1)) * 2;
      final rad = math.sqrt(math.max(0, 1 - y * y));
      final theta = golden * i;
      final band = _band(i % 64);
      final r = unit * (0.85 + band * 0.45 + beat * 0.12);
      final p = Vec3(math.cos(theta) * rad * r, y * r, math.sin(theta) * rad * r)
          .rotateY(time * 0.5)
          .rotateX(0.35);
      final o = _project(p, center, 1);
      final depth = (p.z / (unit * 1.5) + 1) / 2; // 0 far, 1 near
      final c = Color.lerp(base.withOpacity(0.45), Colors.white, depth * 0.8)!;
      items.add((p.z, o, 1.2 + depth * 3.2 + band * 2.5, c));
    }
    items.sort((a, b) => a.$1.compareTo(b.$1));
    for (final it in items) {
      canvas.drawCircle(it.$2, it.$3, _fill(it.$4, glowSigma: glowSigma * 0.5));
    }
  }

  void _particles(
    Canvas canvas,
    Offset center,
    double unit,
    Color base,
    double glowSigma,
  ) {
    const count = 700;
    final items = <(double, Offset, double, Color)>[];
    for (int i = 0; i < count; i++) {
      final h1 = _hash01(i * 3);
      final h2 = _hash01(i * 3 + 1);
      final h3 = _hash01(i * 3 + 2);
      final band = _band(i % 64);
      // Particles drift outward with the music's energy.
      final spread = unit * (0.4 + band * 1.3 + beat * 0.25);
      final theta = h1 * math.pi * 2 + time * (0.1 + h2 * 0.25);
      final phi = math.acos(2 * h2 - 1);
      final r = spread * (0.35 + h3 * 0.65);
      final p = Vec3(
        r * math.sin(phi) * math.cos(theta),
        r * math.cos(phi) * 0.8,
        r * math.sin(phi) * math.sin(theta),
      ).rotateY(time * 0.35);
      final o = _project(p, center, 1);
      final depth = (p.z / (unit * 2) + 1) / 2;
      final c = Color.lerp(base, Colors.white, depth * 0.7 + band * 0.2)!;
      items.add((p.z, o, 1 + depth * 2.5 + band * 2, c));
    }
    items.sort((a, b) => a.$1.compareTo(b.$1));
    for (final it in items) {
      canvas.drawCircle(it.$2, it.$3, _fill(it.$4, glowSigma: glowSigma * 0.4));
    }
  }

  void _waveformTunnel(
    Canvas canvas,
    Offset center,
    double unit,
    Color base,
    double glowSigma,
  ) {
    const rings = 14;
    const depth = 900.0;
    final speed = 260 + beat * 260;
    for (int r = rings - 1; r >= 0; r--) {
      double z = -depth + ((r * (depth / rings) + time * speed) % depth);
      final radius = unit * 0.55;
      final path = Path();
      for (int i = 0; i <= 64; i++) {
        final a = (i / 64) * math.pi * 2;
        final wobble = 1 + _band(i % 64) * 0.35;
        final p = Vec3(
          math.cos(a) * radius * wobble,
          math.sin(a) * radius * wobble,
          z,
        );
        final o = _project(p, center, 1);
        if (i == 0) {
          path.moveTo(o.dx, o.dy);
        } else {
          path.lineTo(o.dx, o.dy);
        }
      }
      // Nearer rings are brighter and thicker.
      final near = 1 - ((z + depth) / depth).clamp(0.0, 1.0);
      final c = Color.lerp(base.withOpacity(0.25), Colors.white, near * 0.8)!;
      canvas.drawPath(
        path,
        _paint(c, width: 1 + near * 2.5, glowSigma: glowSigma * near),
      );
    }
  }

  @override
  bool shouldRepaint(covariant VisualizerPainter oldDelegate) =>
      oldDelegate.bands != bands ||
      oldDelegate.beat != beat ||
      oldDelegate.time != time ||
      oldDelegate.template != template ||
      oldDelegate.settings != settings ||
      oldDelegate.background != background ||
      oldDelegate.title != title ||
      oldDelegate.artist != artist;
}
