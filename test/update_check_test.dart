import 'package:english_step/update_check.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('릴리스 제목에서 빌드 번호를 뽑는다', () {
    expect(parseBuildNumber('영어 한 걸음 (빌드 23)'), 23);
    expect(parseBuildNumber('영어 한 걸음 (빌드23)'), 23);
    expect(parseBuildNumber('영어 한 걸음 최신 APK (#7)'), isNull);
  });

  test('테스트·PC 빌드는 빌드 번호가 0이라 자동 확인을 하지 않는다', () {
    expect(currentBuild, 0);
  });
}
