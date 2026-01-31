import 'dart:math' as math;

import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'components/main_character.dart';
import 'components/sub_character.dart';
import 'models/character_info.dart';
import 'models/characters.dart' as chars;

class GgumteulGame extends FlameGame {
  late final SharedPreferences _prefs;
  SharedPreferences get prefs => _prefs;
  late final PackageInfo _packageInfo;
  PackageInfo get packageInfo => _packageInfo;

  late MainCharacter _character;
  MainCharacter? get mainCharacterComponent => _character;

  final List<SubCharacter> _subCharacters = [];
  List<SubCharacter> get subCharacters => _subCharacters;
  final math.Random _random = math.Random();

  int get pullCount => _character.pullCount;

  /// 현재 캐릭터 정보
  CharacterInfo get currentMainCharacter => _character.characterInfo;

  /// 메인 캐릭터 변경
  Future<void> changeMainCharacter(CharacterInfo newCharacter) async {
    await _character.changeCharacter(newCharacter);
    await _updateSubCharacters();
  }

  @override
  Color backgroundColor() => const Color.fromARGB(255, 130, 107, 94);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    _prefs = await SharedPreferences.getInstance();
    _packageInfo = await PackageInfo.fromPlatform();

    _character = MainCharacter(
      game: this,
      characterInfo: chars.Characters.defaultCharacter,
    );
    await add(_character);

    // 서브 캐릭터 생성
    await _createSubCharacters();

    overlays.add('pullCounter');
    overlays.add('settingsHud');
  }

  /// 서브 캐릭터 생성 (메인 캐릭터가 아닌 캐릭터들)
  Future<void> _createSubCharacters() async {
    final subCharInfos = chars.Characters.all
        .where((c) => c.id != currentMainCharacter.id)
        .toList();

    // 메인 캐릭터 크기의 35%
    final mainSize = math.min(size.x, size.y) * 0.8;
    final subSize = mainSize * 0.35;

    // 메인 캐릭터의 화면 중심 위치 및 크기 (충돌 감지용)
    final mainDisplaySize = Vector2(
      _character.characterInfo.imageMeta.width /
          _character.characterInfo.imageMeta.height *
          mainSize,
      mainSize,
    );
    final mainTopLeft = Vector2(
      (size.x - mainDisplaySize.x) / 2,
      (size.y - mainDisplaySize.y) / 2,
    );
    final mainRect = Rect.fromLTWH(
      mainTopLeft.x,
      mainTopLeft.y,
      mainDisplaySize.x,
      mainDisplaySize.y,
    );

    // 서브 캐릭터 위치 결정 (겹치지 않게)
    final positions = _generateNonOverlappingPositions(
      count: subCharInfos.length,
      subSize: subSize,
      mainRect: mainRect,
    );

    for (int i = 0; i < subCharInfos.length; i++) {
      final sub = SubCharacter(
        ggumteulGame: this,
        characterInfo: subCharInfos[i],
      );
      sub.size = Vector2.all(subSize);
      sub.position = positions[i];
      _subCharacters.add(sub);
      await add(sub);
    }
  }

  /// 메인 캐릭터 변경 시 서브 캐릭터 업데이트
  Future<void> _updateSubCharacters() async {
    // 기존 서브 캐릭터 제거
    for (final sub in _subCharacters) {
      sub.removeFromParent();
    }
    _subCharacters.clear();

    // 새로운 서브 캐릭터 생성
    await _createSubCharacters();
  }

  /// 겹치지 않는 위치 생성
  List<Vector2> _generateNonOverlappingPositions({
    required int count,
    required double subSize,
    required Rect mainRect,
  }) {
    final positions = <Vector2>[];
    final placedRects = <Rect>[mainRect];

    // 화면 여백
    const margin = 10.0;

    for (int i = 0; i < count; i++) {
      Vector2? pos;

      // 최대 100번 시도
      for (int attempt = 0; attempt < 100; attempt++) {
        final x = margin + _random.nextDouble() * (size.x - subSize - margin * 2);
        final y = margin + _random.nextDouble() * (size.y - subSize - margin * 2);
        final candidateRect = Rect.fromLTWH(x, y, subSize, subSize);

        bool overlaps = false;
        for (final placed in placedRects) {
          if (candidateRect.overlaps(placed)) {
            overlaps = true;
            break;
          }
        }

        if (!overlaps) {
          pos = Vector2(x, y);
          placedRects.add(candidateRect);
          break;
        }
      }

      // 100번 시도 후에도 겹치지 않는 위치를 못 찾으면 화면 가장자리에 배치
      pos ??= Vector2(
        margin + i * (subSize + margin),
        margin,
      );

      positions.add(pos);
    }

    return positions;
  }
}
