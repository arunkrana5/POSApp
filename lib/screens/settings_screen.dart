import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../providers/locale_provider.dart';
import '../providers/sync_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/app_drawer.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final TextEditingController _urlController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _urlController.text = ApiConfig.baseUrl;
  }

  @override
  Widget build(BuildContext context) {
    final isHindi = Provider.of<LocaleProvider>(context).isHindi;
    final syncProvider = Provider.of<SyncProvider>(context);
    final themeProvider = Provider.of<TenantThemeProvider>(context);

    return Scaffold(
      backgroundColor: themeProvider.pageBgColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        title: Text(
          isHindi ? 'सेटिंग्स' : 'Settings',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Client Store Profile & Subscription Card
            Text(
              isHindi ? 'दुकान प्रोफ़ाइल एवं खाता (Client Profile)' : 'Client Profile & Store Info',
              style: TextStyle(
                fontFamily: themeProvider.fontFamily,
                fontSize: 16 * themeProvider.fontSizeScale,
                fontWeight: FontWeight.bold,
                color: themeProvider.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: themeProvider.cardBgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: themeProvider.textColor.withOpacity(0.08)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withOpacity(0.02), blurRadius: 4, offset: const Offset(0, 2)),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 24,
                        backgroundColor: themeProvider.primaryColor,
                        child: Text(
                          themeProvider.tenantName.isNotEmpty ? themeProvider.tenantName[0].toUpperCase() : 'V',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 20),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              themeProvider.tenantName,
                              style: TextStyle(
                                fontFamily: themeProvider.fontFamily,
                                fontSize: 16 * themeProvider.fontSizeScale,
                                fontWeight: FontWeight.bold,
                                color: themeProvider.textColor,
                              ),
                            ),
                            Text(
                              themeProvider.appTitle,
                              style: TextStyle(
                                fontFamily: themeProvider.fontFamily,
                                fontSize: 12 * themeProvider.fontSizeScale,
                                color: themeProvider.textColor.withOpacity(0.7),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: Colors.green.shade100,
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          'ACTIVE',
                          style: TextStyle(
                            color: Colors.green.shade800,
                            fontWeight: FontWeight.bold,
                            fontSize: 11,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const Divider(height: 24),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildProfileItem(isHindi ? 'हेल्पलाइन' : 'Helpline', themeProvider.supportPhone, themeProvider),
                      _buildProfileItem(isHindi ? 'ईमेल' : 'Email', themeProvider.supportEmail, themeProvider),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      _buildProfileItem(isHindi ? 'मुद्रा' : 'Currency', themeProvider.currencySymbol, themeProvider),
                      _buildProfileItem(isHindi ? 'समय' : 'Support Hours', themeProvider.supportHours, themeProvider),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // API Server Address Config
            Text(
              isHindi ? 'सर्वर कनेक्शन' : 'Server Connection',
              style: TextStyle(
                fontFamily: themeProvider.fontFamily,
                fontSize: 16 * themeProvider.fontSizeScale,
                fontWeight: FontWeight.bold,
                color: themeProvider.textColor,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: themeProvider.cardBgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: themeProvider.textColor.withOpacity(0.08)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: _urlController,
                    decoration: InputDecoration(
                      labelText: isHindi ? 'API सर्वर URL' : 'API Server Base URL',
                      border: const OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: themeProvider.buttonBgColor,
                        foregroundColor: themeProvider.buttonTextColor,
                      ),
                      onPressed: () {
                        setState(() {
                          ApiConfig.baseUrl = _urlController.text;
                        });
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(isHindi ? 'सर्वर URL अपडेट हुआ' : 'Server URL updated successfully'),
                            backgroundColor: Colors.green.shade700,
                          ),
                        );
                      },
                      child: Text(
                        isHindi ? 'URL सेव करें' : 'Save Connection URL',
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),

            // Sync Status Log Card
            Text(
              isHindi ? 'डेटा सिंक इंजन' : 'Offline Sync Engine',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Color(0xFF1E293B)),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: themeProvider.cardBgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: themeProvider.textColor.withOpacity(0.08)),
              ),
              child: ListTile(
                leading: Icon(
                  syncProvider.pendingSyncCount > 0 ? Icons.cloud_upload_rounded : Icons.check_circle_rounded,
                  color: syncProvider.pendingSyncCount > 0 ? themeProvider.secondaryColor : themeProvider.accentColor,
                  size: 32,
                ),
                title: Text(
                  isHindi ? 'पेंडिंग सिंक आइटम' : 'Pending Offline Queue',
                  style: TextStyle(
                    fontFamily: themeProvider.fontFamily,
                    fontWeight: FontWeight.bold,
                    fontSize: 15 * themeProvider.fontSizeScale,
                    color: themeProvider.textColor,
                  ),
                ),
                subtitle: Text(
                  '${syncProvider.pendingSyncCount} ${isHindi ? "आइटम पेंडिंग हैं" : "items in SQLite queue"}',
                  style: TextStyle(
                    fontFamily: themeProvider.fontFamily,
                    color: themeProvider.textColor.withOpacity(0.6),
                  ),
                ),
                trailing: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeProvider.buttonBgColor,
                    foregroundColor: themeProvider.buttonTextColor,
                  ),
                  onPressed: () async {
                    await syncProvider.syncNow();
                  },
                  child: Text(isHindi ? 'सिंक करें' : 'Sync Now'),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // App Version Footer
            Center(
              child: Text(
                '${themeProvider.appTitle.isNotEmpty ? themeProvider.appTitle : "Smart Store"} Mobile Enterprise v2.4.0',
                style: TextStyle(color: Colors.grey.shade500, fontSize: 12, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildProfileItem(String label, String value, TenantThemeProvider themeProvider) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: themeProvider.textColor.withOpacity(0.6),
            fontFamily: themeProvider.fontFamily,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.bold,
            color: themeProvider.textColor,
            fontFamily: themeProvider.fontFamily,
          ),
        ),
      ],
    );
  }
}
