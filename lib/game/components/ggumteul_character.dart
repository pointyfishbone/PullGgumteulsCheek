import 'dart:async' as async;
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flame/components.dart';
import 'package:flame/events.dart';
import 'package:flame/game.dart';
import 'package:flame_audio/flame_audio.dart';
import 'package:flutter/material.dart';
import 'package:gti_speaki/game/ggumteul_game.dart';

/// 오디오 파일 정보 (파일 이름에서 재생 시간 포함)
class AudioInfo {
  final String fileName;
  final Duration duration;

  const AudioInfo(this.fileName, this.duration);
}

/// 오디오 에셋 정보
class GgumteulAudio {
  static const idleAudio1 = AudioInfo(
    'ggumteul/idle1.wav',
    Duration(milliseconds: 2159),
  );
  static const idleAudio2 = AudioInfo(
    'ggumteul/idle2.wav',
    Duration(milliseconds: 1621),
  );
  static const returnAudio1 = AudioInfo(
    'ggumteul/return1.wav',
    Duration(milliseconds: 869),
  );

  static List<String> get allFiles => [
    idleAudio1.fileName,
    idleAudio2.fileName,
    returnAudio1.fileName,
  ];
}

/// 꿈틀 캐릭터의 상태
enum GgumteulState {
  idle, // 유휴 상태
  cheekPulling, // 드래그 진행 중
  cheekReturn, // 드래그 종료 후 복귀 중
  afterCheekPull, // 복귀 완료 후 대기 상태
}

