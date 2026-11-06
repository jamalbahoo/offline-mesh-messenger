import 'package:flutter_test/flutter_test.dart';
import 'package:offline_mesh_messenger/main.dart';

void main() {
  testWidgets('shows the local-first chats screen and navigation', (tester) async {
    await tester.pumpWidget(const MeshMessengerApp());
    await tester.pumpAndSettle();
    expect(find.text('Mesh Messenger'), findsOneWidget);
    expect(find.text('Chats'), findsOneWidget);
    expect(find.text('Status'), findsOneWidget);
  });
}
