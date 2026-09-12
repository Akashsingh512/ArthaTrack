import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'core/theme/app_theme.dart';
import 'data/database/app_database.dart';
import 'presentation/controllers/balance_sheet_controller.dart';
import 'presentation/controllers/category_controller.dart';
import 'presentation/controllers/dashboard_controller.dart';
import 'presentation/controllers/settings_controller.dart';
import 'presentation/controllers/transaction_controller.dart';
import 'presentation/screens/main_shell_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize SQLite database instance and ensure tables are created
  await AppDatabase.instance.database;

  runApp(const ArthaTrackApp());
}

class ArthaTrackApp extends StatelessWidget {
  const ArthaTrackApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DashboardController()),
        ChangeNotifierProvider(create: (_) => TransactionController()),
        ChangeNotifierProvider(create: (_) => BalanceSheetController()),
        ChangeNotifierProvider(create: (_) => SettingsController()),
        ChangeNotifierProvider(create: (_) => CategoryController()..loadCategories()),
      ],
      child: Consumer<SettingsController>(
        builder: (context, settings, _) {
          return MaterialApp(
            title: 'ArthaTrack',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.lightTheme,
            darkTheme: AppTheme.darkTheme,
            themeMode: settings.themeMode,
            home: const MainShellScreen(),
          );
        },
      ),
    );
  }
}
