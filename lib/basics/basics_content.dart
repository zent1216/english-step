/// 기초 탭: 영어 문장의 뼈대(어순)를 색깔 칸으로 익힌다.
///
/// 문장 = [앞말] [도우미] [누가] [한다] [무엇을] [덧붙임]
/// 외우는 대신 칸에 조각 카드를 끼워 보며 "앞에 무엇이 오면 뒤가 어떻게 되는지"를 몸에 익힌다.
/// 조각 표기: "칸:글자" 를 | 로 이어 쓴다. 칸 = q 앞말, h 도우미, w 누가, a 한다, o 무엇을, m 덧붙임.
/// 헷갈리는 오답 조각: "칸:글자~틀린 이유".
library;

enum Slot { q, h, w, a, o, m }

extension SlotInfo on Slot {
  String get label => switch (this) {
    Slot.q => '앞말',
    Slot.h => '도우미',
    Slot.w => '누가',
    Slot.a => '한다',
    Slot.o => '무엇을',
    Slot.m => '덧붙임',
  };
  String get help => switch (this) {
    Slot.q => 'What·Where·How·Because처럼 맨 앞에서 문장의 방향을 정하는 말',
    Slot.h => 'do·does·can·is·are처럼 질문·부정을 만들어 주는 말',
    Slot.w => '문장의 주인공(I, you, she, my phone…)',
    Slot.a => '하는 일·상태(like, drink, am, is…)',
    Slot.o => '무엇을·누구를·무엇(coffee, me, a teacher…)',
    Slot.m => '빼도 되는 추가 정보(at home, today, by bus…)',
  };

  /// 이 칸이 대답하는 질문(카드 아래 칸 이름 밑에 작게)
  String get ask => switch (this) {
    Slot.q => '뭘 묻나?',
    Slot.h => '도와주는 말',
    Slot.w => '누가?',
    Slot.a => '뭐 해? 어때?',
    Slot.o => '뭘? 누구를?',
    Slot.m => '어디서·언제·어떻게?',
  };

  /// 학교 문법에서 부르는 이름
  String get grammar => switch (this) {
    Slot.q => '의문사(What, Where…) · 접속사(Because)',
    Slot.h => '조동사(do, can, will, did…) · be동사(질문·부정·-ing일 때)',
    Slot.w => '주어',
    Slot.a => '동사(be동사 포함)',
    Slot.o => '목적어 · 보어',
    Slot.m => '부사 · 부사구(전치사구)',
  };

  /// 아이에게 설명하듯 쉬운 설명
  String get explain => switch (this) {
    Slot.q =>
      '문장 맨 앞에서 "이건 이런 걸 묻는 문장이야"라고 먼저 알려 주는 말이에요.\n'
          '• What 무엇 · Where 어디 · When 언제 · Who 누구 · Why 왜 · How 어떻게\n'
          '모르는 칸이 있으면 그 칸을 이 말로 바꿔서 맨 앞으로 보내요. '
          '"You like coffee." → coffee가 궁금하면 → "What do you like?"\n'
          '대답할 때 쓰는 Because(왜냐하면)도 맨 앞에 와요.',
    Slot.h =>
      '혼자서는 뜻이 약하지만 옆에 있는 말을 도와주는 말이에요.\n'
          '• 질문하게 해 줘요: Do you like it?\n'
          '• "안 한다"고 해 줘요: I don\'t like it.\n'
          '• 뜻을 더해 줘요: can(할 수 있다), will(할 거다), did(했다)\n'
          '도우미가 오면 한다 자리는 늘 원래 모양이에요(Does she like? / can swim / did go).\n'
          '질문할 때는 도우미가 누가 앞으로 나가요: You can swim. → Can you swim?',
    Slot.w =>
      '문장의 주인공이에요. 행동을 하는 사람이나 물건이죠. I, you, he, she, my mom, the cat…\n'
          '한국어는 "밥 먹었어?"처럼 주인공을 자주 빼지만, 영어는 거의 빼지 않아요. '
          '날씨나 시간처럼 주인공이 없을 때도 It으로 자리를 채워요: It is cold.',
    Slot.a =>
      '주인공이 하는 일(eat, go, like)이나 상태(am, is, are)예요.\n'
          '영어는 누가 바로 뒤에 한다가 와요. 한국어는 "나는 사과를 먹는다"처럼 맨 끝에 오니까 순서가 반대예요!\n'
          '이 칸 모양으로 때가 바뀌어요: eat(먹는다) → ate(먹었다).\n'
          'He·She·It이 주인공이면 -s가 붙어요: He eats.',
    Slot.o =>
      '한다의 대상이에요. "무엇을 먹어?" → pizza, "누구를 도와?" → me.\n'
          'be동사 뒤에서는 "무엇인지, 어떤지"를 말해요: I am a student. / I am happy.\n'
          '모든 문장에 있는 건 아니에요: I swim.(수영해요)처럼 대상이 필요 없는 동작도 있어요.',
    Slot.m =>
      '빼도 문장은 되지만, 붙이면 더 자세해지는 말이에요. 문장에 붙이는 "추가 정보 스티커"라고 생각하면 쉬워요.\n'
          '• 어디서: at home, in the park\n'
          '• 언제: today, at 7, every morning\n'
          '• 어떻게·누구랑: by bus, with my friend\n'
          '보통 문장 맨 뒤에 붙고, 여러 개면 어디서 → 언제 순서예요. '
          '"I play soccer." 이것만으로도 문장이 되고, "in the park(어디서)", "on Sundays(언제)"를 뒤에 붙일 수 있어요.',
  };

