import 'package:flutter_test/flutter_test.dart';
import 'package:linux_app_menu_example/main.dart';

void main() {
  testWidgets('shows example state', (tester) async {
    await tester.pumpWidget(const MyApp());

    expect(find.text('Theme mode: System'), findsOneWidget);
    expect(find.text('Accent color: Teal'), findsOneWidget);
  });
}
