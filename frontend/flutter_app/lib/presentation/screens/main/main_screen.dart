import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/dark_theme.dart';
import '../../widgets/navigation/gradient_bottom_navigation_bar.dart';
import '../exercise/exercise_screen.dart';
import '../profile/profile_screen.dart';
import '../scenario/scenario_screen.dart';
import '../continuous_streaming_screen.dart';

final selectedTabProvider = StateProvider<int>((ref) => 0);

class MainScreen extends ConsumerWidget {
  const MainScreen({super.key});
  
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final selectedTab = ref.watch(selectedTabProvider);
    
    // Liste des écrans
    final screens = [
      const ExerciseScreen(),
      const ScenarioScreen(),
      const ProfileScreen(),
      const ContinuousStreamingScreen(),
    ];
    
    // Éléments de navigation
    final navigationItems = [
      const BottomNavigationItem(
        icon: Icons.mic,
        label: 'Exercise',
        selectedColor: DarkTheme.accentCyan,
      ),
      const BottomNavigationItem(
        icon: Icons.movie,
        label: 'Scenario',
        selectedColor: DarkTheme.primaryPurple,
      ),
      const BottomNavigationItem(
        icon: Icons.person,
        label: 'Profile',
        selectedColor: DarkTheme.accentPink,
      ),
      const BottomNavigationItem(
        icon: Icons.stream,
        label: 'Streaming',
        selectedColor: DarkTheme.primaryBlue,
      ),
    ];
    
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: DarkTheme.backgroundGradient,
        ),
        child: Stack(
          children: [
            // Écran actif
            screens[selectedTab],
            
            // Barre de navigation
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: GradientBottomNavigationBar(
                currentIndex: selectedTab,
                onTap: (index) => ref.read(selectedTabProvider.notifier).state = index,
                items: navigationItems,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
