import 'package:flutter/material.dart';

import '../features/editor/editor_screen.dart';
import '../features/home/home_screen.dart';
import '../features/library/library_screen.dart';
import '../features/profile/profile_screen.dart';

/// The ONE bottom-navigation shell (Home / Library / Profile) — never a
/// second competing navigation system. Owns which tab is active and which
/// Library filter should be applied, since Library needs to be reachable
/// with a pre-applied filter from Home "See all" / Profile "Explore
/// Library", not just from the bottom-nav tap itself (which always means
/// "All").
class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _tabIndex = 0;
  String _libraryFilter = 'all';

  void _openLibrary(String filter) {
    setState(() {
      _tabIndex = 1;
      _libraryFilter = filter;
    });
  }

  void _openEditor(String lessonId) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => EditorScreen(
          lessonId: lessonId,
          onOpenEditor: _openEditor,
          onBackToHome: _backToHome,
        ),
      ),
    );
  }

  /// PASS 5 §7 — Completion's "Back to home": pops every pushed route back
  /// to this AppShell root AND selects the Home tab specifically, so it
  /// always lands on Home root regardless of which tab was active before
  /// the Editor was opened.
  void _backToHome() {
    setState(() {
      _tabIndex = 0;
      _libraryFilter = 'all';
    });
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Widget _buildBody() {
    switch (_tabIndex) {
      case 0:
        return HomeScreen(onOpenLibrary: _openLibrary, onOpenEditor: _openEditor);
      case 1:
        // Keyed by filter: a fresh request (e.g. a different "See all")
        // always lands on the right filter, even if Library is already the
        // active tab.
        return LibraryScreen(
          key: ValueKey('library-$_libraryFilter'),
          initialFilter: _libraryFilter,
          onOpenEditor: _openEditor,
          onExploreLibraryAll: () => _openLibrary('all'),
        );
      case 2:
        return ProfileScreen(onOpenLibraryAll: () => _openLibrary('all'), onOpenEditor: _openEditor);
      default:
        throw StateError('Unknown tab index: $_tabIndex');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _buildBody(),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tabIndex,
        onDestinationSelected: (index) {
          setState(() {
            _tabIndex = index;
            if (index == 1) _libraryFilter = 'all'; // Bottom Nav entry is always "All".
          });
        },
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'Home'),
          NavigationDestination(icon: Icon(Icons.grid_view_outlined), selectedIcon: Icon(Icons.grid_view), label: 'Library'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
