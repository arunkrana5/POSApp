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
  final _userController = TextEditingController();
  final _passwordController = TextEditingController();
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
                  Icon(Icons.storefront_rounded, size: 64, color: themeProvider.primaryColor),
                  const SizedBox(height: 12),
                  const Text("Shop Portal",
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFF0F172A)),
                  ),
                  const Text("दुकानदार लॉगिन (Shopkeeper Login)", style: TextStyle(color: Color(0xFF64748B), fontWeight: FontWeight.w500)),
                  const SizedBox(height: 24),
                  if (_errorMessage != null) ...[
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(color: const Color(0xFFFEE2E2), borderRadius: BorderRadius.circular(8)),
                      child: Text(_errorMessage!, style: const TextStyle(color: Color(0xFFDC2626), fontWeight: FontWeight.bold)),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _userController,
                    style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600, fontSize: 16),
                    decoration: InputDecoration(
                      labelText: "Username / यूजरनाम",
                      labelStyle: const TextStyle(color: Color(0xFF475569)),
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(Icons.person_rounded, color: themeProvider.primaryColor),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    style: const TextStyle(color: Color(0xFF0F172A), fontWeight: FontWeight.w600, fontSize: 16),
                    decoration: InputDecoration(
                      labelText: "Password / पासवर्ड",
                      labelStyle: const TextStyle(color: Color(0xFF475569)),
                      border: const OutlineInputBorder(),
                      prefixIcon: Icon(Icons.lock_rounded, color: themeProvider.primaryColor),
                      filled: true,
                      fillColor: Colors.white,
                    ),
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeProvider.buttonBgColor,
                        foregroundColor: Colors.white,
                        elevation: 2,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                      ),
                      onPressed: auth.isLoading
                          ? null
                          : () async {
                              setState(() => _errorMessage = null);
                              final res = await auth.login(
                                '',
                                _userController.text.trim(),
                                _passwordController.text.trim(),
                              );
                              if (res.status) {
                                if (mounted) {
                                  // Fetch & apply live tenant theme and white-label branding for logged in tenant
                                  await Provider.of<TenantThemeProvider>(context, listen: false)
                                      .fetchAndApplyConfig(auth.accessToken ?? '', auth.tenantCode, auth.tenantId);

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
                          : const Text("लॉगिन करें (LOGIN)", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.white)),
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
