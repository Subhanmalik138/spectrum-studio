import 'package:shared_preferences/shared_preferences.dart';

import '../models/project.dart';

/// Local project persistence (offline, on-device only).
class ProjectStore {
  static const _key = 'visualizer_projects_v1';

  static Future<List<VisualizerProject>> loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getStringList(_key) ?? const [];
    final out = <VisualizerProject>[];
    for (final s in raw) {
      try {
        out.add(VisualizerProject.fromJsonString(s));
      } catch (_) {
        // Skip a corrupt entry rather than losing the whole list.
      }
    }
    out.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return out;
  }

  static Future<void> save(VisualizerProject project) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await loadAll();
    all.removeWhere((p) => p.id == project.id);
    all.insert(0, project);
    await prefs.setStringList(
      _key,
      all.map((p) => p.toJsonString()).toList(),
    );
  }

  static Future<void> delete(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final all = await loadAll();
    all.removeWhere((p) => p.id == id);
    await prefs.setStringList(
      _key,
      all.map((p) => p.toJsonString()).toList(),
    );
  }
}
