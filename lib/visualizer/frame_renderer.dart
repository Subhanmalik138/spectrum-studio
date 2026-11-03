import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:image/image.dart' as img;

import '../models/project.dart';
import 'visualizer_painter.dart';

/// Loads a background file into a dart:ui image for canvas painting.
Future<ui.Image?> loadBackgroundImage(String? path) async {
  if (path == null) return null;
  final file = File(path);
  if (!await file.exists()) return null;
  final bytes = await file.readAsBytes();
  final codec = await ui.instantiateImageCodec(bytes);
  final frame = await codec.getNextFrame();
  return frame.image;
}

/// Blurs [src] ONCE into a new image at export resolution. The exporter
/// calls this a single time and passes the result to every frame, instead
/// of paying for a full-screen saveLayer blur on each of thousands of
/// frames — one of the biggest export speed wins.
Future<ui.Image?> blurBackgroundOnce({
  required ui.Image src,
  required int width,
  required int height,
  required double blur, // 0..1 setting
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(
    recorder,
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
  );
  final imgSize = ui.Size(src.width.toDouble(), src.height.toDouble());
  final scale = width / imgSize.width > height / imgSize.height
      ? width / imgSize.width
      : height / imgSize.height;
  final drawW = imgSize.width * scale;
  final drawH = imgSize.height * scale;
  final dst = ui.Rect.fromLTWH(
    (width - drawW) / 2,
    (height - drawH) / 2,
    drawW,
    drawH,
  );
  final rect = ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble());
  canvas.saveLayer(
    rect,
    ui.Paint()
      ..imageFilter = ui.ImageFilter.blur(
        sigmaX: blur * 28,
        sigmaY: blur * 28,
      ),
  );
  canvas.drawImageRect(
    src,
    ui.Rect.fromLTWH(0, 0, imgSize.width, imgSize.height),
    dst,
    ui.Paint(),
  );
  canvas.restore();
  final picture = recorder.endRecording();
  return picture.toImage(width, height);
}

/// Renders ONE video frame offscreen with the exact same painter the
/// preview uses, then JPEG-encodes it. The exporter calls this for every
/// frame of the song, so the exported MP4 contains the real visualizer —
/// not a screen recording, not a placeholder.
Future<Uint8List> renderFrame({
  required int width,
  required int height,
  required List<double> bands,
  required double beat,
  required VisualizerTemplate template,
  required VisualizerSettings settings,
  required ui.Image? background,
  required double time,
  required String title,
  required String artist,
  bool backgroundPreBlurred = false,
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = ui.Canvas(
    recorder,
    ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
  );
  VisualizerPainter(
    bands: bands,
    beat: beat,
    template: template,
    settings: settings,
    background: background,
    time: time,
    title: title,
    artist: artist,
    backgroundPreBlurred: backgroundPreBlurred,
  ).paint(canvas, ui.Size(width.toDouble(), height.toDouble()));
  final picture = recorder.endRecording();
  final image = await picture.toImage(width, height);
  final rgba = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  if (rgba == null) throw Exception('Frame rasterization failed.');
  final decoded = img.Image.fromBytes(
    width: width,
    height: height,
    bytes: Uint8List.fromList(rgba.buffer.asUint8List()).buffer,
    numChannels: 4,
  );
  // Quality 80: visually identical after H.264 re-encode, but smaller temp
  // files mean faster JPEG decode inside FFmpeg.
  return Uint8List.fromList(img.encodeJpg(decoded, quality: 80));
}
