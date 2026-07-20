import 'package:flutter/material.dart';

import '../../../app/settings_controller.dart';
import '../../theme/app_theme.dart';
import 'theme_section.dart' show SettingToggleCard;

/// Audio settings: audio boost + auto speakerphone toggles.
class AudioSection extends StatelessWidget {
  const AudioSection({super.key, required this.state, required this.onChanged});

  final SettingsState state;
  final ValueChanged<SettingsState> onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        SettingToggleCard(
          icon: Icons.graphic_eq,
          title: 'Khuếch đại âm thanh',
          description:
              'Tự động tăng âm lượng cuộc gọi để cải thiện độ chính xác.',
          checked: state.audioBoost,
          onChanged: (v) => onChanged(state.copyWith(audioBoost: v)),
        ),
        const SizedBox(height: AppSpacing.sm),
        SettingToggleCard(
          icon: Icons.speaker_phone,
          title: 'Tự bật loa ngoài',
          description:
              'Bật loa ngoài khi bắt đầu giám sát để tăng khả năng thu tiếng.',
          checked: state.autoEnableSpeakerphone,
          onChanged: (v) =>
              onChanged(state.copyWith(autoEnableSpeakerphone: v)),
        ),
      ],
    );
  }
}
