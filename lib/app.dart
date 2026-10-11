import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:stridequest/providers.dart';
import 'package:stridequest/presentation/onboarding/onboarding_screen.dart';
import 'package:stridequest/presentation/home/home_screen.dart';
import 'package:stridequest/presentation/journey/journey_screen.dart';
import 'package:stridequest/presentation/stats/stats_screen.dart';
import 'package:stridequest/presentation/settings/settings_screen.dart';

class StrideQuestApp extends ConsumerWidget {
  const StrideQuestApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final GoRouter router = _createRouter(ref);
    return MaterialApp.router(
      title: 'StrideQuest',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C5CE7), // AppColors.primary
        ),
      ),
      routerConfig: router,
    );
  }

  GoRouter _createRouter(WidgetRef ref) {
    return GoRouter(
      redirect: (context, state) {
        final userState = ref.watch(userProvider);
        return userState.maybeWhen(
          orElse: () => '/onboarding',
          data: (user) => user.onboardingComplete ? null : '/onboarding',
        );
      },
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (context, state, navigationShell) {
            return Scaffold(
              body: navigationShell,
              bottomNavigationBar: NavigationBar(
                selectedIndex: navigationShell.currentIndex,
                onDestinationSelected: (int index) =>
                    navigationShell.goBranch(index),
                destinations: const [
                  NavigationDestination(
                    icon: Icon(Icons.home),
                    label: 'Home',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.map),
                    label: 'Journey',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.insights),
                    label: 'Stats',
                  ),
                  NavigationDestination(
                    icon: Icon(Icons.settings),
                    label: 'Settings',
                  ),
                ],
              ),
            );
          },
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/home',
                  builder: (context, state) => const HomeScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/journey',
                  builder: (context, state) => const JourneyScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/stats',
                  builder: (context, state) => const StatsScreen(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/settings',
                  builder: (context, state) => const SettingsScreen(),
                ),
              ],
            ),
          ],
        ),
        GoRoute(
          path: '/onboarding',
          builder: (context, state) => const OnboardingScreen(),
        ),
      ],
    );
  }
}