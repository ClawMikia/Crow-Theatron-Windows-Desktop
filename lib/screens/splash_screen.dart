import 'dart:async';
import 'package:flutter/material.dart';
import '../theme/crow_colors.dart';
import '../widgets/crow_title_bar.dart';
import '../widgets/app_shell.dart';

/// Port of `splash/SplashActivity.kt` + `activity_splash.xml`.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Timer(const Duration(milliseconds: 1400), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const AppShell()),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CrowColors.bg,
      body: Column(
        children: [
          const CrowTitleBar(),
          Expanded(
            child: DecoratedBox(
              decoration: const BoxDecoration(
                gradient: RadialGradient(
                  center: Alignment.center,
                  radius: 1.1,
                  colors: [CrowColors.surface, CrowColors.bg],
                ),
              ),
              child: Stack(
                children: [
                  Align(
                    alignment: const Alignment(0, -0.5),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(28),
                          child: Image.asset('assets/icons/app_icon.png', width: 132, height: 132),
                        ),
                        const SizedBox(height: 20),
                        const Text(
                          'Crow Théatron',
                          style: TextStyle(
                            color: CrowColors.accentYellow,
                            fontSize: 30,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Orbitron',
                          ),
                        ),
                      ],
                    ),
                  ),
                  Align(
                    alignment: const Alignment(0, 0.82),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: Opacity(
                        opacity: 0.72,
                        child: Text(
                          'Written by your friend in the future',
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white, fontSize: 17),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
