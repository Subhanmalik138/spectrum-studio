import 'dart:convert';
import 'dart:ui' show Color;

/// The twelve built-in 3D visualizer templates. New values are always
/// appended at the end so saved projects keep resolving to the same
/// template they were created with.
enum VisualizerTemplate {
  circularSpectrum,
  rotatingBars,
  neonRings,
  glowingSphere,
  particles,
  waveformTunnel,
  spiralGalaxy,
  dnaHelix,
  gridWall,
  solarFlare,
  cubeField,
  liquidWaves,
}

extension VisualizerTemplateInfo on VisualizerTemplate {
  String get title {
    switch (this) {
      case VisualizerTemplate.circularSpectrum:
        return 'Circular Spectrum';
      case VisualizerTemplate.rotatingBars:
        return 'Rotating 3D Bars';
      case VisualizerTemplate.neonRings:
        return 'Neon Rings';
      case VisualizerTemplate.glowingSphere:
        return 'Glowing Sphere';
      case VisualizerTemplate.particles:
        return 'Particle Field';
      case VisualizerTemplate.waveformTunnel:
        return 'Waveform Tunnel';
      case VisualizerTemplate.spiralGalaxy:
        return 'Spiral Galaxy';
      case VisualizerTemplate.dnaHelix:
        return 'DNA Helix';
      case VisualizerTemplate.gridWall:
        return '3D Grid Wall';
      case VisualizerTemplate.solarFlare:
        return 'Solar Flare';
      case VisualizerTemplate.cubeField:
        return 'Cube Field';
      case VisualizerTemplate.liquidWaves:
        return 'Liquid Waves';
    }
  }

  String get description {
    switch (this) {
      case VisualizerTemplate.circularSpectrum:
        return 'A 3D ring of spectrum bars orbiting the artwork.';
      case VisualizerTemplate.rotatingBars:
        return 'Frequency bars wrapped around a rotating cylinder.';
      case VisualizerTemplate.neonRings:
        return 'Pulsing neon rings that expand on every beat.';
      case VisualizerTemplate.glowingSphere:
        return 'A sphere of audio-reactive points that breathes with the bass.';
      case VisualizerTemplate.particles:
        return 'Thousands of 3D particles driven by the frequency spectrum.';
      case VisualizerTemplate.waveformTunnel:
        return 'A perspective tunnel of waveform rings flying past the camera.';
      case VisualizerTemplate.spiralGalaxy:
        return 'Three audio-reactive spiral arms spinning around a glowing core.';
      case VisualizerTemplate.dnaHelix:
        return 'A double helix whose strands breathe with the music.';
      case VisualizerTemplate.gridWall:
        return 'A 3D equalizer floor stretching into the distance.';
      case VisualizerTemplate.solarFlare:
        return 'Explosive rays of light bursting on every beat.';
      case VisualizerTemplate.cubeField:
        return 'A field of 3D cubes bouncing to the frequency spectrum.';
      case VisualizerTemplate.liquidWaves:
        return 'Layered glowing waves flowing across the screen.';
    }
  }
}

enum ExportAspect { vertical, landscape, square }

extension ExportAspectInfo on ExportAspect {
  String get label {
    switch (this) {
      case ExportAspect.vertical:
        return '9:16 Vertical';
      case ExportAspect.landscape:
        return '16:9 Landscape';
      case ExportAspect.square:
        return '1:1 Square';
    }
  }

  /// Returns (width, height) for a given base resolution (the long edge).
  (int, int) sizeFor(int longEdge) {
    switch (this) {
      case ExportAspect.vertical:
        return (longEdge * 9 ~/ 16, longEdge);
      case ExportAspect.landscape:
        return (longEdge, longEdge * 9 ~/ 16);
      case ExportAspect.square:
        return (longEdge, longEdge);
    }
  }
}

enum TextPlacement { top, center, bottom }

/// All user-adjustable visualizer settings. Defaults are tuned so a video
/// looks professional with zero manual adjustment.
class VisualizerSettings {
  final int color; // ARGB
  final double size; // 0.5 - 1.5 scale
  final double posX; // -1..1 offset from center
  final double posY; // -1..1 offset from center
  final double glow; // 0..1
  final double backgroundBlur; // 0..1
  final TextPlacement textPlacement;
  final bool showTitle;

