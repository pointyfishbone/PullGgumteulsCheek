import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flame/components.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';
import 'package:gti_speaki/game/ggumteul_game.dart';

/// 배경 환경용 나비 객체
/// 화면 바깥에서 등장하여 불규칙하게 날아다니다가 반대편 바깥으로 퇴장한다.
class Butterfly extends PositionComponent with HasGameReference<FlameGame> {
  Butterfly({required this.ggumteulGame});

  final GgumteulGame ggumteulGame;

  // --- 애니메이션 설정 ---
  /// 프레임 전환 주기 (초). 필요 시 변경 가능.
  static const double frameInterval = 0.2;
  static const List<String> _framePaths = [
    'env/butterfly1.png',
    'env/butterfly2.png',
    'env/butterfly3.png',
  ];

  final List<ui.Image> _frames = [];
  int _currentFrame = 0;
  double _frameTimer = 0.0;
  bool _isLoaded = false;

  // --- 이동 ---
  final math.Random _random = math.Random();

  /// 기본 비행 방향 (정규화된 벡터)
  late Vector2 _baseDirection;

  /// 현재 속도 벡터 (불규칙 움직임 포함)
  late Vector2 _velocity;

  /// 비행 속도 (픽셀/초). 화면 크기 기반으로 onLoad에서 결정.
  late double _speed;

  // 불규칙 움직임을 위한 사인파 기반 흔들림
  double _wobblePhase = 0.0;
  late double _wobbleFrequency; // 흔들림 주기
  late double _wobbleAmplitude; // 흔들림 폭 (픽셀/초)

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 이미지 로드
    for (final path in _framePaths) {
      _frames.add(await ggumteulGame.images.load(path));
    }
    _isLoaded = true;

    // 크기 결정: 메인 캐릭터의 17%
    final screenMin = math.min(ggumteulGame.size.x, ggumteulGame.size.y);
    final mainCharSize = screenMin * 0.8; // 메인 캐릭터와 동일한 계산
    final butterflySize = mainCharSize * 0.17;
    size = Vector2.all(butterflySize);
    anchor = Anchor.center;

    // 속도 설정 (화면 대각선의 15~25%)
    final diagonal = math.sqrt(
      ggumteulGame.size.x * ggumteulGame.size.x +
          ggumteulGame.size.y * ggumteulGame.size.y,
    );
    _speed = diagonal * (0.15 + _random.nextDouble() * 0.10);

    // 흔들림 파라미터
    _wobbleFrequency = 1.5 + _random.nextDouble() * 2.0; // 1.5~3.5 Hz
    _wobbleAmplitude = _speed * (0.3 + _random.nextDouble() * 0.3);
    _wobblePhase = _random.nextDouble() * 2 * math.pi;

    // 초기 진입 설정
    _initFlight();
  }

  /// 화면 바깥 임의의 변에서 시작하여 다른 방향으로 날아가도록 설정
  void _initFlight() {
    final screenW = ggumteulGame.size.x;
    final screenH = ggumteulGame.size.y;
    final margin = size.x; // 화면 밖 여유

    // 수평선 기준 ±45도 범위의 비행 각도 결정
    final angleOffset =
        (_random.nextDouble() - 0.5) * (math.pi / 2); // -45° ~ +45°
    final goRight = _random.nextBool();
    final angle = goRight ? angleOffset : math.pi + angleOffset;

    _baseDirection = Vector2(math.cos(angle), math.sin(angle));

    // 비행 방향의 반대편 화면 가장자리에서 진입
    // 방향 벡터를 역추적하여 화면 밖 시작점을 구한다.
    double startX, startY;
    if (goRight) {
      // 왼쪽에서 진입
      startX = -margin;
      startY = _random.nextDouble() * screenH;
    } else {
      // 오른쪽에서 진입
      startX = screenW + margin;
      startY = _random.nextDouble() * screenH;
    }

    position = Vector2(startX, startY);
    _velocity = _baseDirection * _speed;

    // 흔들림 파라미터 재설정
    _wobblePhase = _random.nextDouble() * 2 * math.pi;
    _wobbleFrequency = 1.5 + _random.nextDouble() * 2.0;
    _wobbleAmplitude = _speed * (0.3 + _random.nextDouble() * 0.3);
  }

  /// 화면 중앙의 금지 원 영역(지름 = 화면 높이의 50%)을 회피한다.
  /// 나비가 원 경계에 가까워지면 접선 방향으로 속도를 꺾어 자연스럽게 우회.
  void _avoidCenterZone() {
    final screenW = ggumteulGame.size.x;
    final screenH = ggumteulGame.size.y;
    final center = Vector2(screenW / 2, screenH / 2);
    final radius = screenH * 0.3; // 반지름

    final toCenter = center - position;
    final dist = toCenter.length;

    if (dist < radius + size.x) {
      // 원 중심→나비 방향의 수직(접선) 벡터로 속도를 꺾는다.
      // 기존 진행 방향과 같은 회전 방향을 선택.
      final outward = (position - center).normalized();
      final tangent1 = Vector2(-outward.y, outward.x);
      final tangent2 = Vector2(outward.y, -outward.x);
      final tangent = _velocity.dot(tangent1) >= 0 ? tangent1 : tangent2;

      // 가까울수록 접선 비중을 높인다 (0~1).
      final blend = 1.0 - ((dist - size.x) / radius).clamp(0.0, 1.0);
      _velocity =
          (_velocity * (1.0 - blend) + tangent * _speed * blend).normalized() *
          _velocity.length;
    }
  }

  /// 나비가 화면 밖으로 완전히 벗어났는지 확인
  bool get _isOutOfScreen {
    final margin = size.x * 2;
    final screenW = ggumteulGame.size.x;
    final screenH = ggumteulGame.size.y;
    return position.x < -margin ||
        position.x > screenW + margin ||
        position.y < -margin ||
        position.y > screenH + margin;
  }

  @override
  void update(double dt) {
    super.update(dt);
    if (!_isLoaded) return;

    // 프레임 애니메이션
    _frameTimer += dt;
    if (_frameTimer >= frameInterval) {
      _frameTimer -= frameInterval;
      _currentFrame = (_currentFrame + 1) % _frames.length;
    }

    // 흔들림 업데이트 (기본 방향에 수직인 사인파)
    _wobblePhase += dt * _wobbleFrequency * 2 * math.pi;
    final wobbleValue = math.sin(_wobblePhase) * _wobbleAmplitude;

    // 기본 방향에 수직인 벡터
    final perpendicular = Vector2(-_baseDirection.y, _baseDirection.x);

    _velocity = _baseDirection * _speed + perpendicular * wobbleValue;

    // 중앙 금지 영역 회피
    _avoidCenterZone();

    // 이동
    position += _velocity * dt;

    // 화면 밖으로 나갔으면 재진입
    if (_isOutOfScreen) {
      _initFlight();
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);
    if (!_isLoaded) return;

    canvas.save();

    // 오른쪽으로 이동 중이면 좌우 반전
    if (_velocity.x > 0) {
      canvas.translate(size.x, 0);
      canvas.scale(-1, 1);
    }

    final image = _frames[_currentFrame];
    final srcRect = Rect.fromLTWH(
      0,
      0,
      image.width.toDouble(),
      image.height.toDouble(),
    );
    final dstRect = Rect.fromLTWH(-size.x / 2, -size.y / 2, size.x, size.y);

    canvas.drawImageRect(image, srcRect, dstRect, Paint());
    canvas.restore();
  }
}
