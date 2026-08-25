import 'package:flutter/material.dart';
import 'core/app_state.dart';
import 'core/theme.dart';
import 'features/auth/login_screen.dart';
import 'features/shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await AppState.instance.init();
  runApp(const TeduApp());
}

class TeduApp extends StatelessWidget {
  const TeduApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: AppState.instance,
      builder: (context, _) {
        final st = AppState.instance;
        return MaterialApp(
          title: 'TEdu',
          debugShowCheckedModeBanner: false,
          theme: buildVintageTheme(),
          home: st.isLoggedIn ? const ShellScreen() : const LoginScreen(),
        );
      },
    );
  }
}
