# 영어 한 걸음 (english_step)

한국인 성인을 위한 **완전 무료** 영어 학습 안드로이드 앱(Flutter).
돈을 벌려는 앱이 아니다. 광고, 구독, 수익화 장치는 넣지 않는다.

- 미리보기(웹 프로토타입, 화면 흐름 참고용): https://claude.ai/artifact/9owA7v3fc1kBs31iEJqcU4
- 브랜치: `english-study` (leakcall 저장소 안의 `english_step/` 폴더. 나중에 별도 저장소로 분리 예정)

## 기획 배경과 결정 사항 (바꾸지 말 것)

- **잠금화면이나 오버레이로 학습시키는 방식은 쓰지 않는다.** 사용자가 직접 써봤는데 효율이 극히 낮았다.
- **수익화는 고려하지 않는다.** 그래서 운영 비용이 0원에 가까운 구조로 만든다.
  - 이야기 콘텐츠는 미리 만들어 앱에 넣는다(서버 호출 없음, 오프라인 동작).
  - 음성은 기기 내장 TTS(`flutter_tts`)를 쓴다.
  - 저장은 기기 안(`shared_preferences`)에만 한다. 로그인이나 서버는 없다.
- **팝송 가사는 앱에 넣어 배포하지 않는다(저작권).** 사용자가 직접 붙여넣는다. 데모 곡 "Paper Boats"는 직접 지은 가사다.

## 시장 조사 요약 (2026-10)

| 유형 | 대표 앱 | 참고할 점 |
|---|---|---|
| 게임형 | 듀오링고 | 습관 장치는 좋지만 말하기가 약하다. Max는 월 30달러 |
| AI 회화 | Speak, Langua, Praktika, 말해보카 | 대부분 유료. AI 서버 비용 때문에 무료로 하기 어렵다 |
| 이해 가능한 입력 | Dreaming Spanish, LingQ, Satori Reader | 수준보다 살짝 어려운 콘텐츠를 많이 접하게 한다. **영어판 Dreaming Spanish가 없다** |
| 영상·자막 | Language Reactor, Trancy, Lingopie, 케이크 | Language Reactor는 PC 전용이고 보기만 하는 수동적 학습 |
| 오픈소스 | Enjoy App (GitHub 별 3.6만+) | 아무 오디오·영상으로 문장 단위 따라 말하기. PC 위주 |

**빈틈:** 한국인 초·중급자가 모바일에서 무료로, 수준에 맞는 영어 입력을 받고 따라 말하는 앱이 마땅치 않다.

## 기능 명세

하단 탭 3개로 구성한다: **이야기 / 팝송 연습 / 단어장**

### 1. 이야기 (수준별 짧은 영어 이야기)
- 목록: 레벨(1 입문 ~ 4 중상급), 제목, 한국어 제목, 문장 수, 핵심 표현, 완료 여부를 보여준다.
- 읽기 화면
  - `[표현|뜻]`으로 표시된 학습 포인트는 노란 형광펜 밑줄로 보여준다. 누르면 뜻이 담긴 바텀시트가 뜨고, 바텀시트에서 듣기와 "단어장에 담기"를 할 수 있다.
  - 문장 번호를 누르면 그 문장의 한국어 해석이 보인다. "해석 모두 보기" 토글도 둔다.
  - 문장별 듣기 버튼과 "전체 듣기"(재생 중인 문장 강조)를 둔다. 속도는 0.6~1.2배.
  - 끝에 이해 확인 퀴즈가 있다. 맞히면 핵심 표현 카드(듣기, 단어장에 담기)가 나오고 완료 처리한다.
- 나중에 넣을 것
  - 수준 테스트로 시작 레벨을 정한다.
  - 누른 표현 수를 보고 다음 이야기 난이도를 자동 조절한다.
  - `speech_to_text`로 따라 말하기와 발음 비교를 넣는다.
  - 이야기를 수백 편으로 늘린다(AI로 생성한 뒤 검수해서 앱에 포함).

