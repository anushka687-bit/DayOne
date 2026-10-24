import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import 'onboarding_screen.dart';

/// Step 1 of the demo: a brand new user, no personalization yet.
/// Deliberately generic — this is the "before" half of the before/after.
class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'GENERIC EXPERIENCE',
                style: TextStyle(
                  fontFamily: 'monospace',
                  letterSpacing: 2,
                  color: AppColors.accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 16),
              const Text(
                'DayOne',
                style: TextStyle(
                  fontSize: 56,
                  fontWeight: FontWeight.w800,
                  color: AppColors.ink,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 12),
              const Text(
                'Learn. Adapt. Privately.',
                style: TextStyle(
                  fontSize: 20,
                  fontStyle: FontStyle.italic,
                  color: AppColors.inkSoft,
                ),
              ),
              const SizedBox(height: 28),
              const Text(
                'We know nothing about you yet — no history, no account, '
                'no cloud profile. Answer a few quick questions and this '
                'app will adapt to you and your surroundings, instantly.',
                style: TextStyle(fontSize: 16, color: AppColors.inkSoft, height: 1.5),
              ),
              const SizedBox(height: 36),
              ElevatedButton(
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const OnboardingScreen()),
                  );
                },
                child: const Text('Get started (60 seconds)'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
