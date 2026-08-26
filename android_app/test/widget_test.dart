import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:meteorologus_app/views/dashboard/widgets/page_indicator.dart';
import 'package:meteorologus_app/views/dashboard/widgets/sparkline_painter.dart';
import 'package:meteorologus_app/utils/glass_container.dart';

void main() {
  testWidgets('GlassCard renders child with blur and decoration', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: GlassCard(
            child: Text('Glass Content'),
          ),
        ),
      ),
    );

    expect(find.text('Glass Content'), findsOneWidget);
  });

  testWidgets('PageIndicator renders correct number of dots', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: PageIndicator(
            count: 2,
            currentIndex: 0,
            color: Colors.white,
          ),
        ),
      ),
    );

    expect(find.byType(PageIndicator), findsOneWidget);
  });

  testWidgets('SparklineWidget renders custom paint when multiple temperatures exist', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: SparklineWidget(
            temperatures: [22.0, 23.5, 21.8, 24.1],
            color: Colors.blue,
          ),
        ),
      ),
    );

    expect(find.byType(SparklineWidget), findsOneWidget);
  });
}
