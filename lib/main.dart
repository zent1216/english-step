import 'package:flutter/material.dart';

import 'app_state.dart';
import 'screens/song_list_screen.dart';
import 'screens/story_list_screen.dart';
import 'screens/vocab_screen.dart';
import 'speech/moonshine.dart';
import 'theme.dart';
import 'update_check.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppState.instance.load();
  MoonshineEngine.instance.init(); // 음성 인식 모델이 받아져 있는지 확인(기다리지 않음)
  runApp(const EnglishStepApp());
}

class EnglishStepApp extends StatelessWidget {
  const EnglishStepApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '영어 한 걸음',
      debugShowCheckedModeBanner: false,
      theme: buildTheme(Brightness.light),
      darkTheme: buildTheme(Brightness.dark),
      home: const HomeShell(),
    );
  }
}

/// 하단 탭 3개(이야기 / 팝송 연습 / 단어장)를 가진 첫 화면.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _tab = 0;

  @override
  void initState() {
    super.initState();
    // 첫 화면이 뜬 뒤 새 버전이 있는지 한 번 확인한다.
    WidgetsBinding.instance.addPostFrameCallback((_) => autoCheckForUpdate(context));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _tab,
        children: const [StoryListScreen(), SongListScreen(), VocabScreen()],
      ),
      bottomNavigationBar: ListenableBuilder(
        listenable: AppState.instance,
        builder: (context, _) {
          final due = AppState.instance.dueWords().length;
          Widget vocabIcon(IconData icon) => Badge(
                isLabelVisible: due > 0,
                label: Text('$due'),
                child: Icon(icon),
              );
          return NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: (i) => setState(() => _tab = i),
            destinations: [
              const NavigationDestination(
                icon: Icon(Icons.menu_book_outlined),
                selectedIcon: Icon(Icons.menu_book),
                label: '이야기',
              ),
              const NavigationDestination(
                icon: Icon(Icons.music_note_outlined),
                selectedIcon: Icon(Icons.music_note),
                label: '팝송 연습',
              ),
              NavigationDestination(
                icon: vocabIcon(Icons.style_outlined),
                selectedIcon: vocabIcon(Icons.style),
                label: '단어장',
              ),
            ],
          );
        },
      ),
    );
  }
}
