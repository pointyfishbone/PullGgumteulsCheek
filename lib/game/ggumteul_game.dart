import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'components/ggumteul_character.dart';

class GgumteulGame extends FlameGame {
  @override
  Color backgroundColor() => const Color(0xFFF5F5F5);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    final character = GgumteulCharacter();
    await add(character);
  }
}
