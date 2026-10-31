import 'package:air_rider/group_service.dart';
import 'package:air_rider/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home screen shows create and join', (tester) async {
    await tester.pumpWidget(AirApp(service: DemoGroupService()));
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('Start a new group'), findsOneWidget);
    expect(find.text('Join'), findsOneWidget);
  });
}