  const VisualizerSettings({
    this.color = 0xFF00E5FF,
    this.size = 1.0,
    this.posX = 0.0,
    this.posY = 0.0,
    this.glow = 0.7,
    this.backgroundBlur = 0.4,
    this.textPlacement = TextPlacement.bottom,
    this.showTitle = true,
  });

  Color get colorValue => Color(color);

  VisualizerSettings copyWith({
    int? color,
    double? size,
    double? posX,
    double? posY,
    double? glow,
    double? backgroundBlur,
    TextPlacement? textPlacement,
    bool? showTitle,
  }) =>
      VisualizerSettings(
        color: color ?? this.color,
        size: size ?? this.size,
        posX: posX ?? this.posX,
        posY: posY ?? this.posY,
        glow: glow ?? this.glow,
        backgroundBlur: backgroundBlur ?? this.backgroundBlur,
        textPlacement: textPlacement ?? this.textPlacement,
        showTitle: showTitle ?? this.showTitle,
      );

  Map<String, dynamic> toJson() => {
        'color': color,
        'size': size,
        'posX': posX,
        'posY': posY,
        'glow': glow,
        'backgroundBlur': backgroundBlur,
        'textPlacement': textPlacement.name,
        'showTitle': showTitle,
      };

  factory VisualizerSettings.fromJson(Map<String, dynamic> j) =>
      VisualizerSettings(
        color: j['color'] as int? ?? 0xFF00E5FF,
        size: (j['size'] as num?)?.toDouble() ?? 1.0,
        posX: (j['posX'] as num?)?.toDouble() ?? 0.0,
        posY: (j['posY'] as num?)?.toDouble() ?? 0.0,
        glow: (j['glow'] as num?)?.toDouble() ?? 0.7,
        backgroundBlur: (j['backgroundBlur'] as num?)?.toDouble() ?? 0.4,
        textPlacement: TextPlacement.values.firstWhere(
          (e) => e.name == j['textPlacement'],
          orElse: () => TextPlacement.bottom,
        ),
        showTitle: j['showTitle'] as bool? ?? true,
      );
}

/// A saved project. Audio and background live as local file paths so
/// projects work fully offline.
class VisualizerProject {
  final String id;
  final String title;
  final String artist;
  final String audioPath;
  final String? backgroundPath;
  final VisualizerTemplate template;
  final VisualizerSettings settings;
  final double durationSeconds;
  final String? exportedPath;
  final DateTime createdAt;

  VisualizerProject({
    required this.id,
    required this.title,
    required this.artist,
    required this.audioPath,
    this.backgroundPath,
    required this.template,
    required this.settings,
    required this.durationSeconds,
    this.exportedPath,
    required this.createdAt,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'audioPath': audioPath,
        'backgroundPath': backgroundPath,
        'template': template.name,
        'settings': settings.toJson(),
        'durationSeconds': durationSeconds,
        'exportedPath': exportedPath,
        'createdAt': createdAt.toIso8601String(),
      };

  factory VisualizerProject.fromJson(Map<String, dynamic> j) =>
      VisualizerProject(
        id: j['id'] as String,
        title: j['title'] as String,
        artist: j['artist'] as String,
        audioPath: j['audioPath'] as String,
        backgroundPath: j['backgroundPath'] as String?,
        template: VisualizerTemplate.values.firstWhere(
          (e) => e.name == j['template'],
          orElse: () => VisualizerTemplate.circularSpectrum,
        ),
        settings: VisualizerSettings.fromJson(
          Map<String, dynamic>.from(j['settings'] as Map),
        ),
        durationSeconds: (j['durationSeconds'] as num).toDouble(),
        exportedPath: j['exportedPath'] as String?,
        createdAt: DateTime.parse(j['createdAt'] as String),
      );

  String toJsonString() => jsonEncode(toJson());

  factory VisualizerProject.fromJsonString(String s) =>
      VisualizerProject.fromJson(jsonDecode(s) as Map<String, dynamic>);
}
