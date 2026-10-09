/// 새 버전 알림. 공개 저장소의 최신 릴리스(GitHub API, 키 없음)를 보고 지금 빌드보다 새로우면 알린다.
///
/// 지금 빌드 번호는 Actions가 `--dart-define=BUILD_NUMBER=N`으로 넣어준다.
/// PC에서 그냥 빌드하면 0이라 자동 확인은 하지 않는다(개발용 빌드).
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_state.dart';
import 'speech/moonshine.dart';

const _repo = 'zent1216/english-step';
const releasesPageUrl = 'https://github.com/$_repo/releases';
const apkDownloadUrl = 'https://github.com/$_repo/releases/latest/download/english_step.apk';
const privacyUrl = 'https://github.com/$_repo/blob/main/PRIVACY.md';
const currentBuild = int.fromEnvironment('BUILD_NUMBER');

class ReleaseInfo {
  const ReleaseInfo({required this.build, required this.title, required this.notes, required this.pageUrl});
  final int build;
  final String title;
  final String notes;
  final String pageUrl;
}

/// 릴리스 제목 "영어 한 걸음 (빌드 23)"에서 빌드 번호를 뽑는다.
int? parseBuildNumber(String title) {
  final m = RegExp(r'빌드\s*(\d+)').firstMatch(title);
  return m == null ? null : int.parse(m.group(1)!);
}

Future<ReleaseInfo?> fetchLatestRelease() async {
  final res = await http.get(
    Uri.parse('https://api.github.com/repos/$_repo/releases/latest'),
    headers: {'Accept': 'application/vnd.github+json'},
  ).timeout(const Duration(seconds: 8));
  if (res.statusCode != 200) return null;
  final j = jsonDecode(res.body) as Map<String, dynamic>;
  final title = (j['name'] as String?) ?? '';
  final build = parseBuildNumber(title);
  if (build == null) return null;
  return ReleaseInfo(
    build: build,
    title: title,
    notes: (j['body'] as String?) ?? '',
    pageUrl: (j['html_url'] as String?) ?? releasesPageUrl,
  );
}

Future<void> openExternal(String url) =>
    launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);

const _skipKey = 'skippedUpdateBuild';

/// 앱 시작 때 한 번. 새 버전이 있고, 그 버전을 "나중에"로 넘기지 않았으면 알림 창을 띄운다.
Future<void> autoCheckForUpdate(BuildContext context) async {
  if (currentBuild == 0) return;
  try {
    final latest = await fetchLatestRelease();
    if (latest == null || latest.build <= currentBuild) return;
    final prefs = await SharedPreferences.getInstance();
    if (prefs.getInt(_skipKey) == latest.build) return;
    if (!context.mounted) return;
    final later = await showUpdateDialog(context, latest);
    if (later) await prefs.setInt(_skipKey, latest.build);
  } catch (_) {
    // 오프라인 등은 조용히 넘어간다.
  }
}

/// 새 버전 알림 창. "나중에"를 누르면 true.
Future<bool> showUpdateDialog(BuildContext context, ReleaseInfo info) async {
  final later = await showDialog<bool>(
    context: context,
    builder: (context) {
      final text = Theme.of(context).textTheme;
      final scheme = Theme.of(context).colorScheme;
      return AlertDialog(
        icon: Icon(Icons.system_update_rounded, color: scheme.primary, size: 32),
        title: const Text('새 버전이 나왔어요'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('빌드 $currentBuild → 빌드 ${info.build}', style: text.titleSmall),
            const SizedBox(height: 8),
            Text(
              '[업데이트]를 누르면 새 APK를 받아요. 받은 파일을 눌러 설치하면 '
              '단어장과 진도는 그대로 남아요.',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            TextButton.icon(
              style: TextButton.styleFrom(padding: EdgeInsets.zero),
              icon: const Icon(Icons.open_in_new_rounded, size: 18),
              label: const Text('릴리스 페이지에서 자세히 보기'),
              onPressed: () => openExternal(info.pageUrl),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, true), child: const Text('나중에')),
          FilledButton(
            onPressed: () {
              openExternal(apkDownloadUrl);
              Navigator.pop(context, false);
            },
            child: const Text('업데이트'),
          ),
        ],
      );
    },
  );
  return later ?? true;
}

/// 앱 정보: 지금 버전, 업데이트 확인, 릴리스 페이지, 친구에게 줄 링크.
Future<void> showAppInfoSheet(BuildContext context) => showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _AppInfoSheet(),
    );

class _AppInfoSheet extends StatefulWidget {
  const _AppInfoSheet();

