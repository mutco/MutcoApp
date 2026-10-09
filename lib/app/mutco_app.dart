import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/local_repository.dart';
import '../data/scan_record.dart';
import '../features/home_screen.dart';
import '../features/history_screen.dart';
import '../features/scan_screen.dart';
import '../features/settings_screen.dart';
import '../features/result_screen.dart';
import '../features/learn_screen.dart';
import '../services/yolo_inference.dart';
import 'mutco_theme.dart';

class MutcoApp extends StatefulWidget {
  final LocalRepository repository;
  final SharedPreferences prefs;
  const MutcoApp({super.key, required this.repository, required this.prefs});
  @override
  State<MutcoApp> createState() => _MutcoAppState();
}

class _MutcoAppState extends State<MutcoApp> {
  static const nativeTheme = MethodChannel('com.usk.mutco/theme');
  final inference = YoloInference();
  final navigatorKey = GlobalKey<NavigatorState>();
  static final lightTheme = MutcoTheme.create(MutcoPalette.light);
  static final darkTheme = MutcoTheme.create(MutcoPalette.night);
  int tab = 0;
  bool showingSplash = true;
  Timer? splashTimer;
  bool dark = false, showBoxes = true, showLabels = false;
  String language = 'id';
  double threshold = 0.25, iouThreshold = 0.70;
  late List<ScanRecord> records;

  @override
  void initState() {
    super.initState();
    records = widget.repository.records;
    dark = widget.prefs.getBool('dark') ?? false;
    showBoxes = widget.prefs.getBool('show_boxes') ?? true;
    showLabels = widget.prefs.getBool('show_labels') ?? false;
    threshold = widget.prefs.getDouble('threshold') ?? 0.25;
    iouThreshold = widget.prefs.getDouble('iou_threshold') ?? 0.70;
    language = widget.prefs.getString('language') ?? 'id';
    _systemBars();
    splashTimer = Timer(const Duration(milliseconds: 950), () {
      if (mounted) setState(() => showingSplash = false);
    });
  }

  @override
  void dispose() {
    splashTimer?.cancel();
    inference.dispose();
    super.dispose();
  }

  void refresh() {
    if (mounted) setState(() => records = widget.repository.records);
  }

  Future<void> save(ScanRecord record) async {
    await widget.repository.save(record);
    if (mounted) {
      setState(() {
        records = widget.repository.records;
        tab = 0;
      });
    }
  }

  Future<void> setPreference(String key, Object value) async {
    if (key == 'dark' && value is bool) {
      setState(() => dark = value);
      _systemBars();
    } else if (key == 'show_boxes' && value is bool) {
      showBoxes = value;
    } else if (key == 'show_labels' && value is bool) {
      showLabels = value;
    } else if (key == 'threshold' && value is double) {
      threshold = value;
    } else if (key == 'iou_threshold' && value is double) {
      iouThreshold = value;
    } else if (key == 'language' && value is String) {
      setState(() => language = value);
    }
    if (value is bool) {
      await widget.prefs.setBool(key, value);
    }
    if (value is double) {
      await widget.prefs.setDouble(key, value);
    }
    if (value is String) {
      await widget.prefs.setString(key, value);
    }
  }

  Future<void> resetSettings() async {
    await Future.wait([
      widget.prefs.setBool('dark', false),
      widget.prefs.setBool('show_boxes', true),
      widget.prefs.setBool('show_labels', false),
      widget.prefs.setDouble('threshold', 0.25),
      widget.prefs.setDouble('iou_threshold', 0.70),
      widget.prefs.setString('language', 'id'),
    ]);
    if (!mounted) return;
    setState(() {
      dark = false;
      showBoxes = true;
      showLabels = false;
      threshold = 0.25;
      iouThreshold = 0.70;
      language = 'id';
    });
    _systemBars();
  }

  void _systemBars() {
    final p = dark ? MutcoPalette.night : MutcoPalette.light;
    SystemChrome.setSystemUIOverlayStyle(
      SystemUiOverlayStyle(
        statusBarColor: p.background,
        statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
        systemNavigationBarColor: p.background,
        systemNavigationBarIconBrightness: dark
            ? Brightness.dark
            : Brightness.light,
        systemNavigationBarDividerColor: p.background,
        systemNavigationBarContrastEnforced: false,
      ),
    );
    if (defaultTargetPlatform == TargetPlatform.android) {
      unawaited(
        nativeTheme
            .invokeMethod<void>('setDark', dark)
            .catchError((Object _) {}),
      );
    }
  }

  void openResult(ScanRecord record, {bool saved = true}) {
    navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => ResultScreen(
          record: record,
          saved: saved,
          boxes: showBoxes,
          labels: showLabels,
          onSave: () => save(record),
          onClose: closeResult,
          onRescan: openScan,
          onBoxes: (v) => setPreference('show_boxes', v),
          onLabels: (v) => setPreference('show_labels', v),
        ),
      ),
    );
  }

  void closeResult() {
    navigatorKey.currentState!.popUntil((route) => route.isFirst);
    if (mounted) setState(() => tab = 0);
  }

  void openScan() {
    navigatorKey.currentState!.push(
      MaterialPageRoute(
        builder: (_) => ScanScreen(
          inference: inference,
          repository: widget.repository,
          threshold: threshold,
          iouThreshold: iouThreshold,
          onResult: (record) => openResult(record, saved: false),
        ),
      ),
    );
  }

  void openSettings() => navigatorKey.currentState!.push(
    MaterialPageRoute(
      builder: (_) => SettingsScreen(
        dark: dark,
        language: language,
        threshold: threshold,
        iouThreshold: iouThreshold,
        onPreference: setPreference,
        onResetSettings: resetSettings,
        onClear: () async {
          await widget.repository.clear();
          refresh();
        },
      ),
    ),
  );

  void openLearn() => navigatorKey.currentState!.push(
    MaterialPageRoute(builder: (_) => const LearnScreen()),
  );

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Mutco',
      debugShowCheckedModeBanner: false,
      theme: lightTheme,
      darkTheme: darkTheme,
      themeMode: dark ? ThemeMode.dark : ThemeMode.light,
      locale: Locale(language),
      supportedLocales: const [Locale('id'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      navigatorKey: navigatorKey,
      home: Scaffold(
        body: SafeArea(
          child: showingSplash
              ? Center(
                  child: Image.asset(
                    'assets/branding/loading_icon.png',
                    width: 260,
                    height: 260,
                    fit: BoxFit.contain,
                    filterQuality: FilterQuality.high,
                  ),
                )
              : tab == 0
              ? HomeScreen(
                  records: records,
                  onScan: openScan,
                  onHistory: () => setState(() => tab = 1),
                  onSettings: openSettings,
                  onLearn: openLearn,
                  onOpen: openResult,
                  onChanged: refresh,
                  repository: widget.repository,
                )
              : HistoryScreen(
                  records: records,
                  repository: widget.repository,
                  onScan: openScan,
                  onHome: () => setState(() => tab = 0),
                  onSettings: openSettings,
                  onLearn: openLearn,
                  onOpen: openResult,
                  onChanged: refresh,
                ),
        ),
      ),
    );
  }
}
