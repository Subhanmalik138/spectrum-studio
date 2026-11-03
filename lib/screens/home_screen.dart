import 'package:flutter/material.dart';

import '../models/project.dart';
import '../services/project_store.dart';
import 'create_screen.dart';
import 'preview_screen.dart';
import 'templates_screen.dart';

/// Main shell: bottom navigation between Create, My Projects, Templates.
class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  var _index = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.graphic_eq, color: Color(0xFF00E5FF)),
            SizedBox(width: 8),
            Text('Spectrum Studio'),
          ],
        ),
      ),
      body: IndexedStack(
        index: _index,
        children: [
          const CreateScreen(),
          const ProjectsScreen(),
          TemplatesScreen(
            onPick: (t) {
              Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => Scaffold(
                    appBar: AppBar(title: const Text('Create Visualizer')),
                    body: CreateScreen(initialTemplate: t),
                  ),
                ),
              );
            },
          ),
        ],
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _index,
        selectedItemColor: const Color(0xFF00E5FF),
        onTap: (i) => setState(() => _index = i),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.add_circle_outline),
            label: 'Create',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.folder_open),
            label: 'My Projects',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.style),
            label: 'Templates',
          ),
        ],
      ),
    );
  }
}

class ProjectsScreen extends StatefulWidget {
  const ProjectsScreen({super.key});

  @override
  State<ProjectsScreen> createState() => _ProjectsScreenState();
}

class _ProjectsScreenState extends State<ProjectsScreen> {
  Future<List<VisualizerProject>> _load() => ProjectStore.loadAll();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<VisualizerProject>>(
      future: _load(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final projects = snap.data!;
        if (projects.isEmpty) {
          return Center(
            child: Padding(
              padding: const EdgeInsets.all(32),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.folder_open,
                      size: 64, color: Colors.white30),
                  const SizedBox(height: 16),
                  const Text(
                    'No projects yet',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Create tab se apna pehla visualizer banayen.',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white.withOpacity(0.6)),
                  ),
                ],
              ),
            ),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: projects.length,
          itemBuilder: (context, i) {
            final p = projects[i];
            return Card(
              color: const Color(0xFF171222),
              margin: const EdgeInsets.only(bottom: 12),
              child: ListTile(
                leading: const Icon(
                  Icons.music_video,
                  color: Color(0xFF00E5FF),
                ),
                title: Text(p.title),
                subtitle: Text(
                  '${p.artist.isEmpty ? 'Unknown artist' : p.artist} • '
                  '${p.template.title}'
                  '${p.exportedPath != null ? ' • Exported' : ''}',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () async {
                    await ProjectStore.delete(p.id);
                    setState(() {});
                  },
                ),
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => PreviewScreen(project: p),
                  ),
                ),
              ),
            );
          },
        );
      },
    );
  }
}
