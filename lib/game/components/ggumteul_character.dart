import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flutter/material.dart';

/// 꿈틀 캐릭터의 상태
enum GgumteulState {
  idle, // 유휴 상태
  cheekPulling, // 드래그 진행 중
  cheekReturn, // 드래그 종료 후 복귀 중
  afterCheekPull, // 복귀 완료 후 대기 상태
}

class GgumteulCharacter extends PositionComponent
    with DragCallbacks, HasGameReference<FlameGame> {
  // 상태별 이미지
  late ui.Image _imageIdle;
  late ui.Image _imageCheekPulling;
  late ui.Image _imageCheekReturn1; // ggumteul_03.png
  late ui.Image _imageCheekReturn2; // ggumteul_04.png
  bool _isLoaded = false;

  // cheekReturn 애니메이션
  static const double cheekReturnAnimInterval = 0.12; // 이미지 전환 간격 (초)
  double _cheekReturnAnimTimer = 0.0;
  bool _cheekReturnAnimFrame = false; // false: 03, true: 04

  // 떨림 효과
  final math.Random _random = math.Random();
  final Vector2 _shakeOffset = Vector2.zero();
  static const double shakeIntensity = 3.0; // 떨림 강도 (픽셀)

  // 이미지 원본 크기
  static const double originalWidth = 2700;
  static const double originalHeight = 2700;

  // 볼따구 위치 (원본 이미지 기준)
  static const double cheekX = 2500;
  static const double cheekY = 1500;

  // 화면에 표시될 크기 (스케일 조정)
  late double displayScale;
  late double displayWidth;
  late double displayHeight;

  // 볼따구 위치 (화면 기준)
  late Vector2 cheekPosition;

  // 상태 머신
  GgumteulState _state = GgumteulState.idle;
  GgumteulState get state => _state;

  // 상태 타이머
  static const double cheekReturnTime = 1.5; // cheekReturn 상태 지속 시간 (초)
  static const double afterCheekPullTime = 0.8; // afterCheekPull 상태 지속 시간 (초)
  double _cheekReturnTimer = 0.0;
  double _afterCheekPullTimer = 0.0;

  // 드래그 관련
  Vector2 rawDragOffset = Vector2.zero(); // 실제 드래그 위치 (클램프 없이)
  Vector2 currentDragOffset = Vector2.zero(); // 클램프된 위치 (렌더링용)
  double maxDragDistance = 0;

  // 드래그 가능 각도 범위 (라디안)
  static const double angleRangeStart = -math.pi / 9; // -20도
  static const double angleRangeEnd = math.pi / 9; // +20도

  // 스프링 물리 (오버슛이 있는 빠른 복귀)
  Vector2 velocity = Vector2.zero();
  static const double springStiffness = 1300.0; // 스프링 강성 (높을수록 빠름)
  static const double damping = 30.0; // 감쇠 (낮을수록 오버슛 큼)

  // 볼따구 당김 횟수 카운터
  int pullCount = 0;

  /// 현재 상태에 맞는 이미지 반환
  ui.Image get _currentImage {
    switch (_state) {
      case GgumteulState.idle:
        return _imageIdle;
      case GgumteulState.cheekPulling:
        return _imageCheekPulling;
      case GgumteulState.cheekReturn:
        return _cheekReturnAnimFrame ? _imageCheekReturn2 : _imageCheekReturn1;
      case GgumteulState.afterCheekPull:
        return _imageCheekReturn1; // ggumteul_03.png
    }
  }

  @override
  Future<void> onLoad() async {
    await super.onLoad();

    // 상태별 이미지 로드
    _imageIdle = await _loadImage('assets/images/ggumteul/ggumteul_01.png');
    _imageCheekPulling = await _loadImage(
      'assets/images/ggumteul/ggumteul_07.png',
    );
    _imageCheekReturn1 = await _loadImage(
      'assets/images/ggumteul/ggumteul_03.png',
    );
    _imageCheekReturn2 = await _loadImage(
      'assets/images/ggumteul/ggumteul_04.png',
    );
    _isLoaded = true;

    // 화면 크기에 맞게 스케일 조정 (화면의 80% 크기로)
    final screenSize = game.size;
    final targetSize = math.min(screenSize.x, screenSize.y) * 0.8;
    displayScale = targetSize / originalHeight;
    displayWidth = originalWidth * displayScale;
    displayHeight = originalHeight * displayScale;

    // 컴포넌트 크기 설정
    size = Vector2(displayWidth, displayHeight);

    // 화면 중앙에 배치
    position = Vector2(
      (screenSize.x - displayWidth) / 2,
      (screenSize.y - displayHeight) / 2,
    );

    // 볼따구 위치 계산 (화면 기준)
    cheekPosition = Vector2(cheekX * displayScale, cheekY * displayScale);

    // 최대 드래그 거리 (이미지 가로 길이의 25%)
    maxDragDistance = displayWidth * 0.25;
  }

  Future<ui.Image> _loadImage(String path) async {
    final data = await game.images.load(path.replaceAll('assets/images/', ''));
    return data;
  }

  @override
  void update(double dt) {
    super.update(dt);

    switch (_state) {
      case GgumteulState.idle:
        // 유휴 상태에서는 떨림 없음
        _shakeOffset.setZero();
        break;

      case GgumteulState.cheekPulling:
        // 부들부들 떨림 효과
        _shakeOffset.setValues(
          (_random.nextDouble() - 0.5) * 2 * shakeIntensity,
          (_random.nextDouble() - 0.5) * 2 * shakeIntensity,
        );
        break;

      case GgumteulState.cheekReturn:
        // 복귀 상태에서는 떨림 없음
        _shakeOffset.setZero();

        // 이미지 애니메이션 (0.25초마다 전환)
        _cheekReturnAnimTimer += dt;
        if (_cheekReturnAnimTimer >= cheekReturnAnimInterval) {
          _cheekReturnAnimTimer -= cheekReturnAnimInterval;
          _cheekReturnAnimFrame = !_cheekReturnAnimFrame;
        }

        // 스프링 물리 적용
        if (currentDragOffset.length > 0.01) {
          // 스프링 힘: F = -k * x
          final springForce = currentDragOffset * -springStiffness;

          // 감쇠력: F = -c * v
          final dampingForce = velocity * -damping;

          // 총 가속도
          final acceleration = springForce + dampingForce;

          // 속도 및 위치 업데이트
          velocity += acceleration * dt;
          currentDragOffset += velocity * dt;

          // 충분히 작아지면 정지
          if (currentDragOffset.length < 0.5 && velocity.length < 1.0) {
            currentDragOffset = Vector2.zero();
            velocity = Vector2.zero();
          }
        }

        // 2초 후 afterCheekPull로 전이
        _cheekReturnTimer += dt;
        if (_cheekReturnTimer >= cheekReturnTime) {
          _state = GgumteulState.afterCheekPull;
          _cheekReturnTimer = 0.0;
          _afterCheekPullTimer = 0.0;
        }
        break;

      case GgumteulState.afterCheekPull:
        // 떨림 없음
        _shakeOffset.setZero();

        // 2초 후 idle로 전이
        _afterCheekPullTimer += dt;
        if (_afterCheekPullTimer >= afterCheekPullTime) {
          _state = GgumteulState.idle;
          _afterCheekPullTimer = 0.0;
        }
        break;
    }
  }

  @override
  void onDragStart(DragStartEvent event) {
    super.onDragStart(event);

    // 볼따구 근처를 클릭했는지 확인
    final localPos = event.localPosition;
    final distanceFromCheek = (localPos - cheekPosition).length;

    if (distanceFromCheek < 200 * displayScale) {
      _state = GgumteulState.cheekPulling;
      rawDragOffset = currentDragOffset.clone(); // 현재 위치에서 시작
      velocity = Vector2.zero(); // 속도 초기화
    }
  }

  @override
  void onDragUpdate(DragUpdateEvent event) {
    super.onDragUpdate(event);

    if (_state != GgumteulState.cheekPulling) return;

    // 실제 드래그 위치 누적 (클램프 없이)
    rawDragOffset += event.localDelta;

    // 실제 위치를 기반으로 클램프된 위치 계산
    currentDragOffset = _clampToAllowedRegion(rawDragOffset);
  }

  /// 드래그 위치를 허용된 영역(부채꼴)으로 클램프
  Vector2 _clampToAllowedRegion(Vector2 offset) {
    // 오른쪽 방향으로만 드래그 허용 (x > 0)
    if (offset.x <= 0) {
      return Vector2.zero();
    }

    // 드래그 각도 계산
    final angle = math.atan2(offset.y, offset.x);
    final distance = offset.length;

    if (angle >= angleRangeStart && angle <= angleRangeEnd) {
      // 각도가 범위 내: 거리만 클램프
      if (distance > maxDragDistance) {
        return offset.normalized() * maxDragDistance;
      } else {
        return offset.clone();
      }
    } else {
      // 각도가 범위 밖: 원점에서 드래그 위치까지의 선과 경계선의 교점 계산
      final boundaryAngle = angle < angleRangeStart
          ? angleRangeStart
          : angleRangeEnd;
      final boundaryDir = Vector2(
        math.cos(boundaryAngle),
        math.sin(boundaryAngle),
      );

      // 드래그 벡터를 경계선 방향에 투영
      final projection = offset.dot(boundaryDir);

      if (projection <= 0) {
        // 반대 방향이면 이동 없음
        return Vector2.zero();
      } else {
        // 투영된 거리를 최대 거리로 클램프
        final clampedProjection = math.min(projection, maxDragDistance);
        return boundaryDir * clampedProjection;
      }
    }
  }

  @override
  void onDragEnd(DragEndEvent event) {
    super.onDragEnd(event);

    if (_state == GgumteulState.cheekPulling) {
      rawDragOffset = Vector2.zero(); // 실제 드래그 위치 초기화

      // 최대 범위의 20% 이상 당겼는지 확인
      if (currentDragOffset.length >= maxDragDistance * 0.2) {
        // 충분히 당겼으면 cheekReturn으로 전이
        _state = GgumteulState.cheekReturn;
        _cheekReturnTimer = 0.0; // 상태 타이머 초기화
        _cheekReturnAnimTimer = 0.0; // 애니메이션 타이머 초기화
        _cheekReturnAnimFrame = false; // 첫 번째 프레임부터 시작
        // 스프링 복귀는 update()에서 자동으로 처리됨
        // 당김 횟수 카운터 증가
        pullCount++;
      } else {
        // 충분히 당기지 않았으면 바로 idle로 복귀
        _state = GgumteulState.idle;
        currentDragOffset = Vector2.zero();
        velocity = Vector2.zero();
      }
    }
  }

  @override
  void render(Canvas canvas) {
    super.render(canvas);

    if (!_isLoaded) return;

    // 떨림 오프셋 적용
    canvas.save();
    canvas.translate(_shakeOffset.x, _shakeOffset.y);

    if (currentDragOffset.length < 0.1) {
      // 드래그하지 않을 때는 일반 이미지 렌더링
      canvas.drawImageRect(
        _currentImage,
        Rect.fromLTWH(0, 0, originalWidth, originalHeight),
        Rect.fromLTWH(0, 0, displayWidth, displayHeight),
        Paint(),
      );
    } else {
      // 드래그 중일 때는 메시 변형 적용
      _renderWithMeshDeform(canvas);
    }

    canvas.restore();
  }

  void _renderWithMeshDeform(Canvas canvas) {
    const int gridWidth = 20;
    const int gridHeight = 20;

    final vertices = <Offset>[];
    final textureCoordinates = <Offset>[];
    final indices = <int>[];

    // 드래그 영향 반경
    final influenceRadius = displayWidth * 0.3;

    for (int y = 0; y <= gridHeight; y++) {
      for (int x = 0; x <= gridWidth; x++) {
        final tx = x / gridWidth;
        final ty = y / gridHeight;

        var vertexX = tx * displayWidth;
        var vertexY = ty * displayHeight;

        // 볼따구로부터의 거리 계산
        final dx = vertexX - cheekPosition.x;
        final dy = vertexY - cheekPosition.y;
        final distance = math.sqrt(dx * dx + dy * dy);

        // 거리에 따른 영향도 계산 (가까울수록 강하게)
        if (distance < influenceRadius) {
          final influence = 1.0 - (distance / influenceRadius);
          final deformFactor = influence * influence; // 비선형 감쇠

          vertexX += currentDragOffset.x * deformFactor;
          vertexY += currentDragOffset.y * deformFactor;
        }

        vertices.add(Offset(vertexX, vertexY));
        textureCoordinates.add(Offset(tx * originalWidth, ty * originalHeight));
      }
    }

    // 인덱스 생성 (삼각형 메시)
    for (int y = 0; y < gridHeight; y++) {
      for (int x = 0; x < gridWidth; x++) {
        final topLeft = y * (gridWidth + 1) + x;
        final topRight = topLeft + 1;
        final bottomLeft = (y + 1) * (gridWidth + 1) + x;
        final bottomRight = bottomLeft + 1;

        // 첫 번째 삼각형
        indices.addAll([topLeft, bottomLeft, topRight]);
        // 두 번째 삼각형
        indices.addAll([topRight, bottomLeft, bottomRight]);
      }
    }

    // Vertices 객체 생성 및 렌더링
    final verticesObj = ui.Vertices.raw(
      ui.VertexMode.triangles,
      Float32List.fromList(vertices.expand((v) => [v.dx, v.dy]).toList()),
      textureCoordinates: Float32List.fromList(
        textureCoordinates.expand((v) => [v.dx, v.dy]).toList(),
      ),
      indices: Uint16List.fromList(indices),
    );

    final identityMatrix = Float64List(16)
      ..[0] = 1.0
      ..[5] = 1.0
      ..[10] = 1.0
      ..[15] = 1.0;

    canvas.drawVertices(
      verticesObj,
      BlendMode.srcOver,
      Paint()
        ..shader = ui.ImageShader(
          _currentImage,
          TileMode.clamp,
          TileMode.clamp,
          identityMatrix,
        ),
    );
  }
}
