import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/widgets/ambient_background.dart';
import '../../data/local/local_db.dart';
import '../budget/budget_screen.dart';
import '../dashboard/dashboard_home.dart';
import '../fitness/fitness_screen.dart';
import '../guide/bloom_guide_overlay.dart';
import '../nutrition/nutrition_screen.dart';
import '../onboarding/intake_screen.dart';
import '../reflection/reflection_screen.dart';
import '../voice/voice_session_screen.dart';

/// Bloom v3 shell: a holistic daily companion. Tabs = Dashboard, Budget,
/// Reflection, Fitness, Nutrition. A floating orb on every tab voice-guides the
/// current page. On launch Bloom speaks first (intake, then a daily greeting).
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  static const _pageIds = ['dashboard', 'budget', 'reflection', 'fitness', 'nutrition'];
  static const _pages = <Widget>[
    DashboardHome(),
    BudgetScreen(),
    ReflectionScreen(),
    FitnessScreen(),
    NutritionScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _openingRitual());
  }

  Future<void> _openingRitual() async {
    final done = await LocalDb.instance.getMeta('onboarded');
    if (!mounted) return;
    if (done == null) {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const IntakeScreen(), fullscreenDialog: true),
      );
      if (mounted) setState(() {});
    } else {
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const VoiceSessionScreen(), fullscreenDialog: true),
      );
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: AmbientBackground(
        child: BloomGuideOverlay(
          pageId: _pageIds[_index],
          child: SafeArea(child: _pages[_index]),
        ),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.account_balance_wallet_outlined), label: 'Budget'),
          NavigationDestination(icon: Icon(Icons.self_improvement_outlined), label: 'Reflect'),
          NavigationDestination(icon: Icon(Icons.fitness_center_outlined), label: 'Fitness'),
          NavigationDestination(icon: Icon(Icons.restaurant_outlined), label: 'Nutrition'),
        ],
      ),
    );
  }
}
