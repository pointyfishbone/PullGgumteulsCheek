import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:gti_speaki/game/ggumteul_game.dart';
import 'package:wakelock_plus/wakelock_plus.dart';

class SettingsHud extends StatefulWidget {
  final GgumteulGame game;

  const SettingsHud({super.key, required this.game});

  @override
  State<SettingsHud> createState() => _SettingsHudState();
}

class _SettingsHudState extends State<SettingsHud> {
  late bool _envValue;
  late bool _screenOnValue;

  @override
  void initState() {
    super.initState();
    _envValue = widget.game.isEnvVisible;
    _screenOnValue = widget.game.prefs.getBool('screenOn') ?? false;

    // 저장된 상태에 따라 wakelock 설정
    if (_screenOnValue) {
      WakelockPlus.enable();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.black.withValues(alpha: 0.5),
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        child: IntrinsicWidth(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Screen On 스위치
              if (Platform.isAndroid)
                Row(
                  mainAxisSize: MainAxisSize.max,
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    const Text(
                      'Screen On',
                      style: TextStyle(color: Colors.white),
                    ),
                    Switch(
                      value: _screenOnValue,
                      onChanged: (v) {
                        setState(() => _screenOnValue = v);
                        widget.game.prefs.setBool('screenOn', v);
                        if (v) {
                          WakelockPlus.enable();
                        } else {
                          WakelockPlus.disable();
                        }
                      },
                    ),
                  ],
                ),
              // Environment 스위치
              Row(
                mainAxisSize: MainAxisSize.max,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  const Text(
                    'Environment',
                    style: TextStyle(color: Colors.white),
                  ),
                  Switch(
                    value: _envValue,
                    onChanged: (v) {
                      setState(() => _envValue = v);
                      widget.game.toggleEnv(v);
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
