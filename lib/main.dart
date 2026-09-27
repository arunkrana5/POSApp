import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:provider/provider.dart';

import 'providers/auth_provider.dart';
import 'providers/locale_provider.dart';
import 'providers/sync_provider.dart';
import 'providers/theme_provider.dart';

import 'screens/login_screen.dart';
import 'screens/home_screen.dart';
import 'screens/pos_screen.dart';
import 'screens/products_screen.dart';
import 'screens/customers_screen.dart';
import 'screens/reports_screen.dart';
import 'screens/settings_screen.dart';
import 'screens/sales_history_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VillageShopApp());
}

class VillageShopApp extends StatelessWidget {
  const VillageShopApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) {
          final p = AuthProvider();
          p.init();
          return p;
        }),
        ChangeNotifierProvider(create: (_) => LocaleProvider()),
        ChangeNotifierProvider(create: (_) => SyncProvider()),
        ChangeNotifierProvider(create: (_) => TenantThemeProvider()),
      ],
      child: Consumer2<LocaleProvider, TenantThemeProvider>(
        builder: (context, localeProvider, themeProvider, child) {
          return MaterialApp(
            title: 'VillageShop Mobile',
            debugShowCheckedModeBanner: false,
            locale: localeProvider.locale,
            supportedLocales: const [
              Locale('en', 'US'),
              Locale('hi', 'IN'),
            ],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            theme: themeProvider.themeData,
            home: const AuthWrapper(),
            routes: {
              '/login': (context) => const LoginScreen(),
              '/home': (context) => const HomeScreen(),
              '/pos': (context) => const PosScreen(),
              '/products': (context) => const ProductsScreen(),
              '/customers': (context) => const CustomersScreen(),
              '/reports': (context) => const ReportsScreen(),
              '/settings': (context) => const SettingsScreen(),
              '/sales-history': (context) => const SalesHistoryScreen(),
            },
          );
        },
      ),
    );
  }
}

class AuthWrapper extends StatefulWidget {
  const AuthWrapper({super.key});

  @override
  State<AuthWrapper> createState() => _AuthWrapperState();
}

class _AuthWrapperState extends State<AuthWrapper> {
  bool _themeFetched = false;

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<TenantThemeProvider>(context, listen: false);

    if (!authProvider.isInitialized) {
      return const Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    if (authProvider.isAuthenticated) {
      if (!_themeFetched) {
        _themeFetched = true;
        themeProvider.fetchAndApplyConfig(
          authProvider.accessToken ?? '',
          authProvider.tenantCode,
          authProvider.tenantId,
        );
      }
      return const HomeScreen();
    }

    return const LoginScreen();
  }
}