### 2. 팝송 연습 (사용자 요청 기능)
- 위에는 유튜브 영상(`youtube_player_iframe`), 아래에는 가사를 보여준다.
- **속도:** 0.5 / 0.75 / 0.9 / 1 / 1.25배 (`controller.setPlaybackRate`)
- **한 줄 반복:** 현재 소절의 시작부터 다음 소절 시작 직전까지 계속 반복한다. 가사 줄을 누르면 그 줄로 이동하고, 이전 줄/다음 줄 버튼도 둔다.
- **연습 4단계:** 가사 전체 → 빈칸 채우기(단어를 하나 걸러 빈칸, 누르면 정답) → 첫 글자만(`w____`) → 가사 숨기기(해석만 보고 부르기)
- **해석 보기** 토글을 둔다.
- **노래 찾기(기본):** 제목을 검색하면 LRCLIB(lrclib.net, 키 없음)에서 시간 정보가 붙은 가사(LRC)를, `youtube_explode_dart`(키 없음)로 유튜브 영상을 찾는다. 영상은 가사 곡 길이와 비슷하고 제목에 lyrics/audio가 들어간 것을 우선, 공식 MV·반주·커버·강좌·라이브는 뒤로 미룬다(`lib/song_search.dart`). 가사는 앱에 넣지 않고 검색할 때 받아온다.
- **직접 입력:** 제목, 유튜브 주소, 가사를 붙여넣는다. 한 줄에 한 소절이고 해석은 ` | ` 뒤에 쓴다. 처음에는 4초 간격으로 임시 타이밍을 넣는다.
- **싱크 조절(±0.5/1초)과 다른 영상 찾기:** 연습 화면 메뉴. 영상 앞부분 길이 차이로 가사가 밀릴 때 쓴다.
- **타이밍 맞추기:** 처음부터 재생하면서 각 소절이 시작될 때마다 큰 버튼을 누르면, 그 시각을 저장한다(`synced=true`).
- 유튜브 영상이 없으면(데모 곡) 가상 시계로 가사만 진행한다(속도도 적용).
- 재생 위치는 100~200ms 간격 타이머로 `controller.currentTime`을 읽어 현재 소절을 계산한다.
- 주의: 공식 뮤직비디오 중에는 **외부 재생(임베드)이 막힌 영상이 많다.** 재생 오류가 나면 "이 영상은 앱에서 재생할 수 없어요. 가사 영상이나 다른 업로드를 찾아보세요"처럼 안내한다.
- 나중에 넣을 것
  - 로컬 음악 파일 재생(`just_audio` + 파일 선택).
  - LRC 형식(노래방 가사 형식) 가져오기와 내보내기.
  - 따라 부르기 녹음.

### 3. 단어장
- 이야기와 팝송에서 담은 표현을 모은다(표현, 뜻, 나온 문장).
- **복습 카드:** 앞면은 표현, "뜻 보기"를 누르면 뒷면이 나온다. 그다음 "알아요" 또는 "아직 헷갈려요"를 고른다.
  - 간격 반복(`reviewIntervalsDays = [0,1,3,7,14,30]`일): 알면 다음 칸으로 넘어가고, 헷갈리면 box 0으로 돌아가 10분 뒤 다시 나온다.
  - 오늘 복습할 개수를 보여준다.
- 전체 목록에서 듣기와 삭제를 할 수 있다.

## 디자인 방향 (프로토타입 기준)
- 차분한 청회색 바탕에 잉크 블루 강조색, 학습 포인트는 **형광펜 노랑**.
- 영어 본문은 **Literata**(전자책용 세리프), 한국어 UI는 **Pretendard**, 시간·숫자는 고정폭. 두 글꼴 모두 `assets/fonts`에 포함(SIL OFL, 라이선스 파일 동봉). Literata는 라틴 글자만 있어 한글은 Pretendard로 대체 표시.
- 라이트/다크 모드를 둘 다 지원한다. 현재 재생 중인 줄은 연한 노랑으로 강조한다.

## 코드 구조와 진행 상태

