import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../audio/audio_engine.dart';
import '../models/project.dart';
import '../services/export_service.dart';
import '../services/project_store.dart';
import '../visualizer/frame_renderer.dart';
import '../visualizer/visualizer_painter.dart';
import 'widgets.dart';

/// Live preview: plays the song and drives the visualizer from the real
/// FFT analysis at the current playback position. The same frames are used
/// for export, so preview and video stay identical and in sync.
class PreviewScreen extends StatefulWidget {
  final VisualizerProject project;

  const PreviewScreen({super.key, required this.project});

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late VisualizerProject _project;
  AudioAnalysis? _analysis;
  ui.Image? _background;
  String? _error;
  double _progress = 0;
  String _stage = 'Starting…';
  final _player = PreviewPlayer();
  Timer? _ticker;
  bool _playing = false;
  ExportAspect _aspect = ExportAspect.vertical;

  @override
  void initState() {
    super.initState();
    _project = widget.project;
    _init();
  }

  Future<void> _init() async {
    try {
      final bg = await loadBackgroundImage(_project.backgroundPath);
      final analysis = await AudioAnalysis.analyze(
        _project.audioPath,
        onProgress: (p, stage) {
          if (mounted) {
            setState(() {
              _progress = p;
              _stage = stage;
            });
          }
        },
      );
      await _player.load(_project.audioPath);
      final updated = VisualizerProject(
        id: _project.id,
        title: _project.title,
        artist: _project.artist,
        audioPath: _project.audioPath,
        backgroundPath: _project.backgroundPath,
        template: _project.template,
        settings: _project.settings,
        durationSeconds: analysis.durationSeconds,
        exportedPath: _project.exportedPath,
        createdAt: _project.createdAt,
      );
      if (mounted) {
        setState(() {
          _analysis = analysis;
          _background = bg;
          _project = updated;
        });
      }
      await ProjectStore.save(updated);
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  void _togglePlay() {
    if (_playing) {
      _player.pause();
      _ticker?.cancel();
      setState(() => _playing = false);
    } else {
      _player.play();
      _ticker = Timer.periodic(
        const Duration(milliseconds: 33),
        (_) {
          if (mounted) setState(() {});
        },
      );
      setState(() => _playing = true);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    _player.dispose();
    super.dispose();
  }

  Future<void> _export() async {
    final analysis = _analysis;
    if (analysis == null) return;
    var longEdge = 720;
    var fps = 30;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => _ExportDialog(
        onPick: (edge, f) {
          longEdge = edge;
          fps = f;
        },
      ),
    );
    if (confirmed != true || !mounted) return;

    double progress = 0;
    String stage = 'Rendering…';
    var started = false;
    await showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          // Kick off export once, on first build.
          if (!started) {
            started = true;
            Future.microtask(() async {
            try {
              final out = await ExportService.export(
                project: _project,
                analysis: analysis,
                backgroundImage: _background,
                aspect: _aspect,
                longEdge: longEdge,
                fps: fps,
                onProgress: (p, s) {
                  progress = p;
                  stage = s;
                  setDialogState(() {});
                },
              );
              final updated = VisualizerProject(
                id: _project.id,
                title: _project.title,
                artist: _project.artist,
                audioPath: _project.audioPath,
                backgroundPath: _project.backgroundPath,
                template: _project.template,
                settings: _project.settings,
                durationSeconds: _project.durationSeconds,
                exportedPath: out,
                createdAt: _project.createdAt,
              );
              await ProjectStore.save(updated);
              if (mounted) setState(() => _project = updated);
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Video saved: $out')),
                );
              }
            } catch (e) {
              if (ctx.mounted) Navigator.of(ctx).pop();
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Export failed: $e')),
                );
              }
            }
            });
          }
          return AlertDialog(
            title: const Text('Exporting video'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                LinearProgressIndicator(value: progress),
                const SizedBox(height: 12),
                Text(stage),
                const SizedBox(height: 6),
                Text('${(progress * 100).toStringAsFixed(0)}%'),
              ],
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final analysis = _analysis;
    return Scaffold(
      appBar: AppBar(
        title: Text(_project.title),
        actions: [
          if (analysis != null)
            IconButton(
              icon: const Icon(Icons.ios_share),
              tooltip: 'Export video',
              onPressed: _export,
            ),
        ],
      ),
      body: _error != null
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                  _error!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: Colors.redAccent),
                ),
              ),
            )
          : analysis == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      SizedBox(
                        width: 220,
                        child: LinearProgressIndicator(value: _progress),
                      ),
                      const SizedBox(height: 14),
                      Text(_stage),
                    ],
                  ),
                )
              : _buildPreview(analysis),
    );
  }

  Widget _buildPreview(AudioAnalysis analysis) {
    final pos = _player.position.inMilliseconds / 1000.0;
    final frame = analysis.frameAt(pos);
    final (w, h) = _aspect.sizeFor(720);
    final aspectRatio = w / h;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Center(
          child: AspectRatio(
            aspectRatio: aspectRatio,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: Colors.white.withOpacity(0.1)),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: CustomPaint(
                  painter: VisualizerPainter(
                    bands: frame.bands,
                    beat: frame.beat,
                    template: _project.template,
                    settings: _project.settings,
                    background: _background,
                    time: pos,
                    title: _project.title,
                    artist: _project.artist,
                  ),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            IconButton(
              iconSize: 40,
              color: const Color(0xFF00E5FF),
              icon: Icon(
                _playing ? Icons.pause_circle : Icons.play_circle,
              ),
              onPressed: _togglePlay,
            ),
            Expanded(
              child: Slider(
                value: pos.clamp(0.0, analysis.durationSeconds),
                max: analysis.durationSeconds,
                activeColor: const Color(0xFF00E5FF),
                onChanged: (v) => _player.seek(
                  Duration(milliseconds: (v * 1000).round()),
                ),
              ),
            ),
            Text(
              '${_fmt(pos)} / ${_fmt(analysis.durationSeconds)}',
              style: const TextStyle(fontSize: 12),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text(
          'Export format',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        SegmentedButton<ExportAspect>(
          segments: ExportAspect.values
              .map((a) => ButtonSegment(value: a, label: Text(a.label)))
              .toList(),
          selected: {_aspect},
          onSelectionChanged: (s) => setState(() => _aspect = s.first),
        ),
        const SizedBox(height: 16),
        const Text(
          'Template & style',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 8),
        TemplatePicker(
          selected: _project.template,
          onSelected: (t) => setState(() {
            _project = VisualizerProject(
              id: _project.id,
              title: _project.title,
              artist: _project.artist,
              audioPath: _project.audioPath,
              backgroundPath: _project.backgroundPath,
              template: t,
              settings: _project.settings,
              durationSeconds: _project.durationSeconds,
              exportedPath: _project.exportedPath,
              createdAt: _project.createdAt,
            );
          }),
        ),
        const SizedBox(height: 16),
        SettingsEditor(
          settings: _project.settings,
          onChanged: (s) => setState(() {
            _project = VisualizerProject(
              id: _project.id,
              title: _project.title,
              artist: _project.artist,
              audioPath: _project.audioPath,
              backgroundPath: _project.backgroundPath,
              template: _project.template,
              settings: s,
              durationSeconds: _project.durationSeconds,
              exportedPath: _project.exportedPath,
              createdAt: _project.createdAt,
            );
          }),
        ),
        const SizedBox(height: 20),
        SizedBox(
          height: 54,
          child: ElevatedButton.icon(
            onPressed: _export,
            icon: const Icon(Icons.movie_creation),
            label: const Text(
              'Export Video (MP4)',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
            ),
          ),
        ),
        if (_project.exportedPath != null) ...[
          const SizedBox(height: 10),
          Text(
            'Last export: ${_project.exportedPath}',
            style: TextStyle(color: Colors.white.withOpacity(0.6)),
          ),
        ],
        const SizedBox(height: 30),
      ],
    );
  }

  String _fmt(double seconds) {
    final m = seconds ~/ 60;
    final s = (seconds % 60).floor().toString().padLeft(2, '0');
    return '$m:$s';
  }
}

class _ExportDialog extends StatefulWidget {
  final void Function(int longEdge, int fps) onPick;

  const _ExportDialog({required this.onPick});

  @override
  State<_ExportDialog> createState() => _ExportDialogState();
}

class _ExportDialogState extends State<_ExportDialog> {
  var _edge = 720;
  var _fps = 30;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Export settings'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Resolution'),
          ),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 720, label: Text('720p')),
              ButtonSegment(value: 1080, label: Text('1080p')),
            ],
            selected: {_edge},
            onSelectionChanged: (s) => setState(() => _edge = s.first),
          ),
          const SizedBox(height: 14),
          const Align(
            alignment: Alignment.centerLeft,
            child: Text('Frame rate'),
          ),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 30, label: Text('30 FPS')),
              ButtonSegment(value: 60, label: Text('60 FPS')),
            ],
            selected: {_fps},
            onSelectionChanged: (s) => setState(() => _fps = s.first),
          ),
          const SizedBox(height: 12),
          Text(
            'Note: 1080p / 60 FPS renders more frames and takes longer.',
            style: TextStyle(
              fontSize: 12,
              color: Colors.white.withOpacity(0.6),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () {
            widget.onPick(_edge, _fps);
            Navigator.of(context).pop(true);
          },
          child: const Text('Export'),
        ),
      ],
    );
  }
}
