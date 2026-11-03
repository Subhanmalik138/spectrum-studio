import 'package:flutter_test/flutter_test.dart';

import 'package:spectrum_studio/main.dart';

void main() {
  testWidgets('Spectrum Studio app builds with Create tab', (tester) async {
    await tester.pumpWidget(const SpectrumStudioApp());
    // No pumpAndSettle: the Templates tab runs a repeating preview
    // animation, so frames never fully settle.
    await tester.pump(const Duration(milliseconds: 200));
    expect(find.text('Spectrum Studio'), findsWidgets);
    expect(find.text('Create Visualizer'), findsOneWidget);
  });
}
