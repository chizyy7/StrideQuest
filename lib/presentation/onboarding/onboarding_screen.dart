import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class OnboardingScreen extends ConsumerWidget {
  const OnboardingScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisSize: MainAxisMin,
          children: [
            const Text('Welcome to StrideQuest'),
            ElevatedButton(
              onPressed: () {
                // TODO: Implement onboarding flow
              },
              child: const Text('Get Started'),
            ),
          ],
        ),
      ),
    );
  }
}