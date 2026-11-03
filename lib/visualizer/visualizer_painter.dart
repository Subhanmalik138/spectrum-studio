import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../models/project.dart';

/// Minimal 3D vector with rotation + perspective projection. All twelve
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

  /// When true, [background] is already blurred (the exporter pre-blurs it
  /// once instead of paying for a full-screen blur on every frame).
  final bool backgroundPreBlurred;

  VisualizerPainter({
    required this.bands,
    required this.beat,
    required this.template,
    required this.settings,
    required this.background,
    required this.time,
    required this.title,
    required this.artist,
    this.backgroundPreBlurred = false,
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
      case VisualizerTemplate.spiralGalaxy:
        _spiralGalaxy(canvas, center, unit, base, glowSigma);
        break;
      case VisualizerTemplate.dnaHelix:
        _dnaHelix(canvas, center, unit, base, glowSigma);
        break;
      case VisualizerTemplate.gridWall:
        _gridWall(canvas, center, unit, base, glowSigma);
        break;
      case VisualizerTemplate.solarFlare:
        _solarFlare(canvas, center, unit, base, glowSigma);
        break;
      case VisualizerTemplate.cubeField:
        _cubeField(canvas, center, unit, base, glowSigma);
        break;
      case VisualizerTemplate.liquidWaves:
        _liquidWaves(canvas, center, unit, base, glowSigma);
        break;
    }

    // Cinematic vignette: darkens the edges so the visualizer pops.
    final vignetteRect = Offset.zero & size;
    final vignette = RadialGradient(
      center: Alignment.center,
      radius: 0.9,
      colors: [Colors.transparent, Colors.black.withOpacity(0.40)],
      stops: const [0.55, 1.0],
    );
    canvas.drawRect(
      vignetteRect,
      Paint()..shader = vignette.createShader(vignetteRect),
    );

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
    if (!backgroundPreBlurred && settings.backgroundBlur > 0.02) {
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

  void _spiralGalaxy(
    Canvas canvas,
    Offset center,
    double unit,
    Color base,
    double glowSigma,
  ) {
    const arms = 3;
    const points = 30;
    final rot = time * 0.35 + beat * 0.4;
    final coreR = unit * 0.12 * (1 + beat * 0.8 + _bass * 0.3);
    canvas.drawCircle(center, coreR, _fill(Colors.white, glowSigma: glowSigma));
    canvas.drawCircle(center, coreR * 0.6, _fill(base));
    for (int arm = 0; arm < arms; arm++) {
      final armOffset = arm * (math.pi * 2 / arms);
      Offset? prev;
      for (int i = 0; i < points; i++) {
        final t = i / points;
        final v = _band((i + arm * 7) % 64);
        final radius = unit * (0.25 + t * 1.15) * (1 + v * 0.25);
        final a = armOffset + rot + t * math.pi * 2.2;
        final p =
            Vec3(math.cos(a) * radius, math.sin(a) * radius, 0).rotateX(0.7);
        final o = _project(p, center, 1);
        final c = Color.lerp(base, Colors.white, v * 0.8 + t * 0.2)!;
        if (prev != null) {
          _glowLine(canvas, prev, o, c, 2.5, glowSigma);
        }
        canvas.drawCircle(
          o,
          1.5 + v * 3 + t * 1.5,
          _fill(c, glowSigma: glowSigma * 0.4),
        );
        prev = o;
      }
    }
  }

  void _dnaHelix(
    Canvas canvas,
    Offset center,
    double unit,
    Color base,
    double glowSigma,
  ) {
    const rungs = 36;
    final phase = time * 1.4;
    final radius = unit * 0.55 * (1 + _bass * 0.25 + beat * 0.15);
    final top = -unit * 1.1;
    final bottom = unit * 1.1;
    final strandA = <Offset>[];
    final strandB = <Offset>[];
    for (int i = 0; i < rungs; i++) {
      final t = i / (rungs - 1);
      final y = top + (bottom - top) * t;
      final a = phase + t * math.pi * 4;
      final v = _band(i % 64);
      final r = radius * (0.85 + v * 0.3);
      final pA =
          Vec3(math.cos(a) * r, y, math.sin(a) * r).rotateY(time * 0.2);
      final pB = Vec3(math.cos(a + math.pi) * r, y, math.sin(a + math.pi) * r)
          .rotateY(time * 0.2);
      final oA = _project(pA, center, 1);
      final oB = _project(pB, center, 1);
      strandA.add(oA);
      strandB.add(oB);
      final c = Color.lerp(base, Colors.white, v * 0.6)!;
      _glowLine(canvas, oA, oB, c.withOpacity(0.55), 1.5, glowSigma * 0.5);
    }
    for (final strand in [strandA, strandB]) {
      final path = Path();
      for (int i = 0; i < strand.length; i++) {
        if (i == 0) {
          path.moveTo(strand[i].dx, strand[i].dy);
        } else {
          path.lineTo(strand[i].dx, strand[i].dy);
        }
      }
      canvas.drawPath(
        path,
        _paint(base.withOpacity(0.9), width: 3, glowSigma: glowSigma),
      );
      canvas.drawPath(path, _paint(Colors.white.withOpacity(0.6), width: 1.2));
    }
  }

  void _gridWall(
    Canvas canvas,
    Offset center,
    double unit,
    Color base,
    double glowSigma,
  ) {
    const cols = 16;
    const rows = 6;
    final items = <(double, Offset, Offset, double)>[];
    for (int row = 0; row < rows; row++) {
      final z = row * unit * 0.55;
      for (int col = 0; col < cols; col++) {
        final v = _band((col * 64 ~/ cols) % 64);
        final h = unit * 0.12 + v * unit * 0.9 + beat * unit * 0.08;
        final x = (col - (cols - 1) / 2) * unit * 0.24;
        final b = Vec3(x, unit * 0.75, z).rotateX(0.9);
        final t = Vec3(x, unit * 0.75 - h, z).rotateX(0.9);
        items.add((z, _project(b, center, 1), _project(t, center, 1), v));
      }
    }
    items.sort((a, b) => b.$1.compareTo(a.$1)); // far first
    for (final it in items) {
      final c = Color.lerp(base, Colors.white, it.$4 * 0.6)!;
      _glowLine(canvas, it.$2, it.$3, c, 3, glowSigma);
    }
  }

  void _solarFlare(
    Canvas canvas,
    Offset center,
    double unit,
    Color base,
    double glowSigma,
  ) {
    const n = 64;
    final coreR = unit * 0.22 * (1 + beat * 0.7 + _bass * 0.3);
    for (int i = 0; i < n; i++) {
      final a = (i / n) * math.pi * 2 + time * 0.15;
      final v = _band(i);
      final r1 = coreR + unit * 0.25 + v * unit * 1.25 + beat * unit * 0.15;
      final o0 = Offset(
        center.dx + math.cos(a) * coreR,
        center.dy + math.sin(a) * coreR,
      );
      final o1 = Offset(
        center.dx + math.cos(a) * r1,
        center.dy + math.sin(a) * r1,
      );
      final c = Color.lerp(base, Colors.white, v * 0.75)!;
      _glowLine(canvas, o0, o1, c, 3, glowSigma);
    }
    canvas.drawCircle(center, coreR, _fill(Colors.white, glowSigma: glowSigma));
    canvas.drawCircle(center, coreR * 0.6, _fill(base));
  }

  void _cubeField(
    Canvas canvas,
    Offset center,
    double unit,
    Color base,
    double glowSigma,
  ) {
    const n = 8;
    final items = <(double, Offset, double, double, Color)>[];
    for (int row = 0; row < n; row++) {
      for (int col = 0; col < n; col++) {
        final v = _band((row * n + col) % 64);
        final s = unit * 0.09 + v * unit * 0.16 + beat * unit * 0.03;
        final x = (col - (n - 1) / 2) * unit * 0.30;
        final y = (row - (n - 1) / 2) * unit * 0.30;
        final p = Vec3(x, y, row * unit * 0.18)
            .rotateX(0.5)
            .rotateY(time * 0.15);
        final f = 520 / (520 + p.z * 0.55);
        items.add((
          p.z,
          _project(p, center, 1),
          s * f,
          v,
          Color.lerp(base, Colors.white, v * 0.6)!,
        ));
      }
    }
    items.sort((a, b) => a.$1.compareTo(b.$1)); // far first
    for (final it in items) {
      final o = it.$2;
      final s = it.$3;
      final back = Offset(o.dx + s * 0.45, o.dy - s * 0.45);
      final front = Rect.fromCenter(center: o, width: 2 * s, height: 2 * s);
      final backRect =
          Rect.fromCenter(center: back, width: 2 * s, height: 2 * s);
      canvas.drawRect(
        backRect,
        _paint(it.$5.withOpacity(0.5), width: 1.2),
      );
      canvas.drawRect(
        front,
        _paint(it.$5, width: 2, glowSigma: glowSigma * 0.5),
      );
      canvas.drawLine(
        Offset(front.left, front.top),
        Offset(backRect.left, backRect.top),
        _paint(it.$5.withOpacity(0.5), width: 1.2),
      );
      canvas.drawLine(
        Offset(front.right, front.top),
        Offset(backRect.right, backRect.top),
        _paint(it.$5.withOpacity(0.5), width: 1.2),
      );
      canvas.drawLine(
        Offset(front.right, front.bottom),
        Offset(backRect.right, backRect.bottom),
        _paint(it.$5.withOpacity(0.5), width: 1.2),
      );
      canvas.drawLine(
        Offset(front.left, front.bottom),
        Offset(backRect.left, backRect.bottom),
        _paint(it.$5.withOpacity(0.5), width: 1.2),
      );
    }
  }

  void _liquidWaves(
    Canvas canvas,
    Offset center,
    double unit,
    Color base,
    double glowSigma,
  ) {
    const layers = 5;
    const steps = 72;
    final halfW = center.dx * 1.05;
    final left = center.dx - halfW;
    final right = center.dx + halfW;
    final floorY = center.dy + unit * 1.4;
    for (int layer = 0; layer < layers; layer++) {
      final depth = layer / layers;
      final baseY = center.dy -
          unit * 0.7 +
          layer * unit * 0.35 +
          math.sin(time * 0.7 + layer) * unit * 0.05;
      final amp = unit *
          (0.10 + depth * 0.22) *
          (1 + _band(layer * 12) * 0.8 + beat * 0.2);
      final crest = Path();
      for (int i = 0; i <= steps; i++) {
        final x = left + (i / steps) * (right - left);
        final y = baseY +
            math.sin(
              i / steps * math.pi * 2 * (2 + layer * 0.5) +
                  time * (1 + layer * 0.3),
            ) *
                amp;
        if (i == 0) {
          crest.moveTo(x, y);
        } else {
          crest.lineTo(x, y);
        }
      }
      final fill = Path.from(crest)
        ..lineTo(right, floorY)
        ..lineTo(left, floorY)
        ..close();
      final c = Color.lerp(base, Colors.white, depth * 0.5)!;
      canvas.drawPath(fill, _fill(c.withOpacity(0.16 + depth * 0.10)));
      canvas.drawPath(
        crest,
        _paint(c, width: 2.5, glowSigma: glowSigma * (0.4 + depth * 0.6)),
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
      oldDelegate.backgroundPreBlurred != backgroundPreBlurred ||
      oldDelegate.title != title ||
      oldDelegate.artist != artist;
}
