import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../config/api_config.dart';
import '../providers/auth_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/sync_provider.dart';
import '../providers/theme_provider.dart';
import '../widgets/app_drawer.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {

  void _showLogoutDialog(BuildContext context, AuthProvider auth, bool isHindi) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        title: Row(
          children: [
            const Icon(Icons.logout_rounded, color: Colors.red),
            const SizedBox(width: 8),
            Text(isHindi ? 'लॉग आउट करें?' : 'Log Out?'),
          ],
        ),
        content: Text(
          isHindi
              ? 'क्या आप वाकई अपने खाते से लॉग आउट करना चाहते हैं?'
              : 'Are you sure you want to log out of your account?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isHindi ? 'रद्द करें' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red.shade700,
              foregroundColor: Colors.white,
            ),
            onPressed: () async {
              Navigator.pop(ctx);
              await auth.logout();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            child: Text(isHindi ? 'हाँ, लॉग आउट करें' : 'Yes, Log Out'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = Provider.of<AuthProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final isHindi = localeProvider.isHindi;
    final syncProvider = Provider.of<SyncProvider>(context);
    final themeProvider = Provider.of<TenantThemeProvider>(context);

    final tenantName = (auth.tenantName != null && auth.tenantName!.isNotEmpty)
        ? auth.tenantName!
        : themeProvider.tenantName;
    final username = auth.username ?? 'Shopkeeper';
    final tenantCode = auth.tenantCode ?? 'STANDARD';
    final tenantId = auth.tenantId ?? 1;

    return Scaffold(
      backgroundColor: themeProvider.pageBgColor,
      drawer: const AppDrawer(),
      appBar: AppBar(
        backgroundColor: themeProvider.primaryColor,
        elevation: 2,
        title: Text(
          isHindi ? 'खाता एवं सेटिंग्स' : 'Account & Settings',
          style: TextStyle(
            fontFamily: themeProvider.fontFamily,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        actions: [
          IconButton(
            icon: Icon(
              localeProvider.isHindi ? Icons.g_translate_rounded : Icons.language_rounded,
              color: Colors.white,
            ),
            tooltip: 'Switch Language',
            onPressed: () {
              localeProvider.setLocale(
                localeProvider.isHindi ? const Locale('en') : const Locale('hi'),
              );
            },
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 950),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Pro User Account Header Banner
                _buildHeroProfileHeader(
                  context,
                  tenantName: tenantName,
                  username: username,
                  tenantCode: tenantCode,
                  tenantId: tenantId,
                  isHindi: isHindi,
                  themeProvider: themeProvider,
                  onLogout: () => _showLogoutDialog(context, auth, isHindi),
                ),
                const SizedBox(height: 24),

                // 2. Personal Profile & Account Details Grid
                _buildSectionTitle(
                  isHindi ? 'खाता विवरण' : 'Profile Details',
                  Icons.person_outline_rounded,
                  themeProvider,
                ),
                const SizedBox(height: 12),
                _buildPersonalDetailsCard(
                  context,
                  username: username,
                  tenantName: tenantName,
                  tenantCode: tenantCode,
                  tenantId: tenantId,
                  isHindi: isHindi,
                  themeProvider: themeProvider,
                ),
                const SizedBox(height: 24),

                // 3. App Preferences & Appearance Settings
                _buildSectionTitle(
                  isHindi ? 'ऐप सेटिंग्स' : 'App Preferences',
                  Icons.tune_rounded,
                  themeProvider,
                ),
                const SizedBox(height: 12),
                _buildPreferencesCard(
                  context,
                  isHindi: isHindi,
                  localeProvider: localeProvider,
                  themeProvider: themeProvider,
                ),
                const SizedBox(height: 24),

                // 4. WhatsApp Cloud API Gateway Credentials Card
                _buildSectionTitle(
                  isHindi ? 'व्हाट्सएप API सर्वर गेटवे' : 'WhatsApp API Gateway',
                  Icons.send_rounded,
                  themeProvider,
                ),
                const SizedBox(height: 12),
                _buildWhatsAppConfigCard(
                  context,
                  isHindi: isHindi,
                  themeProvider: themeProvider,
                ),
                const SizedBox(height: 24),

                // 5. Version Footer
                Center(
                  child: Column(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                        decoration: BoxDecoration(
                          color: themeProvider.primaryColor.withOpacity(0.08),
                          borderRadius: BorderRadius.circular(20),
                        ),
                        child: Text(
                          '${themeProvider.appTitle.isNotEmpty ? themeProvider.appTitle : "POS App"} v2.5.0',
                          style: TextStyle(
                            fontFamily: themeProvider.fontFamily,
                            color: themeProvider.primaryColor,
                            fontSize: 12 * themeProvider.fontSizeScale,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '© 2026 Ekargar All rights reserved.',
                        style: TextStyle(
                          fontFamily: themeProvider.fontFamily,
                          color: Colors.grey.shade500,
                          fontSize: 11 * themeProvider.fontSizeScale,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon, TenantThemeProvider themeProvider) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: themeProvider.primaryColor.withOpacity(0.12),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Icon(icon, size: 18, color: themeProvider.primaryColor),
        ),
        const SizedBox(width: 10),
        Text(
          title,
          style: TextStyle(
            fontFamily: themeProvider.fontFamily,
            fontSize: 16 * themeProvider.fontSizeScale,
            fontWeight: FontWeight.w800,
            color: themeProvider.textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroProfileHeader(
    BuildContext context, {
    required String tenantName,
    required String username,
    required String tenantCode,
    required int tenantId,
    required bool isHindi,
    required TenantThemeProvider themeProvider,
    required VoidCallback onLogout,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            themeProvider.primaryColor,
            themeProvider.secondaryColor,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: themeProvider.primaryColor.withOpacity(0.25),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Row(
            children: [
              // Owner Profile Circle Avatar
              Stack(
                children: [
                  CircleAvatar(
                    radius: 34,
                    backgroundColor: Colors.white,
                    child: CircleAvatar(
                      radius: 31,
                      backgroundColor: themeProvider.primaryColor,
                      child: Text(
                        username.isNotEmpty ? username[0].toUpperCase() : 'U',
                        style: TextStyle(
                          fontFamily: themeProvider.fontFamily,
                          color: Colors.white,
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    right: 2,
                    bottom: 2,
                    child: Container(
                      width: 14,
                      height: 14,
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.shade400,
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 2),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      username,
                      style: TextStyle(
                        fontFamily: themeProvider.fontFamily,
                        fontSize: 22 * themeProvider.fontSizeScale,
                        fontWeight: FontWeight.w900,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Icon(Icons.storefront_rounded, size: 14, color: Colors.white.withOpacity(0.85)),
                        const SizedBox(width: 4),
                        Expanded(
                          child: Text(
                            tenantName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: themeProvider.fontFamily,
                              fontSize: 14 * themeProvider.fontSizeScale,
                              color: Colors.white.withOpacity(0.9),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 8,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.white.withOpacity(0.3)),
                          ),
                          child: Text(
                            'Owner',
                            style: TextStyle(
                              fontFamily: themeProvider.fontFamily,
                              color: Colors.white,
                              fontSize: 11 * themeProvider.fontSizeScale,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.white.withOpacity(0.2),
                  foregroundColor: Colors.white,
                  elevation: 0,
                  side: BorderSide(color: Colors.white.withOpacity(0.4)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                icon: const Icon(Icons.logout_rounded, size: 16),
                label: Text(
                  isHindi ? 'लॉग आउट' : 'Log Out',
                  style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                ),
                onPressed: onLogout,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPersonalDetailsCard(
    BuildContext context, {
    required String username,
    required String tenantName,
    required String tenantCode,
    required int tenantId,
    required bool isHindi,
    required TenantThemeProvider themeProvider,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: themeProvider.cardBgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: themeProvider.textColor.withOpacity(0.08), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 600;
              return GridView.count(
                crossAxisCount: isWide ? 3 : 2,
                crossAxisSpacing: 14,
                mainAxisSpacing: 14,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                childAspectRatio: isWide ? 2.4 : 2.0,
                children: [
                  _buildDetailTile(
                    context,
                    isHindi ? 'यूजरनाम' : 'Username',
                    username,
                    Icons.account_circle_rounded,
                    Colors.blue.shade700,
                    themeProvider,
                  ),
                  _buildDetailTile(
                    context,
                    isHindi ? 'दुकान का नाम' : 'Shop / Store Name',
                    tenantName,
                    Icons.store_rounded,
                    themeProvider.primaryColor,
                    themeProvider,
                  ),
                  _buildDetailTile(
                    context,
                    isHindi ? 'टेनेंट आईडी' : 'Tenant ID',
                    '# $tenantId',
                    Icons.fingerprint_rounded,
                    Colors.purple.shade700,
                    themeProvider,
                  ),
                  _buildDetailTile(
                    context,
                    isHindi ? 'टेनेंट कोड' : 'Tenant Code',
                    tenantCode,
                    Icons.qr_code_rounded,
                    Colors.orange.shade800,
                    themeProvider,
                  ),
                  _buildDetailTile(
                    context,
                    isHindi ? 'हेल्पलाइन संपर्क' : 'Support Helpline',
                    themeProvider.supportPhone,
                    Icons.phone_in_talk_rounded,
                    Colors.green.shade700,
                    themeProvider,
                  ),
                  _buildDetailTile(
                    context,
                    isHindi ? 'ईमेल सपोर्ट' : 'Support Email',
                    themeProvider.supportEmail,
                    Icons.email_rounded,
                    Colors.teal.shade700,
                    themeProvider,
                  ),
                ],
              );
            },
          ),
          const Divider(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.verified_user_rounded, color: Colors.green.shade600, size: 18),
                  const SizedBox(width: 6),
                  Text(
                    isHindi ? 'सुरक्षित एन्क्रिप्टेड खाता' : 'Encrypted Multi-Tenant Account',
                    style: TextStyle(
                      fontFamily: themeProvider.fontFamily,
                      fontSize: 12 * themeProvider.fontSizeScale,
                      fontWeight: FontWeight.w600,
                      color: themeProvider.textColor.withOpacity(0.7),
                    ),
                  ),
                ],
              ),
              Text(
                '${isHindi ? "सपोर्ट समय" : "Support"}: ${themeProvider.supportHours}',
                style: TextStyle(
                  fontFamily: themeProvider.fontFamily,
                  fontSize: 12 * themeProvider.fontSizeScale,
                  fontWeight: FontWeight.bold,
                  color: themeProvider.primaryColor,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildDetailTile(
    BuildContext context,
    String label,
    String value,
    IconData icon,
    Color color,
    TenantThemeProvider themeProvider,
  ) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.15), width: 1),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: themeProvider.fontFamily,
                    fontSize: 11 * themeProvider.fontSizeScale,
                    color: themeProvider.textColor.withOpacity(0.6),
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  value,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: themeProvider.fontFamily,
                    fontSize: 13.5 * themeProvider.fontSizeScale,
                    fontWeight: FontWeight.w800,
                    color: themeProvider.textColor,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreferencesCard(
    BuildContext context, {
    required bool isHindi,
    required LocaleProvider localeProvider,
    required TenantThemeProvider themeProvider,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: themeProvider.cardBgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: themeProvider.textColor.withOpacity(0.08), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        children: [
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: themeProvider.primaryColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(
                isHindi ? Icons.g_translate_rounded : Icons.language_rounded,
                color: themeProvider.primaryColor,
              ),
            ),
            title: Text(
              isHindi ? 'इंटरफ़ेस भाषा' : 'App Language',
              style: TextStyle(
                fontFamily: themeProvider.fontFamily,
                fontWeight: FontWeight.bold,
                fontSize: 15 * themeProvider.fontSizeScale,
                color: themeProvider.textColor,
              ),
            ),
            subtitle: Text(
              isHindi ? 'हिंदी एवं अंग्रेजी भाषा स्विच करें' : 'Switch between English and Hindi',
              style: TextStyle(
                fontFamily: themeProvider.fontFamily,
                color: themeProvider.textColor.withOpacity(0.6),
                fontSize: 12 * themeProvider.fontSizeScale,
              ),
            ),
            trailing: Container(
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  GestureDetector(
                    onTap: () => localeProvider.setLocale(const Locale('en')),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: !isHindi ? themeProvider.primaryColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'English',
                        style: TextStyle(
                          color: !isHindi ? Colors.white : Colors.grey.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                  GestureDetector(
                    onTap: () => localeProvider.setLocale(const Locale('hi')),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                      decoration: BoxDecoration(
                        color: isHindi ? themeProvider.primaryColor : Colors.transparent,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        'हिंदी',
                        style: TextStyle(
                          color: isHindi ? Colors.white : Colors.grey.shade700,
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Divider(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildPrefSubTile(
                isHindi ? 'मुद्रा सिंबल' : 'Currency Symbol',
                themeProvider.currencySymbol,
                Icons.currency_rupee_rounded,
                themeProvider,
              ),
              _buildPrefSubTile(
                isHindi ? 'फॉन्ट फैमिली' : 'Font Family',
                themeProvider.fontFamily,
                Icons.font_download_rounded,
                themeProvider,
              ),
              _buildPrefSubTile(
                isHindi ? 'टेक्स्ट स्केल' : 'Text Scale',
                '${(themeProvider.fontSizeScale * 100).toStringAsFixed(0)}%',
                Icons.format_size_rounded,
                themeProvider,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPrefSubTile(String title, String value, IconData icon, TenantThemeProvider themeProvider) {
    return Column(
      children: [
        Icon(icon, size: 18, color: themeProvider.primaryColor),
        const SizedBox(height: 4),
        Text(
          title,
          style: TextStyle(
            fontFamily: themeProvider.fontFamily,
            fontSize: 11 * themeProvider.fontSizeScale,
            color: themeProvider.textColor.withOpacity(0.6),
          ),
        ),
        Text(
          value,
          style: TextStyle(
            fontFamily: themeProvider.fontFamily,
            fontSize: 13 * themeProvider.fontSizeScale,
            fontWeight: FontWeight.bold,
            color: themeProvider.textColor,
          ),
        ),
      ],
    );
  }

  Widget _buildSyncEngineCard(
    BuildContext context, {
    required bool isHindi,
    required SyncProvider syncProvider,
    required TenantThemeProvider themeProvider,
  }) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: themeProvider.cardBgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: themeProvider.textColor.withOpacity(0.08), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: syncProvider.pendingSyncCount > 0
                ? Colors.orange.shade100
                : Colors.green.shade100,
            borderRadius: BorderRadius.circular(12),
          ),
          child: Icon(
            syncProvider.pendingSyncCount > 0
                ? Icons.cloud_upload_rounded
                : Icons.check_circle_rounded,
            color: syncProvider.pendingSyncCount > 0
                ? Colors.orange.shade800
                : Colors.green.shade800,
            size: 24,
          ),
        ),
        title: Text(
          isHindi ? 'ऑफलाइन SQLite सिंक क्यू' : 'Offline Queue Sync Engine',
          style: TextStyle(
            fontFamily: themeProvider.fontFamily,
            fontWeight: FontWeight.bold,
            fontSize: 15 * themeProvider.fontSizeScale,
            color: themeProvider.textColor,
          ),
        ),
        subtitle: Text(
          syncProvider.pendingSyncCount > 0
              ? '${syncProvider.pendingSyncCount} ${isHindi ? "आइटम सर्वर पर पेंडिंग हैं" : "items waiting to sync"}'
              : (isHindi ? 'सभी ट्रांजेक्शन क्लाउड DB पर सिंक हैं' : 'All transactions fully synced with Cloud DB'),
          style: TextStyle(
            fontFamily: themeProvider.fontFamily,
            color: syncProvider.pendingSyncCount > 0
                ? Colors.orange.shade900
                : Colors.green.shade800,
            fontSize: 12 * themeProvider.fontSizeScale,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: themeProvider.accentColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          ),
          icon: const Icon(Icons.sync_rounded, size: 16),
          label: Text(
            isHindi ? 'सिंक करें' : 'Sync Now',
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          onPressed: () async {
            await syncProvider.syncNow();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text(isHindi ? 'डेटा सिंक पूरा हुआ!' : 'Sync completed successfully!'),
                  backgroundColor: Colors.green.shade700,
                ),
              );
            }
          },
        ),
      ),
    );
  }

  Widget _buildFcmCredentialsCard(
    BuildContext context, {
    required bool isHindi,
    required TenantThemeProvider themeProvider,
  }) {
    final notifProvider = Provider.of<NotificationProvider>(context);
    final fcm = notifProvider.fcmConfig;

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: themeProvider.cardBgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: themeProvider.textColor.withOpacity(0.08), width: 1.2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Icon(Icons.mark_chat_unread_rounded, color: Colors.orange.shade800, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    isHindi ? 'FCM वेब एवं मोबाइल कंफ़िग' : 'FCM Web & Mobile Configuration',
                    style: TextStyle(
                      fontFamily: themeProvider.fontFamily,
                      fontSize: 14 * themeProvider.fontSizeScale,
                      fontWeight: FontWeight.bold,
                      color: themeProvider.textColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  'READY',
                  style: TextStyle(
                    color: Colors.green.shade800,
                    fontWeight: FontWeight.bold,
                    fontSize: 10,
                  ),
                ),
              ),
            ],
          ),
          const Divider(height: 20),
          _buildFcmKeyRow('FcmApiKey', fcm['fcmApiKey'] ?? '', themeProvider),
          _buildFcmKeyRow('FcmAuthDomain', fcm['fcmAuthDomain'] ?? '', themeProvider),
          _buildFcmKeyRow('FcmProjectId', fcm['fcmProjectId'] ?? '', themeProvider),
          _buildFcmKeyRow('FcmStorageBucket', fcm['fcmStorageBucket'] ?? '', themeProvider),
          _buildFcmKeyRow('FcmMessagingSenderId', fcm['fcmMessagingSenderId'] ?? '', themeProvider),
          _buildFcmKeyRow('FcmAppId', fcm['fcmAppId'] ?? '', themeProvider),
          _buildFcmKeyRow('measurementId', fcm['measurementId'] ?? '', themeProvider),
          _buildFcmKeyRow('FcmVapidKey', fcm['fcmVapidKey'] ?? '', themeProvider),
        ],
      ),
    );
  }

  Widget _buildFcmKeyRow(String key, String value, TenantThemeProvider themeProvider) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 160,
            child: Text(
              key,
              style: TextStyle(
                fontFamily: 'monospace',
                fontSize: 11 * themeProvider.fontSizeScale,
                fontWeight: FontWeight.bold,
                color: themeProvider.textColor.withOpacity(0.7),
              ),
            ),
          ),
          Expanded(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: Colors.grey.shade300),
              ),
              child: Text(
                value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 11 * themeProvider.fontSizeScale,
                  color: Colors.grey.shade900,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWhatsAppConfigCard(
    BuildContext context, {
    required bool isHindi,
    required TenantThemeProvider themeProvider,
  }) {
    final urlCtrl = TextEditingController(text: themeProvider.whatsappGatewayUrl);
    final instanceCtrl = TextEditingController(text: themeProvider.whatsappInstanceId);
    final apiKeyCtrl = TextEditingController(text: themeProvider.whatsappApiKey);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: themeProvider.cardBgColor,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.green.shade200, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  const Icon(Icons.send_rounded, color: Color(0xFF25D366), size: 22),
                  const SizedBox(width: 8),
                  Text(
                    isHindi ? 'व्हाट्सएप गेटवे API कंफ़िग' : 'WhatsApp Server Gateway API Settings',
                    style: TextStyle(
                      fontFamily: themeProvider.fontFamily,
                      fontSize: 14 * themeProvider.fontSizeScale,
                      fontWeight: FontWeight.bold,
                      color: themeProvider.textColor,
                    ),
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.green.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'SQL DB GATEWAY',
                  style: TextStyle(color: Color(0xFF25D366), fontWeight: FontWeight.bold, fontSize: 10),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isHindi
                ? 'एडमिन पैनल से सीधे SQL डेटाबेस टेबल (V_TenantConfigurations) में WhatsApp API Key और URL सेट करें:'
                : 'Configure WhatsApp Cloud / Green-API credentials saved directly in SQL database table:',
            style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: urlCtrl,
            decoration: const InputDecoration(
              labelText: 'Gateway API URL (Green-API / Meta Cloud API)',
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: instanceCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Instance ID (waInstance)',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: apiKeyCtrl,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'API Token / Key',
                    border: OutlineInputBorder(),
                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF25D366),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              icon: const Icon(Icons.save_rounded, size: 18),
              label: Text(isHindi ? 'डेटाबेस में API Key सेव करें' : 'Save WhatsApp API Keys to DB Table'),
              onPressed: () async {
                await themeProvider.updateWhatsAppGatewayConfig(
                  gatewayUrl: urlCtrl.text.trim(),
                  instanceId: instanceCtrl.text.trim(),
                  apiKey: apiKeyCtrl.text.trim(),
                );
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(isHindi ? 'WhatsApp API गेटवे सेटिंग्स SQL डेटाबेस में सेव हुईं!' : 'WhatsApp API Gateway settings saved to SQL database!'),
                      backgroundColor: Colors.green.shade700,
                    ),
                  );
                }
              },
            ),
          ),
        ],
      ),
    );
  }
}
