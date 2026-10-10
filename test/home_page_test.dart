import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:snap_post/src/app_settings.dart';
import 'package:snap_post/src/home_page.dart';
import 'package:snap_post/src/shot_list.dart';

void main() {
  testWidgets('thread field validates on the home screen', (tester) async {
    final commits = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: HomePage(
          settings: AppSettings.defaults(),
          shots: ShotList(),
          busy: false,
          captureError: null,
          onCapture: () {},
          onOpenSettings: () {},
          onToggle: (index, selected) {},
          onDelete: (index) {},
          onPost: () {},
          onReplyDraft: (value) {},
          onReplyCommit: commits.add,
          onReadClipboard: () async => 'https://x.com/name/status/77',
        ),
      ),
    );

    expect(find.text('全部消す'), findsNothing);
    expect(find.text('ツリーにつなげる'), findsOneWidget);
    expect(find.byType(Switch), findsNothing);
    expect(find.text('未設定'), findsOneWidget);
    expect(
      tester
          .widget<ButtonStyleButton>(find.widgetWithText(TextButton, '開く'))
          .onPressed,
      isNull,
    );

    await tester.enterText(find.byType(TextField), 'nope');
    await tester.pump();
    expect(find.text('読めません'), findsOneWidget);
    expect(commits, isEmpty);

    await tester.enterText(
      find.byType(TextField),
      'https://x.com/name/status/15',
    );
    await tester.pump();
    expect(find.text('status id: 15'), findsOneWidget);
    expect(commits, <String>['https://x.com/name/status/15']);

    await tester.tap(find.text('クリア'));
    await tester.pump();
    expect(find.text('未設定'), findsOneWidget);
    expect(commits.last, isEmpty);

    await tester.tap(find.text('クリップボードから貼り付け'));
    await tester.pump();
    expect(find.text('status id: 77'), findsOneWidget);
    expect(commits.last, 'https://x.com/name/status/77');
    expect(
      tester
          .widget<ButtonStyleButton>(find.widgetWithText(TextButton, '開く'))
          .onPressed,
      isNotNull,
    );
  });
}
