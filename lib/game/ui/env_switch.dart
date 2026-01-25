import 'package:flutter/material.dart';
import 'package:gti_speaki/game/ggumteul_game.dart';

class EnvSwitch extends StatefulWidget {
  final GgumteulGame game;

  const EnvSwitch({super.key, required this.game});

  @override
  State<EnvSwitch> createState() => _EnvSwitchState();
}

class _EnvSwitchState extends State<EnvSwitch> {
  late bool _value;

  @override
  void initState() {
    super.initState();
    _value = widget.game.isEnvVisible;
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Environment', style: TextStyle(color: Colors.white)),
            Switch(
              value: _value,
              onChanged: (v) {
                setState(() => _value = v);
                widget.game.toggleEnv(v);
              },
            ),
          ],
        ),
      ),
    );
  }
}
