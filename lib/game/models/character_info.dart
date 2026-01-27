/// 오디오 파일 정보 (파일 이름과 재생 시간)
class AudioInfo {
  final String fileName;
  final Duration duration;

  const AudioInfo(this.fileName, this.duration);
}

/// 캐릭터 이미지 에셋 정보
class CharacterAssets {
  final String idle1; // 기본 상태 이미지 1
  final String idle2; // 기본 상태 이미지 2 (애니메이션)
  final String return1; // 복귀 상태 이미지 1
  final String return2; // 복귀 상태 이미지 2 (애니메이션)
  final String pulling; // 당기는 중 이미지

  const CharacterAssets({
    required this.idle1,
    required this.idle2,
    required this.return1,
    required this.return2,
    required this.pulling,
  });

  /// 모든 이미지 파일 목록 (프리로드용)
  List<String> get allFiles => [idle1, idle2, return1, return2, pulling];
}

/// 캐릭터 오디오 에셋 정보
class CharacterAudioInfo {
  final AudioInfo idle1;
  final AudioInfo idle2;
  final AudioInfo return1;

  const CharacterAudioInfo({
    required this.idle1,
    required this.idle2,
    required this.return1,
  });

  /// 모든 오디오 파일 목록 (프리로드용)
  List<String> get allFiles => [
        idle1.fileName,
        idle2.fileName,
        return1.fileName,
      ];
}

/// 캐릭터 이미지 메타데이터 (크기, 위치 정보)
class CharacterImageMeta {
  final double width; // 이미지 원본 가로 크기
  final double height; // 이미지 원본 세로 크기
  final double cheekX; // 볼따구 위치 X (드래그 감지용)
  final double cheekY; // 볼따구 위치 Y (드래그 감지용)
  final double deformCenterX; // 메시 변형 중심점 X
  final double deformCenterY; // 메시 변형 중심점 Y

  const CharacterImageMeta({
    required this.width,
    required this.height,
    required this.cheekX,
    required this.cheekY,
    required this.deformCenterX,
    required this.deformCenterY,
  });
}

/// 캐릭터 정보 클래스
class CharacterInfo {
  final String id; // 캐릭터 고유 ID (저장용)
  final String name; // 표시 이름
  final CharacterAssets assets; // 이미지 에셋
  final CharacterAudioInfo audio; // 오디오 에셋
  final CharacterImageMeta imageMeta; // 이미지 메타데이터

  const CharacterInfo({
    required this.id,
    required this.name,
    required this.assets,
    required this.audio,
    required this.imageMeta,
  });
}