| 파일 | 상태 | 내용 |
|---|---|---|
| `lib/models.dart` | 완료 | Story/Sentence/Quiz/Song/LyricLine/VocabItem, `parseMarked`(학습 포인트 파싱), `plainText`, `parseYoutubeId`, `parseLyrics` |
| `lib/content.dart` | 완료 | 이야기 4편(coffee/late/package/no), `demoSong()` |
| `lib/app_state.dart` | 완료 | `AppState` 싱글톤(ChangeNotifier): 단어장, 내 노래, 완료한 이야기, 음성 속도를 SharedPreferences에 저장. `Speaker`(flutter_tts 래퍼) |
| `lib/main.dart` | 완료 | 앱 시작 시 `AppState.instance.load()`, 라이트/다크 테마, 하단 탭 3개(단어장 탭에 오늘 복습 개수 배지) |
| `lib/theme.dart` | 완료 | 색(청회색/잉크 블루/형광펜 노랑), `englishStyle`(기기 기본 세리프), `markerColor`, `currentLineColor` |
| `lib/widgets/marked_text.dart` | 완료 | `MarkedText`(형광펜 + 탭 → 뜻 바텀시트), `showGlossSheet`, `showSpeechRateSheet`(0.6~1.2배) |
| `lib/screens/story_*` | 완료 | 목록(레벨/문장 수/핵심 표현/완료), 읽기(번호 탭 → 해석, 해석 모두 보기, 문장별/전체 듣기, 퀴즈 → 핵심 표현 카드) |
| `lib/screens/song_*` | 완료 | 목록(데모 + 내 노래, 수정/삭제), 추가·수정(소절 수가 같으면 타이밍 유지), 연습(유튜브/가상 시계, 속도, 한 줄 반복, 이전/다음 줄, 4단계, 해석, 타이밍 맞추기, 임베드 차단 시 "가사만 보기") |
| `lib/screens/vocab_screen.dart` | 완료 | 오늘 복습 개수, 복습 카드(헷갈린 표현은 이번 복습 끝에 한 번 더), 전체 목록(듣기/삭제 + 되돌리기) |
| `test/` | 완료 | models 파서·JSON·콘텐츠 형식 단위 테스트 + 위젯 테스트(퀴즈 완료, 단어장 담기, 데모 곡 빈칸/재생) |

상태 관리는 별도 패키지 없이 `AppState.instance`와 `ListenableBuilder`로 처리한다.

## 패키지 (버전 고정)
- `youtube_player_iframe: 6.0.2` (Flutter 3.38 이상 필요)
- `flutter_tts: 4.2.5` — **Android/iOS는 0.5가 보통 속도**다. 그래서 `Speaker.speak`에서 사용자 속도에 0.5를 곱한다(웹은 그대로).
- `shared_preferences: 2.5.5`
- 클라우드 환경에서 만들 때 Flutter 3.47.6 / Dart 3.13.5를 썼다. 집 PC는 Flutter 3.41.4 / Dart 3.11이라
  pubspec의 SDK 조건을 `^3.11.0`으로 낮췄다(새 버전 전용 문법은 안 씀).

## 빌드 / 실행 (PC에서)
- **GitHub Actions 자동 빌드**(`.github/workflows/english_step_apk.yml`): `english-study` 브랜치에
  `english_step/` 변경을 푸시하면 analyze → test → release·debug APK를 빌드한다. GitHub 저장소 →
  Actions → 해당 실행 → Artifacts에서 zip을 받아 `app-release.apk`를 설치한다. 빌드 번호 = 실행 번호(자동 증가).
- **서명 키 고정**: `android/app/ci-debug.keystore`(비밀번호 android, 테스트 전용)를 PC 빌드와 Actions 빌드가 같이 쓴다.
  그래서 어디서 빌드하든 폰에서 삭제 없이 업데이트된다. 이 키를 쓰기 전에 PC 기본 디버그 키로 설치한 앱은 한 번 삭제 후 설치해야 한다.
  Play 배포 시에는 별도 업로드 키를 만들어야 한다(이 키는 저장소에 커밋돼 있으므로 배포용으로 쓰지 말 것).
