import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../models/project.dart';
import '../visualizer/visualizer_painter.dart';

/// Template gallery with live animated mini-previews. The gallery preview
/// uses a deterministic sine-based demo spectrum (it is a template preview,
/// not a song) — the real visualizer always uses the song's actual FFT.
class TemplatesScreen extends StatefulWidget {
  final ValueChanged<VisualizerTemplate>? onPick;

  const TemplatesScreen({super.key, this.onPick});

  @override
  State<TemplatesScreen> createState() => _TemplatesScreenState();
}

class _TemplatesScreenState extends State<TemplatesScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  List<double> _demoBands(double t) {
    return List<double>.generate(64, (i) {
      final v = 0.45 +
          0.35 * math.sin(t * 2.2 + i * 0.45) +
          0.2 * math.sin(t * 3.7 + i * 0.12);
      return v.clamp(0.05, 1.0);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (context, _) {
        final t = _ctrl.value * 4;
        final bands = _demoBands(t);
        final beat = (math.sin(t * 4.4) * 0.5 + 0.5) * 0.8;
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: VisualizerTemplate.values.length,
          itemBuilder: (context, i) {
            final template = VisualizerTemplate.values[i];
            return Card(
              color: const Color(0xFF171222),
              margin: const EdgeInsets.only(bottom: 16),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                onTap: () => widget.onPick?.call(template),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    AspectRatio(
                      aspectRatio: 16 / 9,
                      child: CustomPaint(
                        painter: VisualizerPainter(
                          bands: bands,
                          beat: beat,
                          template: template,
                          settings: const VisualizerSettings(
                            showTitle: false,
                          ),
                          background: null,
                          time: t,
                          title: '',
                          artist: '',
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(14),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            template.title,
                            style: const TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            template.description,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.65),
                            ),
                          ),
                          const SizedBox(height: 8),
                          const Row(
                            children: [
                              Icon(
                                Icons.play_circle_fill,
                                color: Color(0xFF00E5FF),
                                size: 18,
                              ),
                              SizedBox(width: 6),
                              Text(
                                'Use this template',
                                style: TextStyle(
                                  color: Color(0xFF00E5FF),
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ],
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
