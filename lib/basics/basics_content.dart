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
    Slot.m => '어디서·언제·어떻게(at home, today…)',
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
  BuildDrill(
    this.ko,
    String answer, {
    String wrong = '',
    this.end = '.',
    String? from,
    this.fromEnd = '.',
    this.note,
  }) : answer = parseChunks(answer),
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
      Concept(
        'be동사와 can은 바로 뒤에 not',
        'is·are·am과 can은 그 자체가 도우미라서 바로 뒤에 not을 붙여요(isn\'t, aren\'t, can\'t).',
        [Example('w:It|h:isn\'t|o:far', '멀지 않아요.'), Example('w:I|h:can\'t|a:swim', '나는 수영을 못해요.')],
      ),
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
      PickDrill(
        '펜 있어요?',
        'you have a pen?',
        ['Do', 'Are', 'Is'],
        'Do',
        'have는 하는 일(동작·소유)이라 Do예요. Are는 상태 문장에 써요.',
      ),
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
      BuildDrill(
        '사진 좀 찍어 줄래요?',
        'h:Can|w:you|a:take|o:a picture of us',
        end: '?',
        wrong: 'a:takes~Can 뒤 동사는 원래 모양이에요',
      ),
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
      BuildDrill(
        '역이 어디예요?',
        'q:Where|h:is|w:the station',
        end: '?',
        wrong: 'h:does~station은 있는 곳(be 문장)이라 is예요',
      ),
      BuildDrill(
        '가게 언제 열어요?',
        'q:When|h:does|w:the store|a:open',
        end: '?',
        wrong: 'a:opens~does가 있으니 open 그대로예요',
      ),
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
      BuildDrill(
        '누가 답을 알아요?',
        'w:Who|a:knows|o:the answer',
        end: '?',
        wrong: 'h:does~Who가 주인공이라 도우미 없이 knows예요',
      ),
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
      BuildDrill(
        '회사에 어떻게 가요?',
        'q:How|h:do|w:you|a:get|m:to work',
        end: '?',
        wrong: 'h:are~get(가다)은 동작이라 do예요',
      ),
      BuildDrill('날씨 어때요?', 'q:How|h:is|w:the weather', end: '?'),
      BuildDrill(
        '시간이 얼마나 걸려요?',
        'q:How long|h:does|w:it|a:take',
        end: '?',
        wrong: 'a:takes~does가 있으니 take 그대로예요',
      ),
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
      BuildDrill(
        '방에 의자가 두 개 있어요.',
        'w:There|a:are|o:two chairs|m:in the room',
        wrong: 'a:is~두 개(여럿)라서 are예요',
      ),
      BuildDrill(
        '근처에 은행 있어요?',
        'h:Is|w:there|o:a bank|m:near here',
        end: '?',
        from: 'w:There|a:is|o:a bank|m:near here',
        note: '질문은 is를 앞으로',
      ),
    ],
  ),
];
