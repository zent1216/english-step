# 영어 한 걸음 (english_step)

한국인 성인을 위한 **완전 무료** 영어 학습 안드로이드 앱(Flutter).
돈을 벌려는 앱이 아니다. 광고, 구독, 수익화 장치는 넣지 않는다.

- 미리보기(웹 프로토타입, 화면 흐름 참고용): https://claude.ai/artifact/9owA7v3fc1kBs31iEJqcU4
- 저장소: **공개** `zent1216/english-step`(main 브랜치). 2026-10-09 leakcall 저장소의 `english_step/` 폴더에서 커밋 기록째 분리함
  (leakcall은 비공개 유지, 거기의 english_step 폴더·워크플로는 더 이상 안 씀).
- **배포(친구용 고정 링크, 로그인 불필요)**: https://github.com/zent1216/english-step/releases/latest/download/english_step.apk

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

## 디자인 방향 (2026-10-09 개편)
- 밝은 회색 바탕(#F4F5F8) + 흰 카드(둥근 20, 얇은 테두리) + 선명한 블루(#3E5BF2) 강조, **말하기는 코랄(#F2643E, tertiary)**,
  학습 포인트는 형광펜 노랑. 다크 모드도 같은 구조. 색·버튼·카드·하단탭·시트 스타일은 전부 `lib/theme.dart`에 모음
  (`AppColors` 확장: good=맞은 단어 초록, subtleBorder).
- 글꼴은 **전부 Pretendard**(한글 + Inter 기반 영문, Regular/Medium/SemiBold/Bold, SIL OFL). Literata(세리프)는
  "구닥다리 같다"는 피드백으로 제거. `englishFont`/`monoFont`도 Pretendard를 가리킨다(고정폭 글꼴은 기기마다 달라 안 씀).
- 홈: 큰 인사말 + 진도 요약 3칸 + 그라데이션 Lv.0 카드 + 레벨별 색 배지 이야기 카드.
- 화면 확인은 flutter test 골든 캡처로 했다(Pretendard·MaterialIcons를 FontLoader로 불러와 PNG로 찍음, 저장소엔 안 넣음).

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
- **GitHub Actions 자동 빌드**(`.github/workflows/apk.yml`): main에 푸시하면(.md만 바뀐 건 제외) analyze → test →
  release APK를 빌드해 `apk-latest` 릴리스(Latest)로 올린다. 빌드 번호 = 실행 번호 + 10(leakcall에서 10까지 빌드했으므로 이어서).
  - 고정 주소: https://github.com/zent1216/english-step/releases/latest/download/english_step.apk
  - 디스크가 빠듯해 debug APK는 빌드하지 않는다.
- **요즘 폰(arm64-v8a)만 지원** (대상: 갤럭시 A36, S25 등): build.gradle.kts의 `abiFilters`와 Actions의 `--target-platform android-arm64`로
  구형 32비트폰·x86 에뮬레이터용 코드를 뺐다(용량 절감). 에뮬레이터로 테스트하려면 arm64 이미지를 쓰거나 abiFilters를 잠시 풀 것.
- **서명 키 고정**: `android/app/ci-debug.keystore`(비밀번호 android, 테스트 전용)를 PC 빌드와 Actions 빌드가 같이 쓴다.
  그래서 어디서 빌드하든 폰에서 삭제 없이 업데이트된다. 이 키를 쓰기 전에 PC 기본 디버그 키로 설치한 앱은 한 번 삭제 후 설치해야 한다.
  Play 배포 시에는 별도 업로드 키를 만들어야 한다(이 키는 저장소에 커밋돼 있으므로 배포용으로 쓰지 말 것).
- 클라우드 환경은 Android SDK 다운로드 서버(dl.google.com)가 막혀 있어서 APK를 만들 수 없다. **PC 또는 Actions에서 빌드한다.**
- `cd english_step` → `flutter pub get` → `flutter run`, 또는 `flutter build apk --debug` → `adb install -r build\app\outputs\flutter-apk\app-debug.apk`
- 패키지 ID는 `com.facilitymanager.english_step`
- 오버레이를 쓰지 않으니 leakcall 같은 삼성 사이드로드 오버레이 차단 문제는 없다. 
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

## 따라 말하기 / 발음 체크 (2026-10-08 추가)
- 기기 내장 음성 인식(`speech_to_text: 7.4.0`, Flutter 3.41 호환 마지막 정식판)으로 사용자가 말한 문장을 받아,
  원문과 **단어 단위**로 비교(LCS, 대소문자·문장부호 무시)해 맞은 단어 초록 / 못 알아들은 단어 빨강 + 일치율(%)을 보여준다.
  AI 서버·비용 없음. 발음기호 단위 채점(ELSA식)이 아니라 "원어민(음성 인식)이 알아듣는가"를 본다.
- 코드: `lib/pronunciation.dart`(비교 로직, `test/pronunciation_test.dart`), `lib/widgets/speak_check_sheet.dart`
  (`SpeakCheckButton` 마이크 버튼, `ListenSpeakButtons` 듣기/말하기 글자 버튼 쌍, `showSpeakCheckSheet` 시트).
- **원칙: 듣기 버튼이 있는 곳엔 항상 말하기 버튼을 짝으로 둔다**(듣기 → 말하기 순서). 현재 위치:
  이야기 문장별·핵심 표현, Lv.0 문장 카드, 표현 뜻 시트, 단어장 목록·복습 카드, 팝송 가사 줄(누르면 노래 일시정지).
- **퀴즈 모드**(`quiz: true`): 영어를 숨기고 한국어 뜻만 보여준 채 말하게 한다. 결과가 나와야 정답 공개.
  - Lv.0 "말해보기" 모드: 카드를 열기 전 🎤는 퀴즈 모드.
  - 단어장 복습 "말해서 답하기"(말해보카 방식): 80% 이상 알아들으면 자동으로 '알아요', 아니면 정답을 보여주고 직접 고르게 한다.
- 권한: AndroidManifest에 `RECORD_AUDIO` + `<queries>`의 `android.speech.RecognitionService`. 권한 요청은 플러그인이 첫 사용 때 한다.
- 나중에: 내 목소리 녹음해서 원어민 음성과 번갈아 듣기(음성 인식과 동시에 마이크를 못 써서 별도 구현 필요).
- 클라우드 세션에서도 Flutter를 3.41.4로 맞춰 작업했다(pubspec.lock이 PC/Actions와 어긋나지 않게).

## 음성 인식 엔진: Moonshine (2026-10-09 교체)
- 폰 기본 음성 인식이 들쭉날쭉해서 **Moonshine v2 base(영어)**를 `sherpa_onnx: 1.13.8`로 폰 안에서 돌린다(오프라인, 무료).
  모델: sherpa-onnx 공식 배포 `asr-models/sherpa-onnx-moonshine-base-en-quantized-2026-02-27.tar.bz2`
  (받기 111MB → 풀면 encoder_model.ort 31MB + decoder_model_merged.ort 109MB + tokens.txt). 앱에 넣지 않고
  따라 말하기 시트의 "받기" 카드로 처음 한 번 받아 앱 전용 폴더(`getApplicationSupportDirectory()/asr`)에 푼다
  (압축 풀기는 `Isolate.run` + `archive` 패키지, 폰에서 수십 초). tiny(30MB)도 있지만 정확도 때문에 base 선택.
- 클라우드 리눅스에서 검증: 3.8초 음성 받아쓰기 0.16초, 모델 로딩 1.5초, 정확히 인식.
- 코드: `lib/speech/moonshine.dart`(받기/풀기/인식/WAV 저장, `MoonshineEngine` 싱글톤, main에서 `init()`),
  `lib/speech/recorder.dart`(`record` 패키지로 16kHz PCM 녹음, 말 끝나고 1.3초 조용하면 자동 정지, 최대 9초 —
  Moonshine v2가 10초 이상 음성에서 문제가 있었던 이력 때문).
- 모델을 받기 전/실패 시에는 기존 `speech_to_text`(폰 기본 인식)로 대신한다(시트 오른쪽 위 칩: Moonshine / 기본 인식).
- 녹음한 내 목소리를 `audioplayers`로 다시 듣기("내 목소리" 버튼).
- 패키지(Flutter 3.41 호환으로 고정): sherpa_onnx 1.13.8, record 6.2.1, audioplayers 6.7.1, path_provider 2.1.6, archive 4.0.9.
- 받아쓰기(decode)는 메인 isolate에서 돌아 짧게 화면이 멈출 수 있다(문장 길이 기준 1초 안팎 예상, 실기기 미측정).


## Google Play 내부 테스트 배포 (2026-10-09 준비)
- **결정(2026-10-09): Play 배포는 하지 않는다.** 친구 배포는 이 공개 저장소의 릴리스 링크로 한다(위 '빌드 / 실행').
  아래는 나중에 Play로 갈 때를 위한 준비 내용(서명 설정은 남겨둠).
- 서명: 직접 설치용 APK = `ci-debug.keystore`(테스트 키, 저장소에 있음). Play용 AAB = **업로드 키**(저장소에 없음).
  - `build.gradle.kts`가 `android/key.properties`(커밋 안 됨: storeFile, storePassword, keyAlias) 또는 환경변수
    `UPLOAD_KEYSTORE_PATH`/`UPLOAD_KEYSTORE_PASSWORD`에서 읽는다. `-PplayUpload`(flutter는
    `--android-project-arg=playUpload=true`)일 때만 업로드 키로 서명.
  - GitHub Actions: Secrets `UPLOAD_KEYSTORE_BASE64`(jks를 base64), `UPLOAD_KEYSTORE_PASSWORD`가 있으면
    AAB도 빌드해 `apk-latest` 릴리스에 `english_step.aab`로 올린다.
  - 업로드 키 비밀번호를 소스에 하드코딩하려다 자동 안전 검사에 막혔다 → 비밀값은 Secrets/key.properties로만.
- Play 앱 서명(Play App Signing)을 쓰므로 Play가 자기 키로 재서명한다. 그래서 **직접 설치한 앱과 Play 앱은 서명이
  달라** 같은 폰에서 바꿔 설치하려면 한 번 삭제해야 한다.
- 개인정보처리방침 원문: `PRIVACY.md` (공개 URL로 올려서 Play Console에 입력해야 함. 문의 이메일 채울 것).
- 마이크 사용 앱이라 Play Console의 데이터 보안 양식에 "오디오: 수집 안 함(기기 내 처리)"로 답한다.
- 첫 AAB는 Play Console에서 손으로 올려야 한다(Google 정책). 그 뒤 자동 업로드를 원하면 서비스 계정 JSON을 Secrets에 넣고
  업로드 단계를 추가할 것(아직 안 함).

## 새 버전 알림 (2026-10-09 추가)
- `lib/update_check.dart`: 앱 시작 때(첫 화면 뜬 뒤 1회) GitHub API `repos/zent1216/english-step/releases/latest`(키 없음)를
  읽어 릴리스 제목 "영어 한 걸음 (빌드 N)"의 N이 지금 빌드보다 크면 알림 창(업데이트 = APK 고정 링크 열기 / 릴리스 페이지 / 나중에).
  "나중에"를 누른 빌드는 다시 자동으로 묻지 않는다(SharedPreferences `skippedUpdateBuild`). 오프라인이면 조용히 넘어감.
- 지금 빌드 번호는 Actions가 `--dart-define=BUILD_NUMBER=N`으로 넣는다. PC에서 그냥 빌드하면 0 → 자동 확인 안 함(개발용 빌드).
  **릴리스 제목 형식("빌드 N")을 바꾸면 알림이 깨지니 같이 고칠 것.**
- 첫 화면 오른쪽 위 ⓘ → 앱 정보 시트: 빌드 번호, 업데이트 확인, 릴리스 페이지, 친구용 다운로드 링크 복사, 개인정보처리방침.
- 링크 열기는 `url_launcher: 6.3.3`(원래 유튜브 패키지가 쓰던 버전을 직접 의존성으로), AndroidManifest `<queries>`에 https VIEW 추가.
- 빌드 11·12(이 기능 전 APK)는 빌드 번호가 0으로 들어가 알림을 못 받는다. 한 번은 링크로 직접 받아 설치해야 한다.

## 채점 완화 + 천천히 말하기 + 문장별 점수 기억 (2026-10-09)
- 피드백: "제대로 말해도 빡빡하게 채점, 천천히 말하면 끊기거나 점수가 내려감".
- **관대한 채점**(`lib/pronunciation.dart`): 음성 인식의 표기 차이는 정답 처리 —
  같은 소리 다른 철자(for/four, to/two, no/know 등 `_homophones`), 숫자↔영어 숫자, 축약형↔풀어쓴 말
  (원문·인식 결과 **양쪽 다** `_contractions`로 풀어서 비교, 결과는 원문 단어에 표시).
  글자가 70% 이상 같은 단어(walk/walks)는 "비슷해요"(주황, 0.7점). 3글자 미만(a/in/on)은 정확해야 함.
  점수 기준: 85↑ 완벽(초록) / 65↑ 좋아요(주황) / 그 아래 빨강.
- **천천히 말하기**(`lib/speech/recorder.dart`): 말 끝 판정 2.2초 무음(기존 1.3초), 최대 20초(기존 9초),
  처음 0.3초 주변 소음으로 "말하는 중" 기준 자동 조정(작은 목소리도 잡힘).
- **받아쓰기 전 다듬기**(`lib/speech/audio_prep.dart`): 앞뒤 무음 제거, 0.3초 넘는 쉼은 0.25초로 줄임,
  8초 넘으면 조용한 곳 기준으로 나눠 받아쓰고 이어 붙임(Moonshine v2 긴 음성 문제 회피). 테스트 있음.
- **문장별 최고 점수 기억**(`AppState.speakScores`, SharedPreferences `speakScores`, 키 = `AppState.speakKey`):
  마이크 버튼이 100점이면 **초록 체크**, 그 외 점수가 있으면 작은 점수 배지(초록/주황/빨강). 시트에도 "이 문장 최고 기록" 표시.

## 끊어 읽기 대응 + 데이터 초기화 + 단어 발음 연습 (2026-10-09)
- **실험 결과**: Moonshine은 아주 천천히 *이어서* 말하면(0.5배) 정확하지만, 단어마다 끊어 읽으면 to→tear, meet→mate처럼 잘못 알아듣는다.
  - `MoonshineEngine.transcribeCandidates()`가 받아쓰기 후보 최대 4개(원본 / 다듬은 것 / 쉼을 바짝 붙인 `tightJoin` / 구간별 `wordSegments`)를
    만들고, 시트는 원문과 가장 잘 맞는 후보로 채점한다.
  - `looksWordByWord()`로 끊어 읽기를 감지해 점수가 85 미만이면 "끊지 말고 이어서 말해보세요" 안내 카드.
  - **자음 뼈대**(`consonantSkeleton`): 모음만 다른 경우(meet/mate, home/hum)는 "비슷해요"(0.7). 3글자 미만 단어(in/on)는 제외.
- **데이터가 안 지워지던 문제**: 안드로이드 자동 백업이 재설치 때 옛 데이터를 되살린 것으로 추정 → `allowBackup=false`,
  `res/xml/data_extraction_rules.xml`(클라우드 백업·기기 이전 모두 제외). 앱 정보 시트(ⓘ)에 "데이터 관리":
  말하기 점수 초기화 / 학습 기록 전체 초기화(`AppState.resetAll`) / 음성 인식 모델 다시 받기.
- **단어 발음 연습 시트**(`lib/widgets/word_practice_sheet.dart`, 말해보카 참고): 따라 말하기 결과의 빨간·주황 단어를 누르면 열림.
  열자마자 원어민 소리(보통/천천히), 큰 단어 + 뜻(ML Kit 기기 내 번역, 모델 없으면 "뜻 보기" 버튼), 나온 문장에서 단어 형광펜,
  **3번 따라 말하기** 점(70점 이상이면 하나씩 채움, 틀리면 천천히 다시 들려줌), 단어 옆 **단어장에 담기**.
  Moonshine이 없으면 마이크는 기존 따라 말하기 시트(폰 기본 인식)로 넘어간다.

## 단어 경계 인식 대응 (2026-10-09)
- 피드백: "Can I have an iced latte, please?"가 계속 다르게 인식됨.
- 실험(클라우드, 다화자 TTS libritts_r 등 6개 목소리 × 자연/천천히/끊어 읽기):
  - 대부분 문장은 Moonshine으로 100점. 문제는 **드문 단어 + 단어 경계**: "iced latte" → "a nice light day", "ice flight", "lite".
  - 다른 엔진도 시험했지만 Moonshine보다 못함: Zipformer 스트리밍 + 핫워드(목표 문장 편향), 키워드 검출(KWS), NeMo CTC.
    두 엔진 후보를 합쳐도 +1점 정도라 엔진 추가는 안 함. (저음질 TTS amy-low는 단어 하나만 말하면 뭉개져 실험용으로 부적합)
- 그래서 **채점 개선**(`lib/pronunciation.dart`):
  - 소리 열쇠(`consonantSkeleton`): gh 묵음, c(e/i/y 앞)→s, 유성·무성 같은 소리(b=p, d=t, g=k, v=f, z=s).
  - 정렬에 단어 경계 이동 추가: 원문 1↔들은 말 2(latte↔"la tay"), 2↔1, 2↔2("an iced"↔"a nice")를 이어 붙여 비교 → "비슷해요"(0.7).
    그중 한 쌍이라도 그대로 맞으면 경계 문제가 아니라고 보고 쓰지 않음("is in"↔"is on", "latte please"↔"tea please"는 그대로 틀림).

## 한글 발음 표기 (2026-10-09)
- 영어 아래에 "해브 어 나이스 데이"처럼 한글 발음을 적는다(`lib/hangul_pron.dart`, `lib/widgets/pron_text.dart`).
- **CMU 발음 사전**(카네기멜런대, BSD 라이선스) 12만 단어를 `assets/cmudict.txt.gz`(약 0.85MB)로 넣고, 앱 시작 때 백그라운드로 읽는다.
  라이선스 원문 `assets/cmudict-LICENSE.txt`는 main에서 `LicenseRegistry`에 등록(출처 표시 의무).
- 발음기호(ARPAbet) → 한글 규칙: 소리 나는 대로(meet → 미트, cat → 캣, please → 플리즈, where → 웨어, boats → 보츠, home → 홈, go → 고우).
  사전에 없는 단어(이름 등)는 철자 규칙으로 대충 읽는다. 어색한 흔한 단어는 `_overrides`(good → 굿 등)에 직접 적는다.
- **"한글 발음" 체크 칸**(`PronToggle`)으로 보이기/숨기기. 설정은 `AppState.showPron`(SharedPreferences `showPron`, 기본 켜짐), 모든 화면 공통.
  체크 칸 위치: 이야기 읽기·Lv.0 연습 위쪽 바, 팝송 연습 단계 줄, 앱 정보(ⓘ) 시트 스위치.
- 표시 위치: 이야기 문장, Lv.0 카드(영어가 보일 때만), 팝송 가사(정답이 보일 때만 — 빈칸 단계에서 답이 새지 않게),
  표현 뜻 시트, 단어장 목록·복습 카드, 따라 말하기 시트(퀴즈 모드는 결과 뒤), 단어 발음 연습 시트.

## 시끄러운 곳 모드 (2026-10-09)
- 갤럭시 S25처럼 마이크가 여러 개인 폰: 앱은 마이크를 직접 고르지 못하고 "녹음 종류"만 정한다. 마이크를 어떻게 쓸지는 폰이 정한다.
- 기본: `defaultSource` + 잡음 줄이기 + 자동 음량. **시끄러운 곳 모드**: `AndroidAudioSource.voiceCommunication`(통화용) + 에코 제거 →
  통화할 때처럼 여러 마이크로 주변 소음을 지운다. 조용한 곳에서는 목소리가 조금 뭉개질 수 있어 기본은 꺼짐.
- 설정 `AppState.noisyMode`(SharedPreferences `noisyMode`). 체크 칸 `NoisyToggle`(따라 말하기 시트, 단어 발음 연습 시트), ⓘ 시트 스위치.
  `TakeRecorder.record(noisy: ...)`로 전달. 실기기에서 효과 비교 필요(클라우드에서는 확인 불가).

## 약형 한글 표기 + 엔진 바꾸기 (2026-10-09)
- 피드백: "an이 언인데 앤으로 나옴", "latte가 라테이로 나옴", "latte를 잘 말해도 nothing으로 인식".
- 한글 발음: 문장 속 기능어는 약형(`_weakForms`: a 어, an 언, the 더/모음 앞 디, of 어브, to 투). 단어 하나만 있으면 원래 소리(an → 앤).
  latte/cafe 같은 외래어는 `_overrides`(라테, 카페).
- 음성 인식: 따라 말하기 시트 오른쪽 위 엔진 칩을 누르면 **Moonshine ↔ 폰 기본 인식(구글/삼성)** 전환(`AppState.usePhoneAsr`,
  SharedPreferences `usePhoneAsr`). 폰 기본 인식은 큰 어휘·언어 모델이라 latte 같은 단어에 강할 수 있다. 단어 연습 시트도 따른다.
- **근본 해결 후보(다음 단계)**: 단어로 받아쓰지 않고 **음소(발음기호) 단위로 인식**해 CMU 사전의 정답 발음과 비교(GOP 방식, ELSA류).
  후보 모델: wav2vec2 음소 인식 ONNX(buddy-pronunciation-onnx 영어 int8 약 357MB, ARPAbet, Apache-2.0 /
  speako-phoneme-recognizer 약 355MB, IPA / charsiu 프레임 분류 정렬기 약 123MB). sherpa-onnx로는 못 돌려서
  onnxruntime을 직접 써야 하고(sherpa_onnx의 libonnxruntime과 충돌 여부 확인 필요), 클라우드 세션에서 huggingface.co가 막혀 있어 시험 불가.
