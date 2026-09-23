import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';
import '../providers/theme_provider.dart';
import 'home_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _tenantController = TextEditingController(text: 'SHARMA_SHOP');
  final _userController = TextEditingController(text: 'admin');
  final _passwordController = TextEditingController(text: 'admin123');
  String? _errorMessage;

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final themeProvider = Provider.of<TenantThemeProvider>(context);

    return Scaffold(
      backgroundColor: const Color(0xFFF8FAFC),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24.0),
          child: Card(
            elevation: 4,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.storefront, size: 64, color: Color(0xFF2563EB)),
                  const SizedBox(height: 12),
                  Text(
                    themeProvider.tenantName.isNotEmpty && themeProvider.tenantName != "Store Client" 
                        ? themeProvider.tenantName 
                        : "Shop SaaS Portal",
                    style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const Text("दुकानदार लॉगिन (Shopkeeper Login)", style: TextStyle(color: Colors.grey)),
                  const SizedBox(height: 24),
                  if (_errorMessage != null) ...[
                    Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontWeight: FontWeight.bold)),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _tenantController,
                    decoration: const InputDecoration(
                      labelText: "Tenant Code / कोड",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.business),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _userController,
                    decoration: const InputDecoration(
                      labelText: "Username / यूजरनाम",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Password / पासवर्ड",
                      border: OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock),
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: auth.isLoading
                          ? null
                          : () async {
                              setState(() => _errorMessage = null);
                              ApiConfig.baseUrl = 'https://villageshop-api.onrender.com/api';
                              final res = await auth.login(
                                _tenantController.text.trim(),
                                _userController.text.trim(),
                                _passwordController.text.trim(),
                              );
                              if (res.status) {
                                if (mounted) {
                                  // Fetch & apply live tenant theme and white-label branding from SQL Server
                                  await Provider.of<TenantThemeProvider>(context, listen: false)
                                      .fetchAndApplyConfig(auth.accessToken ?? '');

                                  if (mounted) {
                                    Navigator.pushReplacement(
                                      context,
                                      MaterialPageRoute(builder: (_) => const HomeScreen()),
                                    );
                                  }
                                }
                              } else {
                                setState(() => _errorMessage = res.message);
                              }
                            },
                      child: auth.isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text("लॉगिन करें (LOGIN)", style: TextStyle(fontSize: 18)),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
