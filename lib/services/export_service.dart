import 'dart:io';
import 'dart:math' as math;

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:path_provider/path_provider.dart';

import '../audio/audio_engine.dart';
import '../models/project.dart';
import '../visualizer/frame_renderer.dart';

/// Real MP4 export.
///
/// Pipeline (no fake progress — every percentage point is a rendered frame):
/// 1. Render every frame of the song offscreen with the real visualizer
///    painter, in chunks of 240 frames.
/// 2. Encode each chunk to an H.264 segment with FFmpeg.
/// 3. Concatenate the segments and mux the ORIGINAL audio track in, so the
///    exported video keeps the complete song in sync with the visuals.
///
/// Output: H.264 + AAC MP4 at the chosen aspect, resolution and FPS.
class ExportService {
  static const int _chunkFrames = 240;

  static Future<String> export({
    required VisualizerProject project,
    required AudioAnalysis analysis,
    required dynamic backgroundImage,
    required ExportAspect aspect,
    required int longEdge, // 720 or 1080
    required int fps, // 30 or 60
    required void Function(double progress, String stage) onProgress,
  }) async {
    final (width, height) = aspect.sizeFor(longEdge);
    final totalFrames = (analysis.durationSeconds * fps).ceil();
    final tmp = await getTemporaryDirectory();
    final workDir = Directory(
      '${tmp.path}/export_${DateTime.now().millisecondsSinceEpoch}',
    );
    await workDir.create(recursive: true);
    final docs = await getApplicationDocumentsDirectory();
    final exportsDir = Directory('${docs.path}/exports');
    await exportsDir.create(recursive: true);
    final safeTitle =
        project.title.replaceAll(RegExp(r'[^A-Za-z0-9_-]'), '_');
    final outPath =
        '${exportsDir.path}/${safeTitle}_${DateTime.now().millisecondsSinceEpoch}.mp4';

    try {
      final segments = <String>[];
      int rendered = 0;
      for (int start = 0; start < totalFrames; start += _chunkFrames) {
        final end = math.min(start + _chunkFrames, totalFrames);
        final chunkDir = Directory('${workDir.path}/chunk_$start');
        await chunkDir.create();
        for (int f = start; f < end; f++) {
          final t = f / fps;
          final frame = analysis.frameAt(t);
          final jpg = await renderFrame(
            width: width,
            height: height,
            bands: frame.bands,
            beat: frame.beat,
            template: project.template,
            settings: project.settings,
            background: backgroundImage,
            time: t,
            title: project.title,
            artist: project.artist,
          );
          final idx = (f - start + 1).toString().padLeft(6, '0');
          await File('${chunkDir.path}/frame_$idx.jpg').writeAsBytes(jpg);
          rendered++;
          if (rendered % 10 == 0) {
            onProgress(
              0.85 * rendered / totalFrames,
              'Rendering frames $rendered / $totalFrames…',
            );
            await Future<void>.delayed(Duration.zero);
          }
        }
        final segPath = '${workDir.path}/seg_$start.mp4';
        final segSession = await FFmpegKit.execute(
          '-y -v error -framerate $fps -i "${chunkDir.path}/frame_%06d.jpg" '
          '-c:v libx264 -pix_fmt yuv420p -r $fps "$segPath"',
        );
        final segRc = await segSession.getReturnCode();
        if (!ReturnCode.isSuccess(segRc)) {
          throw Exception('Video encoding failed at frame $start.');
        }
        segments.add(segPath);
        await chunkDir.delete(recursive: true);
      }

      onProgress(0.88, 'Joining video and adding audio…');
      final listFile = File('${workDir.path}/concat.txt');
      await listFile.writeAsString(
        segments.map((s) => "file '$s'").join('\n'),
      );
      final muxSession = await FFmpegKit.execute(
        '-y -v error -f concat -safe 0 -i "${listFile.path}" '
        '-i "${project.audioPath}" -map 0:v -map 1:a '
        '-c:v copy -c:a aac -shortest "$outPath"',
      );
      final muxRc = await muxSession.getReturnCode();
      if (!ReturnCode.isSuccess(muxRc)) {
        throw Exception('Final video mux failed. The audio file may be '
            'in an unsupported format.');
      }
      onProgress(1.0, 'Done');
      return outPath;
    } finally {
      await workDir.delete(recursive: true).catchError((_) => workDir);
    }
  }
}
