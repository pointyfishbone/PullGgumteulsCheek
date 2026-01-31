import 'dart:math' as math;

import 'package:flame/components.dart';
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

  late final SpriteComponent _bg;

  late MainCharacter _character;
  MainCharacter? get mainCharacterComponent => _character;

  final List<SubCharacter> _subCharacters = [];
  List<SubCharacter> get subCharacters => _subCharacters;
  final math.Random _random = math.Random();

  // --- pullCount 관리 ---
  int _pullCount = 0;
  int get pullCount => _pullCount;

  /// 해금에 필요한 pullCount 임계값 목록 (변경하기 쉽게 리스트로 관리)
  static const List<int> unlockThresholds = [200, 400, 600];

  // --- 해금 시스템 ---
  final Set<String> _unlockedIds = {};
  int get unlockedCharactersNum => _unlockedIds.length;

  bool isUnlocked(String id) => _unlockedIds.contains(id);

  /// 아직 해금되지 않은 캐릭터 목록
  List<CharacterInfo> get lockedCharacters =>
      chars.Characters.all.where((c) => !_unlockedIds.contains(c.id)).toList();

  /// 현재 캐릭터 정보
  CharacterInfo get currentMainCharacter => _character.characterInfo;

  /// pullCount 증가 및 해금 임계값 체크
  void incrementPullCount() {
    _pullCount++;
    _prefs.setInt('pullCount', _pullCount);

    // 임계값 도달 시 초대 팝업 표시
    if (unlockThresholds
                    .map((e) => e <= _pullCount ? 1 : 0)
                    .reduce((a, b) => a + b) +
                1 >
            _unlockedIds.length &&
        lockedCharacters.isNotEmpty) {
      overlays.add('inviteFriend');
    }
  }

  /// 캐릭터 해금
  Future<void> unlockCharacter(String id) async {
    if (_unlockedIds.contains(id)) return;
    _unlockedIds.add(id);
    await _prefs.setBool('${id}Unlocked', true);
    await _prefs.setInt('unlockedCharactersNum', unlockedCharactersNum);
    await _updateSubCharacters();
  }

  /// 메인 캐릭터 변경
  Future<void> changeMainCharacter(CharacterInfo newCharacter) async {
    await _character.changeCharacter(newCharacter);
    await _prefs.setString('lastMainCharacter', newCharacter.id);
    await _updateSubCharacters();
  }

  @override
  Color backgroundColor() => const Color.fromARGB(255, 130, 107, 94);

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    _prefs = await SharedPreferences.getInstance();
    _packageInfo = await PackageInfo.fromPlatform();

    // pullCount 로드
    _pullCount = _prefs.getInt('pullCount') ?? 0;

    // 해금 상태 로드 (꿈틀이는 항상 해금)
    for (final c in chars.Characters.all) {
      if (c.id == chars.Characters.defaultCharacter.id ||
          (_prefs.getBool('${c.id}Unlocked') ?? false)) {
        _unlockedIds.add(c.id);
      }
    }
    // unlockedCharactersNum 동기화
    await _prefs.setInt('unlockedCharactersNum', unlockedCharactersNum);

    // 마지막 메인 캐릭터 로드
    final lastMainId = _prefs.getString('lastMainCharacter');
    final initialCharacter = (lastMainId != null && isUnlocked(lastMainId))
        ? (chars.Characters.findById(lastMainId) ??
              chars.Characters.defaultCharacter)
        : chars.Characters.defaultCharacter;

    // 전체 화면 배경 컴포넌트 생성
    final bgSprite = await loadSprite('env/bg.png');
    _bg = SpriteComponent(
      sprite: bgSprite,
      size: size,
      position: size / 2,
      anchor: Anchor.center,
      priority: -10,
    )..sprite?.paint.filterQuality = FilterQuality.high;
    await add(_bg);

    // 메인 캐릭터 생성
    _character = MainCharacter(game: this, characterInfo: initialCharacter)
      ..priority = 10;
    await add(_character);

    // 서브 캐릭터 생성 (해금된 캐릭터만)
    await _createSubCharacters();

    overlays.add('pullCounter');
    overlays.add('settingsHud');
  }

  /// 서브 캐릭터 생성 (해금된 + 메인 캐릭터가 아닌 캐릭터들)
  Future<void> _createSubCharacters() async {
    final subCharInfos = chars.Characters.all
        .where(
          (c) => c.id != currentMainCharacter.id && _unlockedIds.contains(c.id),
        )
        .toList();

    if (subCharInfos.isEmpty) return;

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
      )..priority = 5;
      sub.size = Vector2.all(subSize);
      sub.position = positions[i];
      _subCharacters.add(sub);
      await add(sub);
    }
  }

  /// 메인 캐릭터 변경 시 서브 캐릭터 업데이트
  Future<void> _updateSubCharacters() async {
    for (final sub in _subCharacters) {
      sub.removeFromParent();
    }
    _subCharacters.clear();
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

    const margin = 10.0;

    for (int i = 0; i < count; i++) {
      Vector2? pos;

      for (int attempt = 0; attempt < 100; attempt++) {
        final x =
            margin + _random.nextDouble() * (size.x - subSize - margin * 2);
        final y =
            margin + _random.nextDouble() * (size.y - subSize - margin * 2);
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

      pos ??= Vector2(margin + i * (subSize + margin), margin);
      positions.add(pos);
    }

    return positions;
  }
}
