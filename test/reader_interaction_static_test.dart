import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reader pages are non-scrollable and use third-based tap zones', () {
    final source = File('lib/screens/reader_screen.dart').readAsStringSync();

    expect(source, isNot(contains('SelectableText')));
    expect(source, isNot(contains('SingleChildScrollView')));
    expect(source, contains('x < width / 3'));
    expect(source, contains('x > width * 2 / 3'));
    expect(source, contains('widget.onCenterTap()'));
    expect(source, contains('appBar: _controlsVisible'));
    expect(source, contains('book == null || !_controlsVisible'));
    expect(source, contains('left: _horizontalPadding'));
    expect(source, contains('_pageBottomPadding'));
    expect(source, contains('lineGuard'));
  });
}
