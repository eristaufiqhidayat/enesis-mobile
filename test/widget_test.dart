import 'package:enesis_mobile/ui/theme.dart';
import 'package:enesis_mobile/ui/widgets/umum.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('StepperQty menambah, mengurangi, dan berhenti di batas', (tester) async {
    num nilai = 0;

    await tester.pumpWidget(MaterialApp(
      theme: temaEnesis(),
      home: Scaffold(
        body: StatefulBuilder(
          builder: (context, setState) => StepperQty(nilai: nilai, maks: 2, onUbah: (v) => setState(() => nilai = v)),
        ),
      ),
    ));

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();
    await tester.tap(find.byIcon(Icons.add)); // sudah maks
    await tester.pump();
    expect(nilai, 2);
    expect(find.text('2'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.remove));
    await tester.pump();
    expect(nilai, 1);
  });

  testWidgets('Lencana status kunjungan', (tester) async {
    await tester.pumpWidget(MaterialApp(
      home: Scaffold(body: Column(children: [Lencana.status('beli'), Lencana.status('tidak_beli'), Lencana.status('belum')])),
    ));

    expect(find.text('Beli'), findsOneWidget);
    expect(find.text('Tidak beli'), findsOneWidget);
    expect(find.text('Belum'), findsOneWidget);
  });
}
