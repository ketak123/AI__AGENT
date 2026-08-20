import 'package:flutter_test/flutter_test.dart';
import 'package:frontend/main.dart';
import 'package:frontend/services/api_service.dart';

void main() {
  testWidgets('app launches and renders home shell', (WidgetTester tester) async {
    final apiService = ApiService();
    await tester.pumpWidget(BusinessAgentApp(apiService: apiService));
    expect(find.byType(BusinessAgentApp), findsOneWidget);
  });
}
