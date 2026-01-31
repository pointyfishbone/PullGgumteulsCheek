import 'package:flutter/material.dart';
import 'package:gti_speaki/game/ggumteul_game.dart';
import 'package:gti_speaki/game/models/character_info.dart';

class InviteFriendPopup extends StatelessWidget {
  final GgumteulGame game;

  const InviteFriendPopup({super.key, required this.game});

  @override
  Widget build(BuildContext context) {
    final locked = game.lockedCharacters;

    return Align(
      alignment: FractionalOffset(0.5, 0.9),
      child: Material(
        color: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(maxWidth: 900),
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF3E2C23),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Invite a Friend!',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 28,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 24),
              Wrap(
                spacing: 16,
                runSpacing: 16,
                alignment: WrapAlignment.center,
                children: locked
                    .map(
                      (c) => _CharacterCard(
                        characterInfo: c,
                        onTap: () => _onSelectCharacter(c),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _onSelectCharacter(CharacterInfo character) {
    game.unlockCharacter(character.id);
    game.overlays.remove('inviteFriend');
  }
}

class _CharacterCard extends StatefulWidget {
  final CharacterInfo characterInfo;
  final VoidCallback onTap;

  const _CharacterCard({required this.characterInfo, required this.onTap});

  @override
  State<_CharacterCard> createState() => _CharacterCardState();
}

class _CharacterCardState extends State<_CharacterCard> {
  ImageProvider? _imageProvider;

  @override
  void initState() {
    super.initState();
    _loadImage();
  }

  Future<void> _loadImage() async {
    // Flame 이미지 캐시에서 에셋 경로를 직접 로드
    final assetPath = 'assets/images/${widget.characterInfo.assets.idle1}';
    final provider = AssetImage(assetPath);
    if (mounted) {
      setState(() => _imageProvider = provider);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: widget.onTap,
      child: Container(
        width: 120,
        height: 150,
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(borderRadius: BorderRadius.circular(8)),
              child: _imageProvider != null
                  ? Image(image: _imageProvider!, fit: BoxFit.contain)
                  : const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    ),
            ),
            const SizedBox(height: 8),
            Text(
              widget.characterInfo.name,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