  /// 칸 설명창 예문(굵게 보일 조각은 그 칸)
  List<String> get samples => switch (this) {
    Slot.q => ['q:What|h:do|w:you|a:want', 'q:Where|h:is|w:the station', 'q:Because|w:I|a:like|o:it'],
    Slot.h => ['h:Do|w:you|a:like|o:it', 'w:I|h:can\'t|a:swim', 'w:She|h:will|a:come|m:tomorrow'],
    Slot.w => ['w:I|a:like|o:dogs', 'w:My mom|a:works|m:at a bank', 'w:It|a:is|o:cold'],
    Slot.a => ['w:I|a:eat|o:rice', 'w:He|a:ate|o:rice|m:yesterday', 'w:She|a:is|o:a doctor'],
    Slot.o => ['w:I|a:love|o:you', 'w:He|a:reads|o:books', 'w:I|a:am|o:happy'],
    Slot.m => [
      'w:I|a:play|o:soccer',
      'w:I|a:play|o:soccer|m:in the park',
      'w:I|a:play|o:soccer|m:in the park|m:on Sundays',
    ],
  };
}

class Chunk {
  const Chunk(this.slot, this.text, [this.tip]);
  final Slot slot;
  final String text;
  final String? tip; // 오답 조각일 때 왜 틀렸는지
}

/// "q:What|h:do|w:you|a:like" → 조각 목록
List<Chunk> parseChunks(String s) => [
  for (final part in s.split('|'))
    () {
      final tilde = part.indexOf('~');
      final body = tilde < 0 ? part : part.substring(0, tilde);
      final tip = tilde < 0 ? null : part.substring(tilde + 1);
      final colon = body.indexOf(':');
      final slot = Slot.values.byName(body.substring(0, colon).trim());
      return Chunk(slot, body.substring(colon + 1).trim(), tip);
    }(),
];

/// 조각들을 문장으로("Do you like coffee?")
String joinChunks(List<Chunk> chunks, String end) {
  final t = chunks.map((c) => c.text).join(' ');
  return t.isEmpty ? t : t[0].toUpperCase() + t.substring(1) + end;
}

/// 설명 카드의 예문 한 줄
class Example {
  Example(String chunks, this.ko, {this.end = '.'}) : chunks = parseChunks(chunks);
  final List<Chunk> chunks;
  final String ko;
  final String end;
  String get en => joinChunks(chunks, end);
}

class Concept {
  Concept(this.title, this.body, this.examples);
  final String title;
  final String body;
  final List<Example> examples;
}

/// 조립 문제: 한국어를 보고 칸 순서대로 조각을 끼운다. [from]이 있으면 "이 문장을 바꿔 보세요" 문제.
class BuildDrill {
  BuildDrill(this.ko, String answer, {String wrong = '', this.end = '.', String? from, this.fromEnd = '.', this.note})
    : answer = parseChunks(answer),
      wrong = wrong.isEmpty ? const [] : parseChunks(wrong),
      from = from == null ? null : parseChunks(from);
  final String ko;
  final List<Chunk> answer;
  final List<Chunk> wrong;
  final String end;
  final List<Chunk>? from;
  final String fromEnd;
  final String? note; // 다 맞힌 뒤 보여줄 한 줄 정리
  String get en => joinChunks(answer, end);
}

/// 고르기 문제: 빈칸(맨 앞)에 들어갈 말 고르기.
class PickDrill {
  PickDrill(this.ko, this.rest, this.options, this.answer, this.why);
  final String ko;
  final String rest; // 빈칸 뒤 문장("you like coffee?")
  final List<String> options;
  final String answer;
  final String why;
  String get en => '$answer $rest';
}

class Lesson {
  Lesson(this.id, this.title, this.subtitle, this.concepts, this.drills);
  final String id;
  final String title;
  final String subtitle;
  final List<Concept> concepts;
  final List<Object> drills; // BuildDrill 또는 PickDrill
}

