import 'package:air_rider/group_service.dart';
import 'package:air_rider/main.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('home screen shows create and join', (tester) async {
    await tester.pumpWidget(AirApp(service: DemoGroupService()));
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('Start the ride'), findsOneWidget);
    expect(find.text('Join a ride'), findsOneWidget);
    expect(find.text('Ride Captain name'), findsOneWidget);
    await tester.tap(find.text('Join a ride'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Join the ride'), findsOneWidget);
    expect(find.text('Ride code'), findsOneWidget);
  });
}
