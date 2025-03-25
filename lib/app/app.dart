import 'package:flutter/material.dart';
import 'routes.dart';
import '../presentation/screens/auth/auth_screen.dart';
import 'theme.dart';

class App extends StatelessWidget {
  const App({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Eloquence',
      theme: AppTheme.theme,
      routes: {
        AppRoutes.authScreen: (context) => const AuthScreen(),
      },
      home: const AuthScreen(),
    );
  }
}