  @override
  State<_AppInfoSheet> createState() => _AppInfoSheetState();
}

class _AppInfoSheetState extends State<_AppInfoSheet> {
  bool _checking = false;
  String? _status;

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _status = null;
    });
    try {
      final latest = await fetchLatestRelease();
      if (!mounted) return;
      if (latest == null) {
        setState(() => _status = '최신 버전 정보를 가져오지 못했어요.');
      } else if (currentBuild != 0 && latest.build <= currentBuild) {
        setState(() => _status = '최신 버전이에요 (빌드 $currentBuild).');
      } else {
        setState(() => _status = null);
        await showUpdateDialog(context, latest);
      }
    } catch (_) {
      if (mounted) setState(() => _status = '인터넷 연결을 확인해주세요.');
    } finally {
      if (mounted) setState(() => _checking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('영어 한 걸음', style: text.titleLarge),
            const SizedBox(height: 2),
            Text(
              currentBuild == 0 ? '개발용 빌드' : '빌드 $currentBuild',
              style: text.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              icon: _checking
                  ? const SizedBox(
                      width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.system_update_rounded),
              label: const Text('업데이트 확인'),
              onPressed: _checking ? null : _check,
            ),
            if (_status != null) ...[
              const SizedBox(height: 8),
              Text(_status!, textAlign: TextAlign.center, style: text.bodyMedium),
            ],
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new_rounded),
              label: const Text('릴리스 페이지 열기'),
              onPressed: () => openExternal(releasesPageUrl),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              icon: const Icon(Icons.link_rounded),
              label: const Text('친구에게 줄 다운로드 링크 복사'),
              onPressed: () async {
                await Clipboard.setData(const ClipboardData(text: apkDownloadUrl));
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('다운로드 링크를 복사했어요')),
                  );
                }
              },
            ),
            const SizedBox(height: 8),
            ListenableBuilder(
              listenable: AppState.instance,
              builder: (context, _) => SwitchListTile(
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                secondary: const Icon(Icons.translate_rounded),
                title: const Text('한글 발음 보기'),
                subtitle: const Text('영어 아래에 "해브 어 나이스 데이"처럼 적어줘요'),
                value: AppState.instance.showPron,
                onChanged: AppState.instance.setShowPron,
              ),
            ),
            const SizedBox(height: 8),
            Text('데이터 관리', style: text.titleSmall),
            const SizedBox(height: 4),
            Text('이 폰 안에만 저장돼요. 앱을 지우면 함께 지워져요.',
                style: text.bodySmall?.copyWith(color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            _ResetTile(
              icon: Icons.mic_off_rounded,
              title: '말하기 점수 초기화',
              detail: '문장별 최고 점수와 초록 체크를 지워요.',
              confirm: '말하기 점수를 모두 지울까요?',
              action: () => AppState.instance.resetSpeakScores(),
            ),
            _ResetTile(
              icon: Icons.restart_alt_rounded,
              title: '학습 기록 전체 초기화',
              detail: '단어장, 내 노래, 진도, 점수, 설정을 모두 지워요.',
              confirm: '단어장·내 노래·진도·점수를 모두 지울까요? 되돌릴 수 없어요.',
              action: () => AppState.instance.resetAll(),
            ),
            _ResetTile(
              icon: Icons.download_for_offline_rounded,
              title: '음성 인식 모델 다시 받기',
              detail: '받아둔 Moonshine 모델(약 140MB)을 지워요. 따라 말하기에서 다시 받을 수 있어요.',
              confirm: '음성 인식 모델을 지울까요?',
              action: () => MoonshineEngine.instance.deleteModel(),
            ),
            const SizedBox(height: 4),
            TextButton(
              onPressed: () => openExternal(privacyUrl),
              child: const Text('개인정보처리방침'),
            ),
            TextButton(
              onPressed: () => showLicensePage(context: context, applicationName: '영어 한 걸음'),
              child: const Text('오픈소스 라이선스 (발음 사전·글꼴 등)'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ResetTile extends StatelessWidget {
  const _ResetTile({
    required this.icon,
    required this.title,
    required this.detail,
    required this.confirm,
    required this.action,
  });
  final IconData icon;
  final String title;
  final String detail;
  final String confirm;
  final Future<void> Function() action;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4),
      leading: Icon(icon, color: scheme.error),
      title: Text(title),
      subtitle: Text(detail),
      onTap: () async {
        final ok = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(confirm),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('취소')),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: scheme.error, foregroundColor: scheme.onError),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('지우기'),
              ),
            ],
          ),
        );
        if (ok != true) return;
        await action();
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$title 완료')));
        }
      },
    );
  }
}
