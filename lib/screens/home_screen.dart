import 'package:flutter/material.dart';

import 'blind_box_screen.dart';
import 'meal_history_screen.dart';
import 'practice_screen.dart';
import 'recipe_library_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;

  final _recipeKey = GlobalKey<RecipeLibraryScreenState>();
  final _blindBoxKey = GlobalKey<BlindBoxScreenState>();
  final _historyKey = GlobalKey<MealHistoryScreenState>();
  final _practiceKey = GlobalKey<PracticeScreenState>();

  late final List<Widget> _screens = [
    RecipeLibraryScreen(key: _recipeKey),
    BlindBoxScreen(key: _blindBoxKey),
    MealHistoryScreen(key: _historyKey),
    PracticeScreen(key: _practiceKey),
  ];

  void _onTabTapped(int index) {
    if (index == _currentIndex) return;
    setState(() => _currentIndex = index);
    // 页面通过 IndexedStack 常驻保活，切换时刷新目标页，
    // 保证其它页面新增/修改的数据即时可见。
    switch (index) {
      case 0:
        _recipeKey.currentState?.reload();
      case 1:
        _blindBoxKey.currentState?.reload();
      case 2:
        _historyKey.currentState?.reload();
      case 3:
        _practiceKey.currentState?.reload();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _screens),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, -2),
            ),
          ],
        ),
        child: BottomNavigationBar(
          currentIndex: _currentIndex,
          onTap: _onTabTapped,
          items: const [
            BottomNavigationBarItem(
              icon: Icon(Icons.restaurant_menu),
              activeIcon: Icon(Icons.restaurant_menu),
              label: '菜谱',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.casino_outlined),
              activeIcon: Icon(Icons.casino),
              label: '盲盒',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.calendar_today),
              activeIcon: Icon(Icons.calendar_today),
              label: '饮食记录',
            ),
            BottomNavigationBarItem(
              icon: Icon(Icons.auto_awesome),
              activeIcon: Icon(Icons.auto_awesome),
              label: '修炼',
            ),
          ],
        ),
      ),
    );
  }
}
