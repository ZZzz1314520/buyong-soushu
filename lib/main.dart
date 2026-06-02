import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'screens/home_shell.dart';
import 'services/app_controller.dart';
import 'services/controller_scope.dart';
import 'services/local_library.dart';
import 'services/novel_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final preferences = await SharedPreferences.getInstance();
  final controller = AppController(
    library: LocalLibrary(preferences),
    novelService: NovelService(),
  );
  runApp(NovelReaderApp(controller: controller));
}

class NovelReaderApp extends StatelessWidget {
  const NovelReaderApp({super.key, required this.controller});

  final AppController controller;

  @override
  Widget build(BuildContext context) {
    return ControllerScope(
      controller: controller,
      child: MaterialApp(
        title: '不用搜书',
        debugShowCheckedModeBanner: false,
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xfffb5b21),
            primary: const Color(0xfffb5b21),
            secondary: const Color(0xffff8a3d),
            surface: const Color(0xfffffbf7),
          ),
          scaffoldBackgroundColor: const Color(0xfffffbf7),
          appBarTheme: const AppBarTheme(
            backgroundColor: Color(0xfffffbf7),
            foregroundColor: Color(0xff1f1a17),
            elevation: 0,
            centerTitle: false,
          ),
          cardTheme: CardThemeData(
            color: Colors.white,
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
              side: const BorderSide(color: Color(0xfff0e5dc)),
            ),
          ),
        ),
        home: const HomeShell(),
      ),
    );
  }
}
