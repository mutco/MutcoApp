import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:mutco/data/scan_record.dart';
import 'package:mutco/features/common_widgets.dart';

void main() {
  testWidgets('rename sheet saves and closes without disposing an active field', (tester) async {
    final record = ScanRecord(
      id: 'test', name: 'Sampel awal', date: DateTime(2026), imagePath: '',
      width: 640, height: 640, detections: const [], threshold: .25,
      inferenceMs: 0, postprocessMs: 0,
    );
    await tester.pumpWidget(MaterialApp(locale: const Locale('id'),
      supportedLocales: const [Locale('id'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: Builder(
      builder: (context) => TextButton(
        onPressed: () => renameRecord(context, record, (_) async {}),
        child: const Text('Ubah nama'),
      ),
    ))));
    await tester.tap(find.text('Ubah nama'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), 'Sampel baru');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(record.name, 'Sampel baru');
    expect(find.byType(TextField), findsNothing);
    expect(tester.takeException(), isNull);
  });
}