final basicsLessons = <Lesson>[
  Lesson(
    'map',
    '영어 문장 지도',
    '누가 → 한다 → 무엇을 → 덧붙임',
    [
      Concept(
        '영어는 "누가 → 한다"가 먼저',
        '한국어는 "나는 커피를 좋아해요"처럼 동사가 맨 끝에 와요. 영어는 반대로 누가(I) 바로 뒤에 한다(like)가 오고, '
            '나머지는 그 뒤에 줄줄이 붙어요.',
        [
          Example('w:I|a:like|o:coffee', '나는 커피를 좋아해요.'),
          Example('w:She|a:drinks|o:coffee|m:every morning', '그녀는 매일 아침 커피를 마셔요.'),
          Example('w:We|a:play|o:soccer|m:in the park|m:on Sundays', '우리는 일요일마다 공원에서 축구를 해요.'),
        ],
      ),
      Concept(
        '덧붙임은 빼도 되는 "추가 정보"',
        '덧붙임은 문장에 붙이는 스티커 같은 말이에요. 없어도 문장은 완성되지만, 붙일수록 "어디서·언제·어떻게"가 자세해져요. '
            '반대로 누가와 한다는 빼면 문장이 안 돼요. 칸 이름을 누르면 칸마다 쉬운 설명이 나와요.',
        [
          Example('w:I|a:play|o:soccer', '나는 축구를 해요. (이것만으로 문장 완성!)'),
          Example('w:I|a:play|o:soccer|m:in the park', '나는 공원에서 축구를 해요. (+ 어디서)'),
          Example('w:I|a:play|o:soccer|m:in the park|m:on Sundays', '나는 일요일마다 공원에서 축구를 해요. (+ 어디서 + 언제)'),
        ],
      ),
      Concept('덧붙임은 "어디서 → 언제"', '장소와 시간이 같이 나오면 보통 장소가 먼저, 시간이 나중이에요. 한국어 순서(언제 → 어디서)와 거꾸로예요.', [
        Example('w:I|a:study|o:English|m:at home|m:at night', '나는 밤에 집에서 영어를 공부해요.'),
        Example('w:He|a:works|m:in Seoul|m:on weekdays', '그는 평일에 서울에서 일해요.'),
      ]),
    ],
    [
      BuildDrill('나는 물을 마셔요.', 'w:I|a:drink|o:water', wrong: 'a:drinks~I 뒤에는 -s를 붙이지 않아요'),
      BuildDrill(
        '그는 버스를 타요.',
        'w:He|a:takes|o:the bus',
        wrong: 'a:take~He·She·It 뒤에는 동사에 -s가 붙어요(takes)',
        note: 'He·She·It이 주인공이면 한다에 -s',
      ),
      BuildDrill('우리는 학교에서 영어를 배워요.', 'w:We|a:learn|o:English|m:at school'),
      BuildDrill(
        '나는 매일 아침 커피를 마셔요.',
        'w:I|a:drink|o:coffee|m:every morning',
        wrong: 'a:drinks~I 뒤에는 -s를 붙이지 않아요',
        note: '"매일 아침" 같은 언제는 맨 뒤 덧붙임 자리',
      ),
      BuildDrill(
        '그들은 주말에 공원에서 축구를 해요.',
        'w:They|a:play|o:soccer|m:in the park|m:on weekends',
        note: '덧붙임은 어디서(in the park) → 언제(on weekends)',
      ),
    ],
  ),
  Lesson(
    'be',
    'be동사: ~이다, ~에 있다',
    'am · is · are',
    [
      Concept(
        '동작이 없으면 한다 자리에 am/is/are',
        '"배고프다", "선생님이다", "책상 위에 있다"처럼 움직임이 없는 말은 한다 자리에 be동사(am, is, are)를 써요. '
            'I는 am, 한 명·한 개는 is, 여럿이나 you는 are.',
        [
          Example('w:I|a:am|o:hungry', '나는 배고파요.'),
          Example('w:It|a:is|o:cold|m:today', '오늘은 추워요.'),
          Example('w:My phone|a:is|m:on the table', '내 휴대폰은 탁자 위에 있어요.'),
        ],
      ),
    ],
    [
      BuildDrill('나는 피곤해요.', 'w:I|a:am|o:tired', wrong: 'a:is~I 짝꿍은 am이에요'),
      BuildDrill('그녀는 선생님이에요.', 'w:She|a:is|o:a teacher', wrong: 'a:are~한 사람(She)은 is예요'),
      BuildDrill('열쇠가 가방 안에 있어요.', 'w:The key|a:is|m:in the bag'),
      BuildDrill('우리는 지금 집에 있어요.', 'w:We|a:are|m:at home|m:now', wrong: 'a:is~여럿(We)은 are예요'),
    ],
  ),
  Lesson(
    'not',
    '아니에요 · 안 해요',
    'not은 도우미 바로 뒤',
    [
      Concept(
        '"안 한다"는 한다 앞에 don\'t',
        '동작 문장을 부정하려면 한다 앞에 도우미 don\'t(He·She·It은 doesn\'t)를 넣어요. doesn\'t가 -s를 가져가서 동사는 원래 모양이에요.',
        [
          Example('w:I|h:don\'t|a:like|o:milk', '나는 우유를 안 좋아해요.'),
          Example('w:He|h:doesn\'t|a:eat|o:meat', '그는 고기를 안 먹어요.'),
        ],
      ),
      Concept('be동사와 can은 바로 뒤에 not', 'is·are·am과 can은 그 자체가 도우미라서 바로 뒤에 not을 붙여요(isn\'t, aren\'t, can\'t).', [
        Example('w:It|h:isn\'t|o:far', '멀지 않아요.'),
        Example('w:I|h:can\'t|a:swim', '나는 수영을 못해요.'),
      ]),
    ],
    [
      BuildDrill('나는 고기를 안 먹어요.', 'w:I|h:don\'t|a:eat|o:meat', wrong: 'h:not~동작 문장은 not만 쓰지 않고 don\'t를 써요'),
      BuildDrill(
        '그는 커피를 안 마셔요.',
        'w:He|h:doesn\'t|a:drink|o:coffee',
        wrong: 'h:don\'t~He·She·It은 doesn\'t예요|a:drinks~doesn\'t가 -s를 가져가서 drink 그대로예요',
      ),
      BuildDrill('오늘은 안 추워요.', 'w:It|h:isn\'t|o:cold|m:today', wrong: 'h:doesn\'t~cold는 상태라서 isn\'t예요'),
      BuildDrill('나는 운전 못해요.', 'w:I|h:can\'t|a:drive'),
    ],
  ),
  Lesson(
    'do',
    'Do 질문: ~해요?',
    'Do/Does + 누가 + 한다',
    [
      Concept(
        '평서문 앞에 Do를 붙이면 질문',
        '"You like coffee." 앞에 도우미 Do를 붙이면 "Do you like coffee?"가 돼요. He·She·It이면 Does를 쓰고, '
            'Does가 -s를 가져가서 동사는 원래 모양(lives → live)이에요.',
        [
          Example('h:Do|w:you|a:like|o:coffee', '커피 좋아해요?', end: '?'),
          Example('h:Does|w:she|a:live|m:here', '그녀는 여기 살아요?', end: '?'),
        ],
      ),
    ],
    [
      PickDrill('펜 있어요?', 'you have a pen?', ['Do', 'Are', 'Is'], 'Do', 'have는 하는 일(동작·소유)이라 Do예요. Are는 상태 문장에 써요.'),
      BuildDrill(
        '커피 좋아해요?',
        'h:Do|w:you|a:like|o:coffee',
        end: '?',
        wrong: 'h:Are~like는 동작이라 Do예요',
        from: 'w:You|a:like|o:coffee',
      ),
      BuildDrill(
        '그녀는 여기 살아요?',
        'h:Does|w:she|a:live|m:here',
        end: '?',
        wrong: 'a:lives~Does가 -s를 가져가서 live 그대로예요',
        note: 'Does가 있으면 동사는 원래 모양',
      ),
      BuildDrill('매일 운동해요?', 'h:Do|w:you|a:exercise|m:every day', end: '?'),
    ],
  ),
  Lesson(
    'beq',
    'Be 질문: ~이에요? ~에 있어요?',
    'Is/Are + 누가 + 나머지',
    [
      Concept(
        'be동사 문장은 is·are를 앞으로',
        '"You are hungry." 에서 are를 맨 앞으로 보내면 "Are you hungry?"예요. be 문장에는 Do를 쓰지 않아요. '
            '이렇게 앞으로 나간 is·are는 질문을 만드는 도우미 역할을 해요.',
        [
          Example('h:Are|w:you|o:hungry', '배고파요?', end: '?'),
          Example('h:Is|w:it|o:far', '멀어요?', end: '?'),
          Example('h:Is|w:the bathroom|m:upstairs', '화장실이 위층에 있어요?', end: '?'),
        ],
      ),
    ],
    [
      PickDrill('피곤해요?', 'you tired?', ['Do', 'Are'], 'Are', 'tired는 상태(be 문장)라서 Are예요.'),
      PickDrill('여기서 일해요?', 'you work here?', ['Do', 'Are'], 'Do', 'work는 하는 일(동작)이라서 Do예요.'),
      BuildDrill(
        '배고파요?',
        'h:Are|w:you|o:hungry',
        end: '?',
        wrong: 'h:Do~hungry는 상태라서 Are예요',
        from: 'w:You|a:are|o:hungry',
      ),
      BuildDrill('여기서 멀어요?', 'h:Is|w:it|o:far|m:from here', end: '?'),
      BuildDrill('화장실이 위층에 있어요?', 'h:Is|w:the bathroom|m:upstairs', end: '?'),
    ],
  ),
  Lesson(
    'can',
    'Can 질문: ~해 줄래요? ~해도 돼요?',
    'Can + 누가 + 한다',
    [
      Concept(
        'Can I ~? / Can you ~?',
        'Can은 도우미라서 질문할 때 맨 앞으로 와요. "Can I ~?"는 "내가 ~해도 돼요? / ~ 주세요", '
            '"Can you ~?"는 "~해 줄래요?". 뒤의 동사는 항상 원래 모양이에요.',
        [
          Example('h:Can|w:I|a:have|o:an iced latte', '아이스 라테 주시겠어요?', end: '?'),
          Example('h:Can|w:you|a:help|o:me', '저 좀 도와줄래요?', end: '?'),
          Example('h:Can|w:I|a:sit|m:here', '여기 앉아도 돼요?', end: '?'),
        ],
      ),
    ],
    [
      BuildDrill(
        '아이스 라테 주시겠어요?',
        'h:Can|w:I|a:have|o:an iced latte',
        end: '?',
        wrong: 'o:a iced latte~iced처럼 모음 소리로 시작하면 a가 아니라 an이에요|h:Do~부탁할 때는 Can이에요',
      ),
      BuildDrill('도와줄 수 있어요?', 'h:Can|w:you|a:help|o:me', end: '?', wrong: 'o:I~"나를"은 me예요'),
      BuildDrill('여기 앉아도 돼요?', 'h:Can|w:I|a:sit|m:here', end: '?'),
      BuildDrill('사진 좀 찍어 줄래요?', 'h:Can|w:you|a:take|o:a picture of us', end: '?', wrong: 'a:takes~Can 뒤 동사는 원래 모양이에요'),
    ],
  ),
  Lesson(
    'what',
    'What: "무엇"이 궁금할 때',
    'What + 도우미 + 누가 + 한다',
    [
      Concept(
        '모르는 칸을 What으로 바꿔 맨 앞에',
        '"You like coffee."에서 coffee(무엇을)가 궁금하면 그 칸을 What으로 바꿔 맨 앞에 두고, 나머지는 Do 질문 순서 그대로예요. '
            '→ What do you like?',
        [
          Example('q:What|h:do|w:you|a:want', '뭐 원해요?', end: '?'),
          Example('q:What|h:do|w:you|a:do|m:on weekends', '주말에 뭐 해요?', end: '?'),
        ],
      ),
      Concept('be 문장이면 What is ~?', '"무엇이에요?"처럼 be 문장이면 What 뒤에 is/are가 와요.', [
        Example('q:What|h:is|w:your name', '이름이 뭐예요?', end: '?'),
        Example('q:What time|h:is|w:it', '몇 시예요?', end: '?'),
      ]),
    ],
    [
      BuildDrill(
        '뭐 원해요?',
        'q:What|h:do|w:you|a:want',
        end: '?',
        from: 'w:You|a:want|o:coffee',
        wrong: 'o:coffee~궁금한 칸(무엇을)은 What으로 바뀌어 맨 앞으로 갔어요',
        note: '궁금한 칸 → What으로 바꿔 맨 앞',
      ),
      BuildDrill('주말에 뭐 해요?', 'q:What|h:do|w:you|a:do|m:on weekends', end: '?'),
      BuildDrill('이름이 뭐예요?', 'q:What|h:is|w:your name', end: '?', wrong: 'h:do~be 문장이라 is예요'),
      BuildDrill(
        '그녀는 뭘 좋아해요?',
        'q:What|h:does|w:she|a:like',
        end: '?',
        wrong: 'a:likes~does가 -s를 가져가서 like 그대로예요|h:do~she는 does예요',
      ),
    ],
  ),
  Lesson(
    'where',
    'Where · When: 어디, 언제',
    'Where/When + 도우미 + 누가 + 한다',
    [
      Concept(
        '덧붙임 칸이 궁금하면 Where·When',
        '"You live in Seoul."에서 in Seoul(어디서)이 궁금하면 Where를 맨 앞에 → "Where do you live?" '
            '언제가 궁금하면 When이에요. 뒤는 Do 질문이나 be 질문 순서 그대로예요.',
        [
          Example('q:Where|h:do|w:you|a:live', '어디 살아요?', end: '?'),
          Example('q:Where|h:is|w:the station', '역이 어디예요?', end: '?'),
          Example('q:When|h:does|w:the store|a:open', '가게 언제 열어요?', end: '?'),
        ],
      ),
    ],
    [
      BuildDrill(
        '어디 살아요?',
        'q:Where|h:do|w:you|a:live',
        end: '?',
        from: 'w:You|a:live|m:in Seoul',
        wrong: 'm:in Seoul~궁금한 칸(어디서)은 Where로 바뀌었어요',
      ),
      BuildDrill('역이 어디예요?', 'q:Where|h:is|w:the station', end: '?', wrong: 'h:does~station은 있는 곳(be 문장)이라 is예요'),
      BuildDrill('가게 언제 열어요?', 'q:When|h:does|w:the store|a:open', end: '?', wrong: 'a:opens~does가 있으니 open 그대로예요'),
      BuildDrill('언제 시간 돼요?', 'q:When|h:are|w:you|o:free', end: '?', wrong: 'h:do~free(한가한)는 상태라서 are예요'),
    ],
  ),
  Lesson(
    'who',
    'Who: "누가"가 궁금할 때',
    '순서가 안 바뀌어요!',
    [
      Concept(
        '누가 칸이 궁금하면 Who가 그 자리에 그대로',
        '"Tom made this."에서 Tom(누가)이 궁금하면 Tom 자리에 Who만 넣으면 끝이에요 → "Who made this?" '
            '도우미 do가 필요 없어요. 반대로 "누구를"이 궁금하면 What처럼 do가 들어가요.',
        [
          Example('w:Who|a:made|o:this', '누가 이거 만들었어요?', end: '?'),
          Example('w:Who|a:knows|o:the answer', '누가 답을 알아요?', end: '?'),
          Example('q:Who|h:do|w:you|a:live|m:with', '누구랑 살아요?', end: '?'),
        ],
      ),
    ],
    [
      BuildDrill(
        '누가 이거 만들었어요?',
        'w:Who|a:made|o:this',
        end: '?',
        from: 'w:Tom|a:made|o:this',
        wrong: 'h:did~누가가 궁금할 때는 도우미가 필요 없어요',
        note: '누가가 궁금하면 Who로 바꾸기만',
      ),
      BuildDrill('누가 답을 알아요?', 'w:Who|a:knows|o:the answer', end: '?', wrong: 'h:does~Who가 주인공이라 도우미 없이 knows예요'),
      BuildDrill('누구랑 살아요?', 'q:Who|h:do|w:you|a:live|m:with', end: '?', note: '"누구를·누구랑"은 do가 들어가요'),
    ],
  ),
  Lesson(
    'how',
    'How: 어떻게 · 얼마나',
    'How / How much / How long…',
    [
      Concept('How 혼자면 "어떻게·어때요"', 'How 뒤는 Do 질문이나 be 질문 순서 그대로예요.', [
        Example('q:How|h:do|w:you|a:get|m:to work', '회사에 어떻게 가요?', end: '?'),
        Example('q:How|h:is|w:the weather', '날씨 어때요?', end: '?'),
      ]),
      Concept(
        'How + 말 하나 = "얼마나 ~"',
        'How much(얼마), How many(몇 개), How long(얼마나 오래), How old(몇 살)처럼 How 뒤에 한 단어를 붙여 한 덩어리로 써요.',
        [
          Example('q:How much|h:is|w:this', '이거 얼마예요?', end: '?'),
          Example('q:How long|h:does|w:it|a:take', '시간이 얼마나 걸려요?', end: '?'),
          Example('q:How old|h:are|w:you', '몇 살이에요?', end: '?'),
        ],
      ),
    ],
    [
      BuildDrill('이거 얼마예요?', 'q:How much|h:is|w:this', end: '?', wrong: 'q:How many~가격은 How much예요'),
      BuildDrill('회사에 어떻게 가요?', 'q:How|h:do|w:you|a:get|m:to work', end: '?', wrong: 'h:are~get(가다)은 동작이라 do예요'),
      BuildDrill('날씨 어때요?', 'q:How|h:is|w:the weather', end: '?'),
      BuildDrill('시간이 얼마나 걸려요?', 'q:How long|h:does|w:it|a:take', end: '?', wrong: 'a:takes~does가 있으니 take 그대로예요'),
      BuildDrill('몇 살이에요?', 'q:How old|h:are|w:you', end: '?', wrong: 'h:do~나이는 상태(be 문장)라서 are예요'),
    ],
  ),
  Lesson(
    'why',
    'Why와 because',
    '왜? → 왜냐하면',
    [
      Concept(
        'Why + 질문 순서, 대답은 Because + 문장',
        'Why 뒤는 Do 질문이나 be 질문 순서 그대로예요. 대답은 Because를 맨 앞에 붙이고 평서문 순서(누가 → 한다)로 말해요.',
        [
          Example('q:Why|h:do|w:you|a:study|o:English', '왜 영어 공부해요?', end: '?'),
          Example('q:Because|w:I|a:like|o:movies', '영화를 좋아해서요.'),
          Example('q:Why|h:are|w:you|o:tired', '왜 피곤해요?', end: '?'),
        ],
      ),
    ],
    [
      BuildDrill('왜 영어 공부해요?', 'q:Why|h:do|w:you|a:study|o:English', end: '?'),
      BuildDrill('왜 피곤해요?', 'q:Why|h:are|w:you|o:tired', end: '?', wrong: 'h:do~tired는 상태라서 are예요'),
      BuildDrill(
        '영화를 좋아해서요.',
        'q:Because|w:I|a:like|o:movies',
        wrong: 'h:do~대답은 질문 순서가 아니라 평서문 순서예요',
        note: 'Because 뒤는 평서문 순서',
      ),
    ],
  ),
  Lesson(
    'there',
    'There is · There are: ~이 있어요',
    '진짜 주인공은 뒤에',
    [
      Concept(
        '"(어디에) 무엇이 있다"는 There is/are로 시작',
        'There는 자리만 채우는 말이고, 진짜 주인공(있는 것)은 is/are 뒤에 와요. 한 개면 is, 여러 개면 are. '
            '질문은 is/are를 앞으로 → Is there ~?',
        [
          Example('w:There|a:is|o:a cafe|m:near here', '근처에 카페가 있어요.'),
          Example('w:There|a:are|o:two cats|m:in the house', '집에 고양이가 두 마리 있어요.'),
          Example('h:Is|w:there|o:a bank|m:near here', '근처에 은행 있어요?', end: '?'),
        ],
      ),
    ],
    [
      BuildDrill('근처에 카페가 있어요.', 'w:There|a:is|o:a cafe|m:near here', wrong: 'w:It~"~이 있다"는 There로 시작해요'),
      BuildDrill('방에 의자가 두 개 있어요.', 'w:There|a:are|o:two chairs|m:in the room', wrong: 'a:is~두 개(여럿)라서 are예요'),
      BuildDrill(
        '근처에 은행 있어요?',
        'h:Is|w:there|o:a bank|m:near here',
        end: '?',
        from: 'w:There|a:is|o:a bank|m:near here',
        note: '질문은 is를 앞으로',
      ),
    ],
  ),
  Lesson(
    'past',
    '과거: ~했어요',
    '한다 → 했다, 도우미는 did',
    [
      Concept(
        '한 일은 한다 자리 모양만 바꿔요',
        '어제 한 일은 한다 자리의 동사를 과거 모양으로 바꾸면 끝이에요. 대부분 -ed를 붙이고(watch → watched), '
            '자주 쓰는 동사는 모양이 따로 있어요(go → went, eat → ate, see → saw, have → had). '
            '"언제"는 맨 뒤 덧붙임 자리(yesterday, last night).',
        [
          Example('w:I|a:watched|o:a movie|m:yesterday', '나는 어제 영화를 봤어요.'),
          Example('w:She|a:went|m:to work|m:early', '그녀는 일찍 출근했어요.'),
          Example('w:We|a:ate|o:pizza|m:last night', '우리는 어젯밤에 피자를 먹었어요.'),
        ],
      ),
      Concept(
        '질문·부정은 did가 도맡아요',
        '과거 질문과 부정은 도우미 did가 과거를 가져가요. 그래서 한다 자리는 원래 모양이에요. '
            'Did you eat? (O) / Did you ate? (X). 안 했다는 didn\'t + 원래 모양.',
        [
          Example('w:I|h:didn\'t|a:eat|o:breakfast', '나는 아침을 안 먹었어요.'),
          Example('h:Did|w:you|a:sleep|m:well', '잘 잤어요?', end: '?'),
          Example('q:What|h:did|w:you|a:eat|m:for lunch', '점심에 뭐 먹었어요?', end: '?'),
        ],
      ),
    ],
    [
      BuildDrill('나는 어제 친구를 만났어요.', 'w:I|a:met|o:my friend|m:yesterday', wrong: 'a:meet~어제 한 일이라 과거 모양 met이에요'),
      BuildDrill(
        '그는 지난주에 서울에 갔어요.',
        'w:He|a:went|m:to Seoul|m:last week',
        wrong: 'a:goed~go의 과거는 went예요(모양이 따로 있는 동사)',
      ),
      BuildDrill(
        '나는 커피를 안 마셨어요.',
        'w:I|h:didn\'t|a:drink|o:coffee',
        wrong: 'a:drank~didn\'t가 과거를 가져가서 drink 그대로예요',
        note: 'did·didn\'t 뒤에는 원래 모양',
      ),
      BuildDrill(
        '잘 잤어요?',
        'h:Did|w:you|a:sleep|m:well',
        end: '?',
        from: 'w:You|a:slept|m:well',
        wrong: 'a:slept~Did가 과거를 가져가서 sleep 그대로예요',
      ),
      BuildDrill(
        '주말에 뭐 했어요?',
        'q:What|h:did|w:you|a:do|m:on the weekend',
        end: '?',
        wrong: 'a:done~도우미 did가 과거를 가져가서 한다 자리는 원래 모양 do예요',
      ),
      PickDrill(
        '어제 바빴어요?',
        'you busy yesterday?',
        ['Did', 'Were'],
        'Were',
        'busy는 상태(be 문장)라서 be동사의 과거 Were예요. 과거 be는 다음 레슨에서 더 해요.',
      ),
    ],
  ),
  Lesson(
    'was',
    '과거 be: was · were',
    '~였어요, ~에 있었어요',
    [
      Concept(
        'am·is → was, are → were',
        '상태나 있던 곳을 과거로 말할 때는 be동사를 과거로 바꿔요. I·he·she·it은 was, you·we·they는 were. '
            '질문은 was/were를 앞으로, 부정은 wasn\'t/weren\'t.',
        [
          Example('w:I|a:was|o:tired|m:yesterday', '나는 어제 피곤했어요.'),
          Example('w:They|a:were|m:at home', '그들은 집에 있었어요.'),
          Example('h:Were|w:you|o:busy', '바빴어요?', end: '?'),
          Example('q:Where|h:were|w:you', '어디 있었어요?', end: '?'),
        ],
      ),
    ],
    [
      BuildDrill('나는 어제 아팠어요.', 'w:I|a:was|o:sick|m:yesterday', wrong: 'a:were~I의 과거 be는 was예요'),
      BuildDrill('우리는 늦었어요.', 'w:We|a:were|o:late', wrong: 'a:was~여럿(We)은 were예요'),
      BuildDrill('영화 재미있었어요?', 'h:Was|w:the movie|o:good', end: '?', wrong: 'h:Did~good은 상태라서 Was예요'),
      BuildDrill(
        '어디 있었어요?',
        'q:Where|h:were|w:you',
        end: '?',
        from: 'w:You|a:were|m:at home',
        note: '궁금한 칸(어디)을 Where로 → were를 앞으로',
      ),
      BuildDrill('그건 비싸지 않았어요.', 'w:It|h:wasn\'t|o:expensive', wrong: 'h:didn\'t~expensive는 상태라서 wasn\'t예요'),
    ],
  ),
  Lesson(
    'will',
    '미래: will',
    '~할게요, ~할 거예요',
    [
      Concept(
        'will은 도우미, 뒤는 원래 모양',
        '앞으로 할 일이나 "~할게요"라는 약속·결심은 도우미 will을 한다 앞에 넣어요. 뒤의 동사는 늘 원래 모양. '
            '말할 때는 I\'ll처럼 줄여 쓰는 일이 많아요. 안 할 거면 won\'t(= will not).',
        [
          Example('w:I|h:will|a:call|o:you|m:later', '이따 전화할게요.'),
          Example('w:It|h:will|a:rain|m:tomorrow', '내일 비가 올 거예요.'),
          Example('w:I|h:won\'t|o:be late', '늦지 않을게요.'),
        ],
      ),
      Concept('질문은 Will을 앞으로', '"~할 거예요?"는 Will을 맨 앞으로. 궁금한 칸이 있으면 What·When을 그 앞에.', [
        Example('h:Will|w:you|a:come|m:tomorrow', '내일 올 거예요?', end: '?'),
        Example('q:What|h:will|w:you|a:do|m:this weekend', '이번 주말에 뭐 할 거예요?', end: '?'),
      ]),
    ],
    [
      BuildDrill('내가 도와줄게요.', 'w:I|h:will|a:help|o:you', wrong: 'a:helps~will 뒤는 원래 모양이에요'),
      BuildDrill('내일 비가 올 거예요.', 'w:It|h:will|a:rain|m:tomorrow', wrong: 'a:rains~will 뒤는 원래 모양이에요'),
      BuildDrill('파티에 올 거예요?', 'h:Will|w:you|a:come|m:to the party', end: '?', wrong: 'h:Do~앞으로의 일이라 Will이에요'),
      BuildDrill('늦지 않을게요.', 'w:I|h:won\'t|o:be late', wrong: 'h:don\'t~앞으로의 약속이라 won\'t예요'),
      BuildDrill('언제 돌아올 거예요?', 'q:When|h:will|w:you|a:come back', end: '?'),
    ],
  ),
  Lesson(
    'going',
    '미래: be going to',
    '~할 예정이에요(이미 정한 계획)',
    [
      Concept(
        '정해 둔 계획은 am/is/are going to',
        '이미 마음먹은 계획은 "be going to + 원래 모양"으로 말해요. am·is·are going to를 한 덩어리 도우미로 보면 쉬워요. '
            'will(지금 정한 것, 약속)과 거의 같지만, going to는 "원래 그럴 계획"이라는 느낌이에요.',
        [
          Example('w:I|h:am going to|a:visit|o:my parents|m:this weekend', '이번 주말에 부모님 댁에 갈 거예요.'),
          Example('w:She|h:is going to|a:start|o:a new job', '그녀는 새 일을 시작할 예정이에요.'),
        ],
      ),
      Concept('질문은 am/is/are를 앞으로', 'be 질문과 똑같이 am·is·are만 앞으로 보내요. → Are you going to ~?', [
        Example('h:Are|w:you|h:going to|a:buy|o:it', '그거 살 거예요?', end: '?'),
        Example('q:What|h:are|w:you|h:going to|a:do|m:tomorrow', '내일 뭐 할 거예요?', end: '?'),
      ]),
    ],
    [
      BuildDrill('나는 영어를 배울 거예요.', 'w:I|h:am going to|a:learn|o:English', wrong: 'a:learning~going to 뒤는 원래 모양이에요'),
      BuildDrill('그는 차를 살 예정이에요.', 'w:He|h:is going to|a:buy|o:a car', wrong: 'h:are going to~한 사람(He)은 is예요'),
      BuildDrill(
        '그거 살 거예요?',
        'h:Are|w:you|h:going to|a:buy|o:it',
        end: '?',
        from: 'w:You|h:are going to|a:buy|o:it',
        note: '질문은 are만 앞으로',
      ),
      BuildDrill('내일 뭐 할 거예요?', 'q:What|h:are|w:you|h:going to|a:do|m:tomorrow', end: '?'),
    ],
  ),
  Lesson(
    'ing',
    '지금 하는 중: -ing',
    'am · is · are + 동사ing',
    [
      Concept(
        '"~하는 중이에요"는 be + -ing',
        '지금 바로 하고 있는 일은 도우미 자리에 am·is·are, 한다 자리에 동사 + ing를 써요. '
            'eat → eating, read → reading, run → running. am/is/are를 빼면 안 돼요(I eating X).',
        [
          Example('w:I|h:am|a:eating|o:lunch|m:now', '나는 지금 점심을 먹는 중이에요.'),
          Example('w:She|h:is|a:reading|o:a book', '그녀는 책을 읽고 있어요.'),
          Example('w:It|h:is|a:raining', '비가 오고 있어요.'),
        ],
      ),
      Concept('질문·부정도 be 문장과 같아요', '질문은 am·is·are를 앞으로, 부정은 그 뒤에 not. do는 쓰지 않아요.', [
        Example('h:Are|w:you|a:sleeping', '자고 있어요?', end: '?'),
        Example('q:What|h:are|w:you|a:doing', '뭐 하고 있어요?', end: '?'),
        Example('w:I|h:am not|a:watching|o:TV', '나는 TV를 보고 있지 않아요.'),
      ]),
    ],
    [
      BuildDrill(
        '나는 지금 점심을 먹고 있어요.',
        'w:I|h:am|a:eating|o:lunch|m:now',
        wrong: 'a:eat~"~하는 중"이라 -ing가 붙은 eating이에요',
        note: 'am(도우미) + eating(한다) = 하는 중',
      ),
      BuildDrill('그는 책을 읽고 있어요.', 'w:He|h:is|a:reading|o:a book', wrong: 'h:are~한 사람(He)은 is예요'),
      BuildDrill(
        '뭐 하고 있어요?',
        'q:What|h:are|w:you|a:doing',
        end: '?',
        wrong: 'h:do~-ing 문장의 질문은 do가 아니라 are예요',
        note: '궁금한 칸(무엇을)을 What으로 → are를 앞으로',
      ),
      BuildDrill('비가 오고 있어요.', 'w:It|h:is|a:raining', note: '날씨는 주인공 자리에 It'),
      BuildDrill('나는 TV를 보고 있지 않아요.', 'w:I|h:am not|a:watching|o:TV', wrong: 'h:don\'t~-ing 문장의 부정은 am not이에요'),
    ],
  ),
  Lesson(
    'want',
    '하고 싶어요: want to',
    'want to + 원래 모양',
    [
      Concept(
        '"~하고 싶어요"는 want to + 원래 모양',
        '하고 싶은 일은 want to를 한 덩어리 도우미로 보고, 그 뒤 한다 자리에 원래 모양을 써요. '
            'He·She·It이면 wants to. want to 뒤에는 -s·-ing를 붙이지 않아요.',
        [
          Example('w:I|h:want to|a:eat|o:pizza', '나는 피자를 먹고 싶어요.'),
          Example('w:She|h:wants to|a:be|o:a doctor', '그녀는 의사가 되고 싶어 해요.'),
        ],
      ),
      Concept('질문·부정은 do가 도와줘요', 'want는 원래 동작 말이라서 질문은 Do, 부정은 don\'t를 앞에 붙여요.', [
        Example('h:Do|w:you|h:want to|a:come|m:with us', '우리랑 같이 갈래요?', end: '?'),
        Example('w:I|h:don\'t want to|a:sleep|m:now', '나는 지금 자고 싶지 않아요.'),
        Example('q:What|h:do|w:you|h:want to|a:eat', '뭐 먹고 싶어요?', end: '?'),
      ]),
    ],
    [
      BuildDrill(
        '나는 피자를 먹고 싶어요.',
        'w:I|h:want to|a:eat|o:pizza',
        wrong: 'a:eating~want to 뒤는 원래 모양이에요',
        note: 'want to(하고 싶다) + eat(원래 모양)',
      ),
      BuildDrill('그녀는 의사가 되고 싶어 해요.', 'w:She|h:wants to|a:be|o:a doctor', wrong: 'h:want to~She 뒤에는 wants to예요(-s)'),
      BuildDrill(
        '우리랑 같이 갈래요?',
        'h:Do|w:you|h:want to|a:come|m:with us',
        end: '?',
        from: 'w:You|h:want to|a:come|m:with us',
        wrong: 'h:Are~want는 동작 말이라 질문은 Do예요',
      ),
      BuildDrill('나는 지금 자고 싶지 않아요.', 'w:I|h:don\'t want to|a:sleep|m:now'),
      BuildDrill('뭐 먹고 싶어요?', 'q:What|h:do|w:you|h:want to|a:eat', end: '?', note: '궁금한 칸(무엇을)을 What으로 → do를 앞으로'),
    ],
  ),
  Lesson(
    'have',
    '해야 해요: have to',
    'have to + 원래 모양',
    [
      Concept('"~해야 해요"는 have to + 원래 모양', '꼭 해야 하는 일은 have to를 한 덩어리 도우미로 보고, 그 뒤에 원래 모양을 써요. He·She·It이면 has to.', [
        Example('w:I|h:have to|a:go|m:now', '나는 지금 가야 해요.'),
        Example('w:He|h:has to|a:work|m:tomorrow', '그는 내일 일해야 해요.'),
      ]),
      Concept('don\'t have to는 "안 해도 돼요"', '조심! don\'t have to는 "하면 안 돼"가 아니라 "안 해도 괜찮아"라는 뜻이에요. 질문은 Do를 앞에.', [
        Example('w:You|h:don\'t have to|a:hurry', '서두르지 않아도 돼요.'),
        Example('h:Do|w:you|h:have to|a:get up|m:early', '일찍 일어나야 해요?', end: '?'),
        Example('q:What|h:do|w:I|h:have to|a:do', '나는 뭘 해야 해요?', end: '?'),
      ]),
    ],
    [
      BuildDrill('나는 지금 가야 해요.', 'w:I|h:have to|a:go|m:now', wrong: 'a:going~have to 뒤는 원래 모양이에요'),
      BuildDrill('그는 내일 일해야 해요.', 'w:He|h:has to|a:work|m:tomorrow', wrong: 'h:have to~He 뒤에는 has to예요'),
      BuildDrill(
        '일찍 일어나야 해요?',
        'h:Do|w:you|h:have to|a:get up|m:early',
        end: '?',
        from: 'w:You|h:have to|a:get up|m:early',
        note: '질문은 Do를 앞으로',
      ),
      BuildDrill('서두르지 않아도 돼요.', 'w:You|h:don\'t have to|a:hurry', note: 'don\'t have to = 안 해도 돼요(하지 말라는 뜻이 아니에요)'),
      BuildDrill('나는 뭘 해야 해요?', 'q:What|h:do|w:I|h:have to|a:do', end: '?'),
    ],
  ),
];
