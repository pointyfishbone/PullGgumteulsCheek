import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:gti_speaki/game/ui/env_switch.dart';
import 'package:gti_speaki/game/ui/pull_counter.dart';

import 'ggumteul_game.dart';

class GameScreen extends StatelessWidget {
  GameScreen({super.key});

  final game = GgumteulGame();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GameWidget(
        game: game,
        overlayBuilderMap: {
          'pullCounter': (context, GgumteulGame game) {
            return Positioned(
              top: 16,
              right: 16,
              child: PullCounter(game: game),
            );
          },
          'envSwitch': (context, GgumteulGame game) {
            return Positioned(
              right: 16,
              bottom: 16,
              child: EnvSwitch(game: game),
            );
          },
        },
      ),
    );
  }
}
