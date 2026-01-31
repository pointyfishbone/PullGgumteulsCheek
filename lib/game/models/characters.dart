import 'character_info.dart';

/// 미리 정의된 캐릭터 목록
class Characters {
  Characters._();

  /// 꿈틀이 캐릭터
  static const ggumteul = CharacterInfo(
    id: 'ggumteul',
    name: '꿈틀',
    assets: CharacterAssets(
      idle1: 'ggumteul/ggumteul_01.png',
      idle2: 'ggumteul/ggumteul_02.png',
      return1: 'ggumteul/ggumteul_03.png',
      return2: 'ggumteul/ggumteul_04.png',
      pulling: 'ggumteul/ggumteul_07.png',
    ),
    audio: CharacterAudioInfo(
      idle1: AudioInfo('ggumteul/idle1.wav', Duration(milliseconds: 2159)),
      idle2: AudioInfo('ggumteul/idle2.wav', Duration(milliseconds: 1621)),
      return1: AudioInfo('ggumteul/return1.wav', Duration(milliseconds: 869)),
    ),
    imageMeta: CharacterImageMeta(
      width: 900,
      height: 900,
      cheekX: 833.33,
      cheekY: 500,
      deformCenterX: 873.33,
      deformCenterY: 482.67,
    ),
  );

  /// 미르 캐릭터
  static const mir = CharacterInfo(
    id: 'mir',
    name: '미르',
    assets: CharacterAssets(
      idle1: 'mir/mir_1.png',
      idle2: 'mir/mir_2.png',
      return1: 'mir/mir_3.png',
      return2: 'mir/mir_4.png',
      pulling: 'mir/mir_7.png',
    ),
    audio: CharacterAudioInfo(
      idle1: AudioInfo('mir/idle1.wav', Duration(milliseconds: 10886)),
      idle2: AudioInfo('mir/idle2.wav', Duration(milliseconds: 12919)),
      return1: AudioInfo('mir/return1.wav', Duration(milliseconds: 4074)),
    ),
    imageMeta: CharacterImageMeta(
      width: 900,
      height: 900,
      cheekX: 833.33,
      cheekY: 500,
      deformCenterX: 873.33,
      deformCenterY: 482.67,
    ),
  );

  /// 이제 캐릭터 (임시: 꿈틀이 에셋 사용)
  static const eze = CharacterInfo(
    id: 'eze',
    name: '윤이제',
    assets: CharacterAssets(
      idle1: 'ggumteul/ggumteul_01.png',
      idle2: 'ggumteul/ggumteul_02.png',
      return1: 'ggumteul/ggumteul_03.png',
      return2: 'ggumteul/ggumteul_04.png',
      pulling: 'ggumteul/ggumteul_07.png',
    ),
    audio: CharacterAudioInfo(
      idle1: AudioInfo('ggumteul/idle1.wav', Duration(milliseconds: 2159)),
      idle2: AudioInfo('ggumteul/idle2.wav', Duration(milliseconds: 1621)),
      return1: AudioInfo('ggumteul/return1.wav', Duration(milliseconds: 869)),
    ),
    imageMeta: CharacterImageMeta(
      width: 900,
      height: 900,
      cheekX: 833.33,
      cheekY: 500,
      deformCenterX: 873.33,
      deformCenterY: 482.67,
    ),
  );

  /// 마로니 캐릭터 (임시: 꿈틀이 에셋 사용)
  static const marronie = CharacterInfo(
    id: 'marronie',
    name: '마로니',
    assets: CharacterAssets(
      idle1: 'ggumteul/ggumteul_01.png',
      idle2: 'ggumteul/ggumteul_02.png',
      return1: 'ggumteul/ggumteul_03.png',
      return2: 'ggumteul/ggumteul_04.png',
      pulling: 'ggumteul/ggumteul_07.png',
    ),
    audio: CharacterAudioInfo(
      idle1: AudioInfo('ggumteul/idle1.wav', Duration(milliseconds: 2159)),
      idle2: AudioInfo('ggumteul/idle2.wav', Duration(milliseconds: 1621)),
      return1: AudioInfo('ggumteul/return1.wav', Duration(milliseconds: 869)),
    ),
    imageMeta: CharacterImageMeta(
      width: 900,
      height: 900,
      cheekX: 833.33,
      cheekY: 500,
      deformCenterX: 873.33,
      deformCenterY: 482.67,
    ),
  );

  /// 모든 캐릭터 목록
  static const List<CharacterInfo> all = [ggumteul, mir, eze, marronie];

  /// 기본 캐릭터
  static const CharacterInfo defaultCharacter = ggumteul;

  /// ID로 캐릭터 찾기
  static CharacterInfo? findById(String id) {
    for (final character in all) {
      if (character.id == id) {
        return character;
      }
    }
    return null;
  }
}