- 클라우드 환경은 Android SDK 다운로드 서버(dl.google.com)가 막혀 있어서 APK를 만들 수 없다. **PC 또는 Actions에서 빌드한다.**
- `cd english_step` → `flutter pub get` → `flutter run`, 또는 `flutter build apk --debug` → `adb install -r build\app\outputs\flutter-apk\app-debug.apk`
- 패키지 ID는 `com.facilitymanager.english_step`
- 오버레이를 쓰지 않으니 leakcall 같은 삼성 사이드로드 오버레이 차단 문제는 없다. 그래도 Play 배포가 필요하면 leakcall의 내부 테스트 절차(루트 CLAUDE.md)를 참고한다.
- 유튜브 재생에는 인터넷 권한(`android.permission.INTERNET`)이 필요하다. 릴리스 빌드에서는 AndroidManifest에 명시해야 한다.

- 웹 미리보기: 저장소 루트 `.claude/launch.json`의 `english_step-web`(flutter run -d web-server, 포트 8765).
  웹(CanvasKit)에는 'serif' 글꼴이 없어 영어 본문이 고딕으로 보인다. 안드로이드에서는 Noto Serif로 나온다.

## 다음 할 일 (순서대로)
1. ~~main.dart, 학습 포인트 위젯, 이야기/팝송/단어장 화면, 테스트~~ (2026-10-08 완료, analyze 0건, 테스트 13개 통과)
2. 폰에 설치해서 테스트 → 피드백 반영 (특히 유튜브 재생, TTS, 타이밍 맞추기는 실기기 확인 필요)
3. (선택) 별도 저장소로 분리, Play 내부 테스트로 배포

## Lv.0 첫걸음 문장 (2026-10-08 추가)
- 기존 이야기 4편(`content.dart`)은 이전 세션에서 AI가 직접 쓴 것이라 Lv.1부터 초보자에게 어려웠다. 그 아래 단계로 추가.
- 데이터: `assets/tatoeba_lv0.json` (200문장, 10개씩 20세트). **Tatoeba(tatoeba.org) 영어-한국어 쌍, CC BY 2.0 FR** → 앱 안에 출처 표시 필수(세트 목록 하단 + 문장별 `src`).
- 만드는 법: Tatoeba 공식 내보내기(`downloads.tatoeba.org/exports/per_language/kor/kor-eng_links.tsv.bz2`, `kor_sentences_detailed`, `eng/eng_sentences_detailed`)를 받아
  영어 200만 문장 기준 빈도 상위 1,000단어로만 된 3~7단어 문장을 고르고(이름·숫자·영어 섞인 해석 제외, 첫 두 단어 같은 문장 최대 3개),
  쉬운 순으로 260개 후보를 뽑아 **사람이 검수**해 번역이 어긋난 31쌍을 빼고 200개를 썼다. (ManyThings.org의 kor-eng.zip은 자동 다운로드가 막혀 있음)
- 화면: 이야기 탭 맨 위 카드 → 세트 목록(`sentence_screens.dart`) → 연습("듣고 이해": 영어→해석 / "말해보기": 해석→영어, 정답 열면 자동 읽기), 문장을 단어장에 담기.
- 다음 후보: StoryWeaver(CC BY 4.0, 레벨별 짧은 이야기), VOA Learning English(퍼블릭 도메인, 중급), NGSL(CC BY-SA, 난이도 기준표).

## 가사 해석 자동 채우기 (2026-10-08 추가)
- LRCLIB 가사는 영어만 있다. 연습 화면의 "해석 자동 채우기" 칩 → **구글 ML Kit 기기 내 번역**(`google_mlkit_translation: 0.14.0`, `lib/translate.dart`).
  무료·오프라인(처음 한 번 영어/한국어 모델 약 60MB 다운로드). 서버형 AI 번역은 호출 비용 때문에 쓰지 않는다(운영비 0원 원칙).
- 직역 위주라 가사 비유는 어색할 수 있음 → 노래 수정 화면에서 직접 고칠 수 있다. 안드로이드/iOS에서만 동작(웹 미지원).
