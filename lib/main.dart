import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import 'services/hermes_service.dart';
import 'services/notification_service.dart';
import 'services/settings_service.dart';
import 'screens/connect_screen.dart';
import 'screens/chat_screen.dart';
import 'theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarBrightness: Brightness.dark,
  ));
  await NotificationService().init();
  runApp(const HermesApp());
}

class HermesApp extends StatelessWidget {
  const HermesApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => HermesService(),
      child: MaterialApp(
        title: 'Hermes',
        theme: AppTheme.dark,
        debugShowCheckedModeBanner: false,
        home: const _StartupPage(),
      ),
    );
  }
}

class _StartupPage extends StatefulWidget {
  const _StartupPage();

  @override
  State<_StartupPage> createState() => _StartupPageState();
}

class _StartupPageState extends State<_StartupPage> {
  @override
  void initState() {
    super.initState();
    _init();
  }

  Future<void> _init() async {
    final saved = await SettingsService().load();
    if (!mounted) return;

    if (saved != null) {
      final service = context.read<HermesService>();
      await service.connect(saved);
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ChatScreen()),
      );
    } else {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const ConnectScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: AppTheme.bg,
      body: Center(
        child: CircularProgressIndicator(color: AppTheme.accent),
      ),
    );
  }
}