class GgumteulCharacter extends PositionComponent
    with DragCallbacks, HasGameReference<FlameGame> {
  GgumteulCharacter({required this.game});

  @override
  final GgumteulGame game;

  // 상태별 이미지
  late ui.Image _imageIdle1; // ggumteul_01.png
  late ui.Image _imageIdle2; // ggumteul_02.png
  late ui.Image _imageCheekPulling;
  late ui.Image _imageCheekReturn1; // ggumteul_03.png
  late ui.Image _imageCheekReturn2; // ggumteul_04.png
  bool _isLoaded = false;

  // idle 오디오 관련
  static const double idleAudioIntervalMin = 3.0; // 최소 대기 시간 (초)
  static const double idleAudioIntervalMax = 8.0; // 최대 대기 시간 (초)
  static const double idleAnimInterval = 0.12; // 이미지 전환 간격 (초, 120ms)
  double _idleAudioIntervalTimer = 0.0;
  double _nextIdleAudioTime = 0.0;
  bool _isPlayingIdleAudio = false;
  double _idleAnimTimer = 0.0;
  bool _idleAnimFrame = false; // false: 01, true: 02
  async.Timer? _idleAudioTimer; // idle 오디오 완료 감지 타이머
  async.Timer? _returnAudioTimer; // returnAudio 완료 감지 타이머
  AudioPlayer? _idleAudioPlayer; // idle 오디오 플레이어 (중지용)
  AudioPlayer? _returnAudioPlayer; // returnAudio 플레이어 (중지용)

  // cheekReturn 애니메이션
  static const double cheekReturnAnimInterval = 0.12; // 이미지 전환 간격 (초)
  double _cheekReturnAnimTimer = 0.0;
  bool _cheekReturnAnimFrame = false; // false: 03, true: 04

  // 떨림 효과
  final math.Random _random = math.Random();
  final Vector2 _shakeOffset = Vector2.zero();
  static const double shakeIntensity = 3.0; // 떨림 강도 (픽셀)

  // 이미지 원본 크기
  static const double originalWidth = 900;
  static const double originalHeight = 900;

  // 볼따구 위치 - 드래그 감지용 (원본 이미지 기준)
  static const double cheekX = 833.33;
  static const double cheekY = 500;

  // 메시 변형 중심점 (원본 이미지 기준)
  static const double deformCenterX = 873.33;
  static const double deformCenterY = 482.67;

  // 화면에 표시될 크기 (스케일 조정)
  late double displayScale;
  late double displayWidth;
  late double displayHeight;

  // 볼따구 위치 (화면 기준) - 드래그 감지용
  late Vector2 cheekPosition;
  // 메시 변형 중심점 (화면 기준)
  late Vector2 deformCenter;

  // 상태 머신
  GgumteulState _state = GgumteulState.idle;
  GgumteulState get state => _state;

  // 상태 타이머
  static const double afterCheekPullTime = 0.8; // afterCheekPull 상태 지속 시간 (초)
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
  static const double maxPhysicsDt = 0.016; // 물리 시뮬레이션 최대 dt (약 60fps)
  static const double maxDivergenceDistance =
      2.0; // 발산 감지 배수 (maxDragDistance 기준)

  // 메시 변형 최적화 (미리 할당)
  static const int meshGridSize = 20; // 그리드 크기
  static const int meshVertexCount = (meshGridSize + 1) * (meshGridSize + 1);
  static const int meshIndexCount = meshGridSize * meshGridSize * 6;
  late Float32List _meshVertices;
  late Float32List _meshTexCoords;
  late Uint16List _meshIndices;
  late Float64List _identityMatrix;
  late double _meshInfluenceRadius;

  // 볼따구 당김 횟수 카운터
  int pullCount = 0;

  /// 현재 상태에 맞는 이미지 반환
  ui.Image get _currentImage {
    switch (_state) {
      case GgumteulState.idle:
        // 오디오 재생 중이면 애니메이션 프레임 사용
        if (_isPlayingIdleAudio) {
          return _idleAnimFrame ? _imageIdle2 : _imageIdle1;
        }
        return _imageIdle1;
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

    // pullCount 로드
    pullCount = game.prefs.getInt('pullCount') ?? 0;

    // 상태별 이미지 로드
    _imageIdle1 = await _loadImage('assets/images/ggumteul/ggumteul_01.png');
    _imageIdle2 = await _loadImage('assets/images/ggumteul/ggumteul_02.png');
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

    // 오디오 프리로드 (lowLatency 모드를 위해 미리 로드)
    await FlameAudio.audioCache.loadAll(GgumteulAudio.allFiles);

    // idle 오디오 타이머 초기화 (3~8초 랜덤)
    _nextIdleAudioTime =
        _random.nextDouble() * (idleAudioIntervalMax - idleAudioIntervalMin) +
        idleAudioIntervalMin;

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

    // 볼따구 위치 계산 (화면 기준) - 드래그 감지용
    cheekPosition = Vector2(cheekX * displayScale, cheekY * displayScale);
    // 메시 변형 중심점 계산 (화면 기준)
    deformCenter = Vector2(
      deformCenterX * displayScale,
      deformCenterY * displayScale,
    );

    // 최대 드래그 거리 (이미지 가로 길이의 25%)
    maxDragDistance = displayWidth * 0.25;

    // 메시 데이터 미리 할당
    _initMeshData();
  }

  /// 메시 데이터 초기화 (성능 최적화)
  void _initMeshData() {
    _meshVertices = Float32List(meshVertexCount * 2);
    _meshTexCoords = Float32List(meshVertexCount * 2);
    _meshIndices = Uint16List(meshIndexCount);
    _meshInfluenceRadius = displayWidth * 0.3;

    // Identity matrix 캐시
    _identityMatrix = Float64List(16);
    _identityMatrix[0] = 1.0;
    _identityMatrix[5] = 1.0;
    _identityMatrix[10] = 1.0;
    _identityMatrix[15] = 1.0;

    // 텍스처 좌표와 인덱스는 변하지 않으므로 미리 계산
    int vertexIdx = 0;
    for (int y = 0; y <= meshGridSize; y++) {
      for (int x = 0; x <= meshGridSize; x++) {
        final tx = x / meshGridSize;
        final ty = y / meshGridSize;
        _meshTexCoords[vertexIdx] = tx * originalWidth;
        _meshTexCoords[vertexIdx + 1] = ty * originalHeight;
        vertexIdx += 2;
      }
    }

    // 인덱스 미리 계산
    int indexIdx = 0;
    for (int y = 0; y < meshGridSize; y++) {
      for (int x = 0; x < meshGridSize; x++) {
        final topLeft = y * (meshGridSize + 1) + x;
        final topRight = topLeft + 1;
        final bottomLeft = (y + 1) * (meshGridSize + 1) + x;
        final bottomRight = bottomLeft + 1;

        _meshIndices[indexIdx++] = topLeft;
        _meshIndices[indexIdx++] = bottomLeft;
        _meshIndices[indexIdx++] = topRight;
        _meshIndices[indexIdx++] = topRight;
        _meshIndices[indexIdx++] = bottomLeft;
        _meshIndices[indexIdx++] = bottomRight;
      }
    }
  }

  Future<ui.Image> _loadImage(String path) async {
    final data = await game.images.load(path.replaceAll('assets/images/', ''));
    return data;
  }

  /// 랜덤 idle 오디오 재생 (lowLatency 모드 + 타이머 기반 완료 감지)
  void _playRandomIdleAudio() async {
    _isPlayingIdleAudio = true;
    _idleAnimTimer = 0.0;
    _idleAnimFrame = false;

    // idle1 또는 idle2 중 랜덤 선택
    final audio = _random.nextBool()
        ? GgumteulAudio.idleAudio1
        : GgumteulAudio.idleAudio2;

    // lowLatency 모드로 재생 (프리로드된 오디오 사용)
    _idleAudioPlayer = await FlameAudio.play(audio.fileName);

    // 파일 이름에 기록된 재생 시간으로 완료 감지
    _idleAudioTimer = async.Timer(audio.duration, _onIdleAudioComplete);
  }

  /// idle 오디오 중지
  void _stopIdleAudio() {
    _idleAudioTimer?.cancel();
    _idleAudioTimer = null;
    _idleAudioPlayer?.stop();
    _idleAudioPlayer = null;
    _isPlayingIdleAudio = false;
    _idleAnimFrame = false;
    _idleAudioIntervalTimer = 0.0;
  }

  /// idle 오디오 재생 완료 시 호출
  void _onIdleAudioComplete() {
    _idleAudioTimer = null;
    _idleAudioPlayer = null;
    _isPlayingIdleAudio = false;
    _idleAnimFrame = false;
    // 다음 오디오 재생까지의 시간 설정 (3~8초 랜덤)
    _nextIdleAudioTime =
        _random.nextDouble() * (idleAudioIntervalMax - idleAudioIntervalMin) +
        idleAudioIntervalMin;
  }

  /// returnAudio 오디오 재생 (볼 당기기 성공 시, lowLatency 모드)
  void _playReturnAudio() async {
    _stopReturnAudio(); // 기존 타이머 및 오디오 중지

    // lowLatency 모드로 재생
    _returnAudioPlayer = await FlameAudio.play(
      GgumteulAudio.returnAudio1.fileName,
    );

    // 파일 이름에 기록된 재생 시간으로 완료 감지
    _returnAudioTimer = async.Timer(
      GgumteulAudio.returnAudio1.duration,
      _onReturnAudioComplete,
    );
  }

  /// returnAudio 중지
  void _stopReturnAudio() {
    _returnAudioTimer?.cancel();
    _returnAudioTimer = null;
    _returnAudioPlayer?.stop();
    _returnAudioPlayer = null;
  }

  /// returnAudio 재생 완료 시 호출
  void _onReturnAudioComplete() {
    _returnAudioTimer = null;
    _returnAudioPlayer = null;
    // cheekReturn 상태에서 returnAudio가 끝나면 afterCheekPull로 전이
    if (_state == GgumteulState.cheekReturn) {
      _state = GgumteulState.afterCheekPull;
      _afterCheekPullTimer = 0.0;
    }
  }

  @override
  void update(double dt) {
    super.update(dt);

    switch (_state) {
      case GgumteulState.idle:
        // 유휴 상태에서는 떨림 없음
        _shakeOffset.setZero();

        if (_isPlayingIdleAudio) {
          // 오디오 재생 중: 이미지 애니메이션 (120ms 간격)
          _idleAnimTimer += dt;
          if (_idleAnimTimer >= idleAnimInterval) {
            _idleAnimTimer -= idleAnimInterval;
            _idleAnimFrame = !_idleAnimFrame;
          }
        } else {
          // 오디오 미재생: 타이머 체크
          _idleAudioIntervalTimer += dt;
          if (_idleAudioIntervalTimer >= _nextIdleAudioTime) {
            _idleAudioIntervalTimer = 0.0;
            _playRandomIdleAudio();
          }
        }
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

        // 스프링 물리 적용 (sub-stepping으로 안정성 확보)
        if (currentDragOffset.length > 0.01) {
          // Sub-stepping: dt가 크면 여러 번 나눠서 계산
          double remainingDt = dt;
          while (remainingDt > 0) {
            final stepDt = math.min(remainingDt, maxPhysicsDt);
            remainingDt -= stepDt;

            // 스프링 힘: F = -k * x
            final springForce = currentDragOffset * -springStiffness;

            // 감쇠력: F = -c * v
            final dampingForce = velocity * -damping;

            // 총 가속도
            final acceleration = springForce + dampingForce;

            // Semi-implicit Euler: 속도 먼저 업데이트 후 위치 업데이트 (더 안정적)
            velocity += acceleration * stepDt;
            currentDragOffset += velocity * stepDt;
          }

          // 발산 감지: 원래 드래그 거리보다 훨씬 멀어지면 리셋
          if (currentDragOffset.length >
              maxDragDistance * maxDivergenceDistance) {
            currentDragOffset = Vector2.zero();
            velocity = Vector2.zero();
          }

          // 충분히 작아지면 정지
          if (currentDragOffset.length < 0.5 && velocity.length < 1.0) {
            currentDragOffset = Vector2.zero();
            velocity = Vector2.zero();
          }
        }
        // afterCheekPull로의 전이는 returnAudio 완료 시 _onReturnAudioComplete()에서 처리
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
      // 오디오 중지
      _stopIdleAudio();
      _stopReturnAudio();

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
        _cheekReturnAnimTimer = 0.0; // 애니메이션 타이머 초기화
        _cheekReturnAnimFrame = false; // 첫 번째 프레임부터 시작
        // 스프링 복귀는 update()에서 자동으로 처리됨
        // 당김 횟수 카운터 증가
        pullCount++;
        game.prefs.setInt('pullCount', pullCount);
        // returnAudio 재생
        _playReturnAudio();
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
    // 정점 위치만 매 프레임 업데이트 (텍스처 좌표와 인덱스는 캐시됨)
    int vertexIdx = 0;
    for (int y = 0; y <= meshGridSize; y++) {
      for (int x = 0; x <= meshGridSize; x++) {
        final tx = x / meshGridSize;
        final ty = y / meshGridSize;

        var vertexX = tx * displayWidth;
        var vertexY = ty * displayHeight;

        // 메시 변형 중심점으로부터의 거리 계산
        final dx = vertexX - deformCenter.x;
        final dy = vertexY - deformCenter.y;
        final distanceSq = dx * dx + dy * dy;
        final influenceRadiusSq = _meshInfluenceRadius * _meshInfluenceRadius;

        // 거리에 따른 영향도 계산 (가까울수록 강하게)
        if (distanceSq < influenceRadiusSq) {
          final distance = math.sqrt(distanceSq);
          final influence = 1.0 - (distance / _meshInfluenceRadius);
          final deformFactor = influence * influence; // 비선형 감쇠

          vertexX += currentDragOffset.x * deformFactor;
          vertexY += currentDragOffset.y * deformFactor;
        }

        _meshVertices[vertexIdx] = vertexX;
        _meshVertices[vertexIdx + 1] = vertexY;
        vertexIdx += 2;
      }
    }

    // Vertices 객체 생성 (캐시된 배열 사용)
    final verticesObj = ui.Vertices.raw(
      ui.VertexMode.triangles,
      _meshVertices,
      textureCoordinates: _meshTexCoords,
      indices: _meshIndices,
    );

    canvas.drawVertices(
      verticesObj,
      BlendMode.srcOver,
      Paint()
        ..shader = ui.ImageShader(
          _currentImage,
          TileMode.clamp,
          TileMode.clamp,
          _identityMatrix,
        ),
    );
  }
}
