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

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const VillageShopApp());
}

class VillageShopApp extends StatefulWidget {
  const VillageShopApp({super.key});

  @override
  State<VillageShopApp> createState() => _VillageShopAppState();
}

class _VillageShopAppState extends State<VillageShopApp> {
  bool _initialized = false;

  @override
  void initState() {
    super.initState();
    _initApp();
  }

  Future<void> _initApp() async {
    final authProvider = AuthProvider();
    await authProvider.init();
    
    final themeProvider = TenantThemeProvider();
    if (authProvider.isAuthenticated) {
      await themeProvider.fetchAndApplyConfig(
        authProvider.accessToken ?? '',
        authProvider.tenantCode,
        authProvider.tenantId,
      );
    }

    if (mounted) {
      setState(() {
        _initialized = true;
      });
    }
  }

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
      child: Consumer3<AuthProvider, LocaleProvider, TenantThemeProvider>(
        builder: (context, authProvider, localeProvider, themeProvider, child) {
          if (!authProvider.isInitialized) {
            return const MaterialApp(
              debugShowCheckedModeBanner: false,
              home: Scaffold(
                body: Center(
                  child: CircularProgressIndicator(),
                ),
              ),
            );
          }

          final initialRoute = authProvider.isAuthenticated ? '/home' : '/login';

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
            initialRoute: initialRoute,
            routes: {
              '/login': (context) => const LoginScreen(),
              '/home': (context) => const HomeScreen(),
              '/pos': (context) => const PosScreen(),
              '/products': (context) => const ProductsScreen(),
              '/customers': (context) => const CustomersScreen(),
              '/reports': (context) => const ReportsScreen(),
              '/settings': (context) => const SettingsScreen(),
            },
          );
        },
      ),
    );
  }
}
