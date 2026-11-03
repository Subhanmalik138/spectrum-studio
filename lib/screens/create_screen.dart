import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';

import '../models/project.dart';
import '../services/project_store.dart';
import 'preview_screen.dart';
import 'widgets.dart';

/// Step-by-step creation flow: song -> background -> title/artist ->
/// template -> customization -> preview & export.
///
/// Professional defaults are pre-selected, so tapping "Preview" with just a
/// song already produces a finished-looking video.
class CreateScreen extends StatefulWidget {
  final VisualizerTemplate? initialTemplate;

  const CreateScreen({super.key, this.initialTemplate});

  @override
  State<CreateScreen> createState() => _CreateScreenState();
}

class _CreateScreenState extends State<CreateScreen> {
  String? _audioPath;
  String? _audioName;
  String? _backgroundPath;
  final _titleCtrl = TextEditingController();
  final _artistCtrl = TextEditingController();
  late VisualizerTemplate _template;
  var _settings = const VisualizerSettings();

  @override
  void initState() {
    super.initState();
    _template = widget.initialTemplate ?? VisualizerTemplate.circularSpectrum;
  }

  @override
  void dispose() {
    _titleCtrl.dispose();
    _artistCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickSong() async {
    final res = await FilePicker.platform.pickFiles(type: FileType.audio);
    if (res != null && res.files.single.path != null) {
      setState(() {
        _audioPath = res.files.single.path;
        _audioName = res.files.single.name;
        if (_titleCtrl.text.isEmpty) {
          _titleCtrl.text = res.files.single.name
              .replaceAll(RegExp(r'\.[a-zA-Z0-9]+$'), '')
              .replaceAll(RegExp(r'[_-]+'), ' ');
        }
      });
    }
  }

  Future<void> _pickBackground() async {
    final img =
        await ImagePicker().pickImage(source: ImageSource.gallery);
    if (img != null) {
      setState(() => _backgroundPath = img.path);
    }
  }

  void _goPreview() {
    if (_audioPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pehle ek song select karein.')),
      );
      return;
    }
    final project = VisualizerProject(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: _titleCtrl.text.trim().isEmpty
          ? (_audioName ?? 'Untitled')
          : _titleCtrl.text.trim(),
      artist: _artistCtrl.text.trim(),
      audioPath: _audioPath!,
      backgroundPath: _backgroundPath,
      template: _template,
      settings: _settings,
      durationSeconds: 0, // Filled after analysis on the preview screen.
      createdAt: DateTime.now(),
    );
    ProjectStore.save(project);
    Navigator.of(context).push(
      MaterialPageRoute(builder: (_) => PreviewScreen(project: project)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        const Text(
          'Create Visualizer',
          style: TextStyle(fontSize: 26, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 6),
        Text(
          'Song chunein, background lagayen, template select karein — video khud ban jayega.',
          style: TextStyle(color: Colors.white.withOpacity(0.65)),
        ),
        const SizedBox(height: 22),
        _stepCard(
          n: '1',
          title: 'Song select karein',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_audioName != null)
                Text('🎵 $_audioName',
                    style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 8),
              ElevatedButton.icon(
                onPressed: _pickSong,
                icon: const Icon(Icons.music_note),
                label: Text(_audioPath == null
                    ? 'Device se song chunein'
                    : 'Doosra song chunein'),
              ),
            ],
          ),
        ),
        _stepCard(
          n: '2',
          title: 'Background picture (optional)',
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_backgroundPath != null)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.file(
                    File(_backgroundPath!),
                    height: 140,
                    width: double.infinity,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(),
                  ),
                ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: _pickBackground,
                icon: const Icon(Icons.image),
                label: const Text('Gallery se picture chunein'),
              ),
            ],
          ),
        ),
        _stepCard(
          n: '3',
          title: 'Song details',
          child: Column(
            children: [
              TextField(
                controller: _titleCtrl,
                decoration: const InputDecoration(
                  labelText: 'Song title',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _artistCtrl,
                decoration: const InputDecoration(
                  labelText: 'Artist name',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
          ),
        ),
        _stepCard(
          n: '4',
          title: '3D visualizer template',
          child: TemplatePicker(
            selected: _template,
            onSelected: (t) => setState(() => _template = t),
          ),
        ),
        _stepCard(
          n: '5',
          title: 'Customize (optional)',
          child: SettingsEditor(
            settings: _settings,
            onChanged: (s) => setState(() => _settings = s),
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          height: 54,
          child: ElevatedButton.icon(
            onPressed: _goPreview,
            icon: const Icon(Icons.play_circle_fill),
            label: const Text(
              'Preview & Export',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFF00E5FF),
              foregroundColor: Colors.black,
            ),
          ),
        ),
        const SizedBox(height: 30),
      ],
    );
  }

  Widget _stepCard({
    required String n,
    required String title,
    required Widget child,
  }) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF171222),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 13,
                backgroundColor: const Color(0xFF00E5FF),
                child: Text(
                  n,
                  style: const TextStyle(
                    color: Colors.black,
                    fontWeight: FontWeight.bold,
                    fontSize: 13,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}
