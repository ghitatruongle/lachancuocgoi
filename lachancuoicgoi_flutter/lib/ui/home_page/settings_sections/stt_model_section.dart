import 'package:flutter/material.dart';

import '../../../app/settings_controller.dart';
import 'theme_section.dart' show SettingToggleCard;

/// STT model size selection toggle (small vs full Vosk model).
class SttModelSection extends StatelessWidget {
  const SttModelSection({
    super.key,
    required this.state,
    required this.onChanged,
  });

  final SettingsState state;
  final ValueChanged<SettingsState> onChanged;

  @override
  Widget build(BuildContext context) {
    return SettingToggleCard(
      icon: Icons.memory,
      title: 'Model STT nhỏ',
      description: state.useSmallSttModel
          ? 'Dùng model nhận diện giọng nói nhỏ (nhanh hơn, ít RAM hơn).'
          : 'Dùng model nhận diện giọng nói đầy đủ (chính xác hơn).',
      checked: state.useSmallSttModel,
      onChanged: (v) => onChanged(state.copyWith(useSmallSttModel: v)),
    );
  }
}
