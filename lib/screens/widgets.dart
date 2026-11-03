import 'package:flutter/material.dart';

import '../models/project.dart';

/// Shared template picker grid used by Create and Templates screens.
class TemplatePicker extends StatelessWidget {
  final VisualizerTemplate selected;
  final ValueChanged<VisualizerTemplate> onSelected;

  const TemplatePicker({
    super.key,
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 1.35,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      itemCount: VisualizerTemplate.values.length,
      itemBuilder: (context, i) {
        final t = VisualizerTemplate.values[i];
        final isSel = t == selected;
        return InkWell(
          onTap: () => onSelected(t),
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              color: isSel
                  ? const Color(0xFF00E5FF).withOpacity(0.14)
                  : const Color(0xFF1B1626),
              border: Border.all(
                color: isSel
                    ? const Color(0xFF00E5FF)
                    : Colors.white.withOpacity(0.08),
                width: isSel ? 2 : 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  _iconFor(t),
                  color: isSel
                      ? const Color(0xFF00E5FF)
                      : Colors.white70,
                  size: 28,
                ),
                const SizedBox(height: 10),
                Text(
                  t.title,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  t.description,
                  style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withOpacity(0.6),
                  ),
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  IconData _iconFor(VisualizerTemplate t) {
    switch (t) {
      case VisualizerTemplate.circularSpectrum:
        return Icons.donut_large;
      case VisualizerTemplate.rotatingBars:
        return Icons.bar_chart;
      case VisualizerTemplate.neonRings:
        return Icons.radio_button_checked;
      case VisualizerTemplate.glowingSphere:
        return Icons.public;
      case VisualizerTemplate.particles:
        return Icons.blur_on;
      case VisualizerTemplate.waveformTunnel:
        return Icons.timeline;
    }
  }
}

const _swatches = <int>[
  0xFF00E5FF,
  0xFF7C4DFF,
  0xFFFF2D78,
  0xFF00E676,
  0xFFFFEA00,
  0xFFFF6D00,
  0xFFFFFFFF,
  0xFF2979FF,
];

/// Sliders + color swatches for visualizer customization.
class SettingsEditor extends StatelessWidget {
  final VisualizerSettings settings;
  final ValueChanged<VisualizerSettings> onChanged;

  const SettingsEditor({
    super.key,
    required this.settings,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Color',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 10,
          children: _swatches.map((c) {
            final sel = settings.color == c;
            return GestureDetector(
              onTap: () => onChanged(settings.copyWith(color: c)),
              child: Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: Color(c),
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: sel ? Colors.white : Colors.transparent,
                    width: 2.5,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 18),
        _slider('Size', settings.size, 0.5, 1.5,
            (v) => onChanged(settings.copyWith(size: v))),
        _slider('Glow', settings.glow, 0, 1,
            (v) => onChanged(settings.copyWith(glow: v))),
        _slider('Background blur', settings.backgroundBlur, 0, 1,
            (v) => onChanged(settings.copyWith(backgroundBlur: v))),
        _slider('Horizontal position', settings.posX, -1, 1,
            (v) => onChanged(settings.copyWith(posX: v))),
        _slider('Vertical position', settings.posY, -1, 1,
            (v) => onChanged(settings.copyWith(posY: v))),
        const SizedBox(height: 8),
        Row(
          children: [
            const Text('Show song title',
                style: TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            Switch(
              value: settings.showTitle,
              activeColor: const Color(0xFF00E5FF),
              onChanged: (v) =>
                  onChanged(settings.copyWith(showTitle: v)),
            ),
          ],
        ),
        const SizedBox(height: 8),
        const Text('Title placement',
            style: TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(height: 6),
        SegmentedButton<TextPlacement>(
          segments: const [
            ButtonSegment(value: TextPlacement.top, label: Text('Top')),
            ButtonSegment(value: TextPlacement.center, label: Text('Center')),
            ButtonSegment(
                value: TextPlacement.bottom, label: Text('Bottom')),
          ],
          selected: {settings.textPlacement},
          onSelectionChanged: (s) =>
              onChanged(settings.copyWith(textPlacement: s.first)),
        ),
      ],
    );
  }

  Widget _slider(
    String label,
    double value,
    double min,
    double max,
    ValueChanged<double> onChanged,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
            const Spacer(),
            Text(value.toStringAsFixed(2),
                style: const TextStyle(color: Colors.white70)),
          ],
        ),
        Slider(
          value: value,
          min: min,
          max: max,
          activeColor: const Color(0xFF00E5FF),
          onChanged: onChanged,
        ),
      ],
    );
  }
}
