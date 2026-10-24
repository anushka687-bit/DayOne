import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../app_state.dart';
import '../models/preference_profile.dart';
import '../theme/app_theme.dart';
import 'home_shell.dart';

/// The entire bootstrapping mechanism for DayOne: four slider questions,
/// ~60 seconds, no account. This is what the problem statement means by
/// "a concrete, fast bootstrapping mechanism."
class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  double _conciseness = 0.5;
  double _visual = 0.5;
  double _guided = 0.5;
  double _minimalNotifications = 0.5;

  final _pageController = PageController();
  int _page = 0;

  static const _questions = [
    _Question(
      eyebrow: 'Question 1 of 4',
      prompt: 'How do you like information presented?',
      leftLabel: 'Detailed',
      rightLabel: 'Concise',
    ),
    _Question(
      eyebrow: 'Question 2 of 4',
      prompt: 'How do you like content shown to you?',
      leftLabel: 'Text-heavy',
      rightLabel: 'Visual',
    ),
    _Question(
      eyebrow: 'Question 3 of 4',
      prompt: 'How do you like getting started on something new?',
      leftLabel: 'Independent',
      rightLabel: 'Guided, step-by-step',
    ),
    _Question(
      eyebrow: 'Question 4 of 4',
      prompt: 'How many notifications do you want?',
      leftLabel: 'Frequent',
      rightLabel: 'Minimal',
    ),
  ];

  void _finish() {
    final profile = PreferenceProfile(
      conciseness: _conciseness,
      visual: _visual,
      guided: _guided,
      minimalNotifications: _minimalNotifications,
    );
    context.read<AppState>().completeOnboarding(profile);
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (_) => const HomeShell()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final values = [_conciseness, _visual, _guided, _minimalNotifications];
    final setters = <ValueChanged<double>>[
      (v) => setState(() => _conciseness = v),
      (v) => setState(() => _visual = v),
      (v) => setState(() => _guided = v),
      (v) => setState(() => _minimalNotifications = v),
    ];

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
              child: Row(
                children: List.generate(_questions.length, (i) {
                  final active = i <= _page;
                  return Expanded(
                    child: Container(
                      height: 4,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        color: active ? AppColors.accent : AppColors.line,
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  );
                }),
              ),
            ),
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _questions.length,
                onPageChanged: (i) => setState(() => _page = i),
                itemBuilder: (context, i) {
                  return _QuestionSlide(
                    question: _questions[i],
                    value: values[i],
                    onChanged: setters[i],
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  if (_page > 0)
                    TextButton(
                      onPressed: () => _pageController.previousPage(
                        duration: const Duration(milliseconds: 250),
                        curve: Curves.easeOut,
                      ),
                      child: const Text('Back'),
                    ),
                  const Spacer(),
                  ElevatedButton(
                    onPressed: () {
                      if (_page < _questions.length - 1) {
                        _pageController.nextPage(
                          duration: const Duration(milliseconds: 250),
                          curve: Curves.easeOut,
                        );
                      } else {
                        _finish();
                      }
                    },
                    child: Text(
                      _page < _questions.length - 1 ? 'Next' : 'Create my profile',
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Question {
  final String eyebrow;
  final String prompt;
  final String leftLabel;
  final String rightLabel;

  const _Question({
    required this.eyebrow,
    required this.prompt,
    required this.leftLabel,
    required this.rightLabel,
  });
}

class _QuestionSlide extends StatelessWidget {
  final _Question question;
  final double value;
  final ValueChanged<double> onChanged;

  const _QuestionSlide({
    required this.question,
    required this.value,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            question.eyebrow.toUpperCase(),
            style: const TextStyle(
              fontFamily: 'monospace',
              letterSpacing: 2,
              color: AppColors.accent,
              fontWeight: FontWeight.w600,
              fontSize: 13,
            ),
          ),
          const SizedBox(height: 16),
          Text(
            question.prompt,
            style: const TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              color: AppColors.ink,
              height: 1.25,
            ),
          ),
          const SizedBox(height: 48),
          Slider(value: value, onChanged: onChanged),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(question.leftLabel,
                  style: const TextStyle(color: AppColors.inkSoft)),
              Text(question.rightLabel,
                  style: const TextStyle(color: AppColors.inkSoft)),
            ],
          ),
        ],
      ),
    );
  }
}
