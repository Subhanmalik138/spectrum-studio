import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffmpeg_kit_flutter_new/ffmpeg_kit.dart';
import 'package:ffmpeg_kit_flutter_new/return_code.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';

import 'fft.dart';

/// Full offline audio analysis of one song.
///
/// 1. Decodes the song to mono 22050 Hz float PCM with FFmpeg (any common
///    format: mp3, m4a, wav, flac, ogg...).
/// 2. Runs a real FFT on every window and stores log-spaced band magnitudes
///    plus a spectral-flux beat pulse per frame.
///
/// The preview and the exporter both read from these frames, so what you see
/// while previewing is exactly what lands in the exported video, in sync
/// with the original audio.
class AudioAnalysis {
  static const int sampleRate = 22050;
  static const int fftSize = 2048;
  static const int hop = 1024;
  static const int bandCount = 64;

  final List<List<double>> bandFrames;
  final List<double> beatFrames;
  final double durationSeconds;

  AudioAnalysis({
    required this.bandFrames,
    required this.beatFrames,
    required this.durationSeconds,
  });

  double get frameDuration => hop / sampleRate;

  /// Interpolated bands + beat at [seconds] into the song.
  ({List<double> bands, double beat}) frameAt(double seconds) {
    if (bandFrames.isEmpty) {
      return (bands: List.filled(bandCount, 0.0), beat: 0.0);
    }
    final pos = (seconds / frameDuration).clamp(0.0, bandFrames.length - 1.0);
    final i0 = pos.floor();
    final i1 = math.min(i0 + 1, bandFrames.length - 1);
    final t = pos - i0;
    final a = bandFrames[i0];
    final b = bandFrames[i1];
    final bands = List<double>.generate(
      bandCount,
      (k) => a[k] * (1 - t) + b[k] * t,
    );
    final beat = beatFrames[i0] * (1 - t) + beatFrames[i1] * t;
    return (bands: bands, beat: beat);
  }

  /// Decodes [audioPath] and analyzes it. [onProgress] reports 0..1 and is
  /// called with real progress (decode, then FFT passes) — never faked.
  static Future<AudioAnalysis> analyze(
    String audioPath, {
    void Function(double progress, String stage)? onProgress,
  }) async {
    final tmp = await getTemporaryDirectory();
    final pcmPath =
        '${tmp.path}/pcm_${DateTime.now().millisecondsSinceEpoch}.raw';
    onProgress?.call(0.02, 'Decoding audio…');
    final session = await FFmpegKit.execute(
      '-y -v error -i "$audioPath" -ac 1 -ar $sampleRate -f f32le "$pcmPath"',
    );
    final rc = await session.getReturnCode();
    if (!ReturnCode.isSuccess(rc)) {
      throw Exception('Could not decode this audio file. '
          'Try an MP3, M4A, WAV, FLAC or OGG file.');
    }
    final bytes = await File(pcmPath).readAsBytes();
    await File(pcmPath).delete().catchError((_) => File(pcmPath));
    final count = bytes.lengthInBytes ~/ 4;
    final bd = ByteData.sublistView(bytes);
    final pcm = List<double>.generate(
      count,
      (i) => bd.getFloat32(i * 4, Endian.little),
    );
    final duration = count / sampleRate;

    onProgress?.call(0.15, 'Analyzing frequencies…');
    final tracker = BeatTracker();
    final bandFrames = <List<double>>[];
    final beatFrames = <double>[];
    List<double>? prev;
    final totalWindows =
        ((count - fftSize) / hop).floor().clamp(0, 1 << 30) + 1;
    for (int w = 0, offset = 0;
        offset + fftSize <= count;
        w++, offset += hop) {
      final bands = Fft.bandsFromWindow(
        pcm,
        offset,
        fftSize,
        sampleRate,
        bandCount,
        previous: prev,
      );
      prev = bands;
      bandFrames.add(bands);
      beatFrames.add(tracker.update(bands));
      if (w % 200 == 0) {
        onProgress?.call(
          0.15 + 0.80 * (w / totalWindows),
          'Analyzing frequencies…',
        );
      }
    }
    if (bandFrames.isEmpty) {
      throw Exception('Audio file is too short to analyze.');
    }
    onProgress?.call(1.0, 'Done');
    return AudioAnalysis(
      bandFrames: bandFrames,
      beatFrames: beatFrames,
      durationSeconds: duration,
    );
  }
}

/// Thin wrapper around just_audio used by the preview screen. Playback
/// position is the single source of truth for visualizer sync.
class PreviewPlayer {
  final AudioPlayer _player = AudioPlayer();

  Stream<Duration> get positionStream => _player.positionStream;
  Stream<PlayerState> get playerStateStream => _player.playerStateStream;
  Duration get position => _player.position;
  bool get playing => _player.playing;

  Future<Duration?> load(String path) => _player.setFilePath(path);
  Future<void> play() => _player.play();
  Future<void> pause() => _player.pause();
  Future<void> seek(Duration d) => _player.seek(d);
  Future<void> dispose() => _player.dispose();
}
