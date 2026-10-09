import 'package:flutter/material.dart';

import '../app_state.dart';
import '../hangul_pron.dart';
import '../models.dart';

/// 영어 아래에 붙이는 한글 발음 한 줄("해브 어 나이스 데이"). "한글 발음"을 끄면 안 보인다.
class PronText extends StatelessWidget {
  const PronText(this.english, {super.key, this.size = 14, this.textAlign});
  final String english; // `[표현|뜻]` 표시가 있어도 된다
  final double size;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([AppState.instance, HangulPron.instance]),
      builder: (context, _) {
        if (!AppState.instance.showPron) return const SizedBox.shrink();
        final pron = HangulPron.instance.sentence(plainText(english));
        if (pron.isEmpty) return const SizedBox.shrink();
        return Padding(
          padding: const EdgeInsets.only(top: 2),
          child: Text(
            pron,
            textAlign: textAlign,
            style: TextStyle(
              fontSize: size,
              height: 1.35,
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
            ),
          ),
        );
      },
    );
  }
}

/// "한글 발음" 체크 칸. 체크하면 영어 아래 한글 발음이 보이고, 해제하면 숨는다(모든 화면 공통, 저장됨).
class PronToggle extends StatelessWidget {
  const PronToggle({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final on = AppState.instance.showPron;
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: FilterChip(
            label: const Text('한글 발음'),
            selected: on,
            showCheckmark: true,
            visualDensity: VisualDensity.compact,
            tooltip: on ? '한글 발음 숨기기' : '한글 발음 보기',
            onSelected: AppState.instance.setShowPron,
          ),
        );
      },
    );
  }
}
