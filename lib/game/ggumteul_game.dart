import 'dart:math' as math;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'components/ggumteul_character.dart';

class GgumteulGame extends FlameGame {
  late final SharedPreferences _prefs;
  SharedPreferences get prefs => _prefs;

  late final GgumteulCharacter _character;
  late final SpriteComponent _env1;
  late final SpriteComponent _env2;

  bool _envVisible = false;
  bool get isEnvVisible => _envVisible;
  int get pullCount => _character.pullCount;

  @override
  Color backgroundColor() => const Color.fromARGB(255, 130, 107, 94);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // SharedPreferences 로드
    _prefs = await SharedPreferences.getInstance();

    // _envVisible 로드
    _envVisible = _prefs.getBool('envVisible') ?? false;

    // 환경 이미지 로드
    final envSprite1 = await loadSprite('env/mir.png');
    final envSprite2 = await loadSprite('env/ije_maroni.png');

    // 전체 화면 환경 컴포넌트 생성
    _env1 = SpriteComponent(
      sprite: envSprite1,
      size: size,
      position: size / 2,
      anchor: Anchor.center,
      priority: -10,
    )..sprite?.paint.filterQuality = FilterQuality.high;
    _fitCover(_env1);
    _env2 = SpriteComponent(
      sprite: envSprite2,
      size: size,
      position: size / 2,
      anchor: Anchor.center,
      priority: 10,
    )..sprite?.paint.filterQuality = FilterQuality.high;
    _fitCover(_env2);

    _character = GgumteulCharacter(game: this);
    await add(_character);

    if (_envVisible) {
      await add(_env1);
      await add(_env2);
    }

    overlays.add('pullCounter');
    overlays.add('settingsHud');
  }

  Future<void> toggleEnv(bool visible) async {
    _envVisible = visible;
    await _prefs.setBool('envVisible', visible);

    if (visible && !_env1.isMounted) {
      add(_env1);
    } else if (!visible && _env1.isMounted) {
      _env1.removeFromParent();
    }

    if (visible && !_env2.isMounted) {
      add(_env2);
    } else if (!visible && _env2.isMounted) {
      _env2.removeFromParent();
    }
  }

  void _fitCover(SpriteComponent c) {
    final imgSize = c.sprite!.srcSize;
    final screen = size;

    final scale = math.max(screen.x / imgSize.x, screen.y / imgSize.y);

    c
      ..size = imgSize * scale
      ..position = screen / 2;
  }
}
