import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:gti_speaki/game/components/main_character.dart';
import 'package:gti_speaki/game/ggumteul_game.dart';
import 'package:gti_speaki/game/models/character_info.dart';

/// 메인 캐릭터 주변에 표시되는 서브 캐릭터
class SubCharacter extends PositionComponent
    with HasGameReference<FlameGame> {
  SubCharacter({
    required this.ggumteulGame,
    required CharacterInfo characterInfo,
  }) : _characterInfo = characterInfo;

  final GgumteulGame ggumteulGame;
  CharacterInfo _characterInfo;
  CharacterInfo get characterInfo => _characterInfo;

  late ui.Image _imageIdle1;
  late ui.Image _imageReturn2;
  bool _isLoaded = false;

  // 떨림 효과
  final math.Random _random = math.Random();
  final Vector2 _shakeOffset = Vector2.zero();
  static const double shakeIntensity = 2.0;

  // 배회 이동
  Vector2 _wanderDirection = Vector2.zero();
  static const double wanderSpeed = 15.0; // 픽셀/초
  double _directionChangeTimer = 0.0;
  double _nextDirectionChangeTime = 0.0;
  static const double dirChangeTimeMin = 2.0; // 최소 방향 유지 시간
  static const double dirChangeTimeMax = 5.0; // 최대 방향 유지 시간

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    await _loadImages();
    _isLoaded = true;

    // 초기 배회 방향 설정
    _pickRandomDirection();
    _nextDirectionChangeTime = dirChangeTimeMin +
        _random.nextDouble() * (dirChangeTimeMax - dirChangeTimeMin);
  }

  Future<void> _loadImages() async {
    _imageIdle1 = await ggumteulGame.images.load(_characterInfo.assets.idle1);
    _imageReturn2 = await ggumteulGame.images.load(_characterInfo.assets.return2);
  }

  /// 캐릭터 변경
  Future<void> changeCharacter(CharacterInfo newInfo) async {
    _characterInfo = newInfo;
    _isLoaded = false;
    await _loadImages();
    _isLoaded = true;
  }

  void _pickRandomDirection() {
    final angle = _random.nextDouble() * 2 * math.pi;
    _wanderDirection = Vector2(math.cos(angle), math.sin(angle));
  }

  /// 메인 캐릭터가 idle이 아닌 상태인지 (cheekPulling, cheekReturn, afterCheekPull)
  bool get _isMainActive {
    final mainChar = ggumteulGame.mainCharacterComponent;
    if (mainChar == null) return false;
    return mainChar.state != CharacterState.idle;
  }

  /// 메인 캐릭터의 중심 X 좌표
  double get _mainCenterX {
    final mainChar = ggumteulGame.mainCharacterComponent;
    if (mainChar == null) return ggumteulGame.size.x / 2;
    return mainChar.position.x + mainChar.size.x / 2;
  }

  /// 이 서브 캐릭터의 중심이 메인 캐릭터 중심보다 오른쪽에 있는지
  bool get _shouldFlip {
    final myCenterX = position.x + size.x / 2;
    return myCenterX > _mainCenterX;
  }

  /// 현재 위치의 Rect
  Rect get bounds => Rect.fromLTWH(position.x, position.y, size.x, size.y);

  @override
  void update(double dt) {
    super.update(dt);

    final mainChar = ggumteulGame.mainCharacterComponent;
    if (mainChar == null) return;

    if (_isMainActive) {
      // 부들부들 떨림
      _shakeOffset.setValues(
        (_random.nextDouble() - 0.5) * 2 * shakeIntensity,
        (_random.nextDouble() - 0.5) * 2 * shakeIntensity,
      );
    } else {
      _shakeOffset.setZero();

      // idle 상태: 배회 이동
      _updateWander(dt);
    }
  }

  void _updateWander(double dt) {
    // 방향 변경 타이머
    _directionChangeTimer += dt;
    if (_directionChangeTimer >= _nextDirectionChangeTime) {
      _directionChangeTimer = 0.0;
      _pickRandomDirection();
      _nextDirectionChangeTime = dirChangeTimeMin +
          _random.nextDouble() * (dirChangeTimeMax - dirChangeTimeMin);
    }

    // 이동 시도
    final delta = _wanderDirection * wanderSpeed * dt;
    final newX = position.x + delta.x;
    final newY = position.y + delta.y;
    final candidateRect = Rect.fromLTWH(newX, newY, size.x, size.y);

    // 화면 경계 체크
    const margin = 10.0;
    final screenW = ggumteulGame.size.x;
    final screenH = ggumteulGame.size.y;
    if (newX < margin || newX + size.x > screenW - margin ||
        newY < margin || newY + size.y > screenH - margin) {
      _bounceDirection();
      return;
    }

    // 메인 캐릭터와 충돌 체크
    final mainChar = ggumteulGame.mainCharacterComponent!;
    final mainRect = Rect.fromLTWH(
      mainChar.position.x,
      mainChar.position.y,
      mainChar.size.x,
      mainChar.size.y,
    );
    if (candidateRect.overlaps(mainRect)) {
      _bounceDirection();
      return;
    }

    // 다른 서브 캐릭터와 충돌 체크
    for (final other in ggumteulGame.subCharacters) {
      if (other == this) continue;
      if (candidateRect.overlaps(other.bounds)) {
        _bounceDirection();
        return;
      }
    }

    // 충돌 없으면 이동
    position.x = newX;
    position.y = newY;
  }

  /// 충돌 시 방향 반전 + 약간의 랜덤 변동
  void _bounceDirection() {
    // 방향 반전 + ±45도 랜덤 회전
    final angle = math.atan2(_wanderDirection.y, _wanderDirection.x) +
        math.pi +
        (_random.nextDouble() - 0.5) * math.pi / 2;
    _wanderDirection = Vector2(math.cos(angle), math.sin(angle));
    _directionChangeTimer = 0.0;
    _nextDirectionChangeTime = dirChangeTimeMin +
        _random.nextDouble() * (dirChangeTimeMax - dirChangeTimeMin);
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (!_isLoaded) return;

    canvas.save();
    canvas.translate(_shakeOffset.x, _shakeOffset.y);

    // 좌우 반전 처리
    if (_shouldFlip) {
      canvas.translate(size.x, 0);
      canvas.scale(-1, 1);
    }

    final image = _isMainActive ? _imageReturn2 : _imageIdle1;
    final srcRect = Rect.fromLTWH(
      0,
      0,
      _characterInfo.imageMeta.width,
      _characterInfo.imageMeta.height,
    );
    final dstRect = Rect.fromLTWH(0, 0, size.x, size.y);

    canvas.drawImageRect(image, srcRect, dstRect, Paint());
    canvas.restore();
  }
}
