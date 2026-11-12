import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'data/settings.dart';
import 'state/phone_controller.dart';
import 'state/phone_scope.dart';
import 'ui/pages/home_page.dart';
import 'ui/theme.dart';

class SPhoneApp extends StatefulWidget {
  const SPhoneApp({super.key, required this.controller});

  final PhoneController controller;

  @override
  State<SPhoneApp> createState() => _SPhoneAppState();
}

class _SPhoneAppState extends State<SPhoneApp> {
  static final _light = buildTheme(Brightness.light);
  static final _dark = buildTheme(Brightness.dark);

  late AppThemeMode _mode = widget.controller.settings.theme;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onControllerChanged);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onControllerChanged);
    super.dispose();
  }

  /// L'application entière n'est reconstruite que si le thème choisi change.
  void _onControllerChanged() {
    final mode = widget.controller.settings.theme;
    if (mode != _mode) setState(() => _mode = mode);
  }

  @override
  Widget build(BuildContext context) {
    return PhoneScope(
      controller: widget.controller,
      child: MaterialApp(
        title: 'sPhone',
        debugShowCheckedModeBanner: false,
        theme: _light,
        darkTheme: _dark,
        themeMode: switch (_mode) {
          AppThemeMode.auto => ThemeMode.system,
          AppThemeMode.light => ThemeMode.light,
          AppThemeMode.dark => ThemeMode.dark,
        },
        locale: const Locale('fr', 'FR'),
        supportedLocales: const [Locale('fr', 'FR')],
        localizationsDelegates: GlobalMaterialLocalizations.delegates,
        home: const HomePage(),
      ),
    );
  }
}
