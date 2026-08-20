import 'package:flutter/material.dart';
import 'core/constants.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';
import 'views/home_shell.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  final apiService = ApiService();
  runApp(BusinessAgentApp(apiService: apiService));
}

class BusinessAgentApp extends StatelessWidget {
  final ApiService apiService;

  const BusinessAgentApp({super.key, required this.apiService});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: AppConstants.appName,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: HomeShell(apiService: apiService),
    );
  }
}
