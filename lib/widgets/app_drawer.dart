import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/auth_provider.dart';
import '../providers/sync_provider.dart';
import '../providers/locale_provider.dart';
import '../providers/theme_provider.dart';

class AppDrawer extends StatefulWidget {
  const AppDrawer({super.key});

  @override
  State<AppDrawer> createState() => _AppDrawerState();
}

class _AppDrawerState extends State<AppDrawer> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final themeProvider = Provider.of<TenantThemeProvider>(context, listen: false);
      final authProvider = Provider.of<AuthProvider>(context, listen: false);
      themeProvider.fetchAndApplyConfig(authProvider.accessToken ?? '');
    });
  }

  @override
  Widget build(BuildContext context) {
    final authProvider = Provider.of<AuthProvider>(context);
    final syncProvider = Provider.of<SyncProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final themeProvider = Provider.of<TenantThemeProvider>(context);

    final tenantName = authProvider.tenantName ?? themeProvider.tenantName;
    final isHindi = localeProvider.isHindi;
    final enabledMods = themeProvider.enabledModules;

    return Drawer(
      backgroundColor: themeProvider.pageBgColor,
      child: Column(
        children: [
          // Dynamic Custom Drawer Header
          Container(
            width: double.infinity,
            padding: EdgeInsets.fromLTRB(16, MediaQuery.of(context).padding.top + 16, 16, 18),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  themeProvider.primaryColor == Colors.white ? const Color(0xFF0F172A) : themeProvider.primaryColor,
                  (themeProvider.primaryColor == Colors.white ? const Color(0xFF0F172A) : themeProvider.primaryColor).withOpacity(0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              boxShadow: const [
                BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 3)),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Top Branding Row (Logo + Shop Name)
                Row(
                  children: [
                    // Dynamic Logo (Image URL or Emblem)
                    Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [themeProvider.secondaryColor, Colors.amber.shade700],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.amber.shade200, width: 1.5),
                        boxShadow: [
                          BoxShadow(
                            color: themeProvider.secondaryColor.withOpacity(0.35),
                            blurRadius: 10,
                            spreadRadius: 1,
                            offset: const Offset(0, 3),
                          ),
                        ],
                      ),
                      child: Center(
                        child: themeProvider.logoUrl.isNotEmpty
                            ? ClipRRect(
                                borderRadius: BorderRadius.circular(24),
                                child: Image.network(
                                  themeProvider.logoUrl,
                                  width: 48,
                                  height: 48,
                                  fit: BoxFit.cover,
                                  errorBuilder: (_, __, ___) => const Icon(Icons.storefront_rounded, size: 26, color: Colors.white),
                                ),
                              )
                            : const Icon(
                                Icons.storefront_rounded,
                                size: 26,
                                color: Colors.white,
                              ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    // Dynamic Tenant Shop Title & Platform Badge
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: Text(
                              themeProvider.appTitle.isNotEmpty ? themeProvider.appTitle : (isHindi ? 'दुकान POS' : 'STORE POS'),
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 10,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.1,
                              ),
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            tenantName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Navigation Links List (Dynamically Generated from Admin Panel API)
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                if (themeProvider.dynamicMenuItems.where((m) {
                  final isEnabled = m['IsEnabled'] ?? m['isEnabled'] ?? m['is_enabled'];
                  if (isEnabled == null) return true;
                  if (isEnabled is bool) return isEnabled;
                  if (isEnabled is String) return isEnabled.toLowerCase() == 'true';
                  if (isEnabled is num) return isEnabled != 0;
                  return true;
                }).isNotEmpty)
                  ...themeProvider.dynamicMenuItems.where((m) {
                    final isEnabled = m['IsEnabled'] ?? m['isEnabled'] ?? m['is_enabled'];
                    if (isEnabled == null) return true;
                    if (isEnabled is bool) return isEnabled;
                    if (isEnabled is String) return isEnabled.toLowerCase() == 'true';
                    if (isEnabled is num) return isEnabled != 0;
                    return true;
                  }).map((item) {
                    final titleEn = (item['TitleEn'] ?? item['titleEn'] ?? '').toString();
                    final titleHi = (item['TitleHi'] ?? item['titleHi'] ?? '').toString();
                    final title = isHindi ? (titleHi.isNotEmpty ? titleHi : titleEn) : (titleEn.isNotEmpty ? titleEn : 'Menu Item');
                    final badge = (item['BadgeText'] ?? item['badgeText'] ?? '').toString();
                    final iconName = (item['Icon'] ?? item['icon'] ?? '').toString();
                    final route = (item['Route'] ?? item['route'] ?? '/home').toString();

                    return _buildDrawerItem(
                      context,
                      icon: _getIconData(iconName),
                      title: title,
                      route: route,
                      badgeText: badge.isNotEmpty ? badge : null,
                      badgeColor: Colors.amber.shade700,
                    );
                  }).toList()
                else ...[
                  _buildDrawerItem(
                    context,
                    icon: Icons.dashboard_rounded,
                    title: isHindi ? 'डैशबोर्ड' : 'Dashboard',
                    route: '/home',
                  ),
                  if (enabledMods.contains('POS'))
                    _buildDrawerItem(
                      context,
                      icon: Icons.point_of_sale_rounded,
                      title: isHindi ? 'नया बिल / POS' : 'New Sale / POS',
                      route: '/pos',
                      badgeColor: Colors.amber.shade700,
                      badgeText: 'FAST',
                    ),
                  if (enabledMods.contains('Products'))
                    _buildDrawerItem(
                      context,
                      icon: Icons.inventory_2_rounded,
                      title: isHindi ? 'सामान और स्टॉक' : 'Products & Stock',
                      route: '/products',
                    ),
                  if (enabledMods.contains('Customers'))
                    _buildDrawerItem(
                      context,
                      icon: Icons.people_alt_rounded,
                      title: isHindi ? 'ग्राहक उधार खाता' : 'Customer Udhaar',
                      route: '/customers',
                    ),
                  if (enabledMods.contains('Reports'))
                    _buildDrawerItem(
                      context,
                      icon: Icons.analytics_rounded,
                      title: isHindi ? 'रिपोर्ट और कमाई' : 'Reports & Earnings',
                      route: '/reports',
                    ),
                ],
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Divider(height: 1),
                ),

                // Sync Status Section
                ListTile(
                  dense: true,
                  leading: Icon(
                    syncProvider.isSyncing
                        ? Icons.sync_rounded
                        : (syncProvider.pendingSyncCount > 0
                            ? Icons.cloud_upload_rounded
                            : Icons.cloud_done_rounded),
                    color: syncProvider.pendingSyncCount > 0 ? Colors.orange.shade700 : const Color(0xFF10B981),
                    size: 24,
                  ),
                  title: Text(
                    isHindi ? 'सिंक स्थिति' : 'Sync Status',
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: Color(0xFF1E293B)),
                  ),
                  subtitle: Text(
                    syncProvider.pendingSyncCount > 0
                        ? (isHindi
                            ? '${syncProvider.pendingSyncCount} डेटा पेंडिंग'
                            : '${syncProvider.pendingSyncCount} pending items')
                        : (isHindi ? 'सब डेटा सुरक्षित है' : 'Fully Synced'),
                    style: TextStyle(
                      fontSize: 11.5,
                      color: syncProvider.pendingSyncCount > 0 ? Colors.orange.shade900 : Colors.green.shade800,
                    ),
                  ),
                  trailing: ElevatedButton(
                    onPressed: syncProvider.isSyncing
                        ? null
                        : () async {
                            await syncProvider.syncNow();
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(isHindi ? 'सिंक पूरा हुआ!' : 'Sync completed successfully!'),
                                  backgroundColor: themeProvider.accentColor,
                                ),
                              );
                            }
                          },
                    style: ElevatedButton.styleFrom(
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      backgroundColor: themeProvider.buttonBgColor,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(6)),
                    ),
                    child: Text(
                      isHindi ? 'सिंक' : 'Sync',
                      style: TextStyle(fontSize: 11.5, color: themeProvider.buttonTextColor, fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
                const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                  child: Divider(height: 1),
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.settings_rounded,
                  title: isHindi ? 'सेटिंग्स' : 'Settings',
                  route: '/settings',
                ),

                // Language Switcher Tile
                ListTile(
                  dense: true,
                  leading: Icon(Icons.language_rounded, color: themeProvider.buttonBgColor, size: 24),
                  title: Text(
                    isHindi ? 'भाषा (Language)' : 'Language (हिंदी)',
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13.5, color: themeProvider.textColor),
                  ),
                  trailing: Switch(
                    value: isHindi,
                    onChanged: (val) {
                      localeProvider.setLocale(val ? const Locale('hi') : const Locale('en'));
                    },
                    activeColor: themeProvider.primaryColor,
                  ),
                ),
              ],
            ),
          ),

          // Bottom Logout Action & App Footer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: themeProvider.cardBgColor,
              border: Border(top: BorderSide(color: themeProvider.textColor.withOpacity(0.1))),
            ),
            child: Row(
              children: [
                Expanded(
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 8),
                    leading: const Icon(Icons.logout_rounded, color: Colors.redAccent, size: 22),
                    title: Text(
                      isHindi ? 'लॉगआउट' : 'Logout',
                      style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent, fontSize: 14),
                    ),
                    onTap: () => _showLogoutDialog(context, authProvider, isHindi),
                  ),
                ),
                Text(
                  'v1.0.4',
                  style: TextStyle(fontSize: 11, color: themeProvider.textColor.withOpacity(0.5), fontWeight: FontWeight.w500),
                ),
                const SizedBox(width: 8),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String route,
    Color? badgeColor,
    String? badgeText,
  }) {
    final themeProvider = Provider.of<TenantThemeProvider>(context);
    final currentRoute = ModalRoute.of(context)?.settings.name;
    final isSelected = currentRoute == route;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: isSelected ? themeProvider.primaryColor.withOpacity(0.12) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        dense: true,
        selected: isSelected,
        leading: Icon(
          icon,
          size: 22,
          color: isSelected ? themeProvider.primaryColor : themeProvider.textColor.withOpacity(0.7),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontFamily: themeProvider.fontFamily,
            fontWeight: isSelected ? FontWeight.bold : FontWeight.w500,
            color: isSelected ? themeProvider.primaryColor : themeProvider.textColor,
            fontSize: 14 * themeProvider.fontSizeScale,
          ),
        ),
        trailing: badgeText != null
            ? Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor ?? Colors.blue,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  badgeText,
                  style: const TextStyle(color: Colors.white, fontSize: 9.5, fontWeight: FontWeight.bold),
                ),
              )
            : null,
        onTap: () {
          Navigator.pop(context); // Close drawer
          if (!isSelected) {
            Navigator.pushReplacementNamed(context, route);
          }
        },
      ),
    );
  }

  void _showLogoutDialog(BuildContext context, AuthProvider authProvider, bool isHindi) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        title: Text(isHindi ? 'लॉगआउट की पुष्टि' : 'Confirm Logout'),
        content: Text(isHindi ? 'क्या आप लॉगआउट करना चाहते हैं?' : 'Are you sure you want to log out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text(isHindi ? 'रद्द करें' : 'Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              authProvider.logout();
              if (context.mounted) {
                Navigator.pushReplacementNamed(context, '/login');
              }
            },
            child: Text(isHindi ? 'हाँ, लॉगआउट' : 'Yes, Logout', style: const TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  IconData _getIconData(String iconName) {
    switch (iconName) {
      case 'point_of_sale_rounded':
        return Icons.point_of_sale_rounded;
      case 'inventory_2_rounded':
        return Icons.inventory_2_rounded;
      case 'people_alt_rounded':
        return Icons.people_alt_rounded;
      case 'analytics_rounded':
        return Icons.analytics_rounded;
      case 'settings_rounded':
        return Icons.settings_rounded;
      case 'local_offer':
        return Icons.local_offer_rounded;
      case 'qr_code':
        return Icons.qr_code_rounded;
      case 'support':
        return Icons.support_agent_rounded;
      case 'dashboard_rounded':
      default:
        return Icons.dashboard_rounded;
    }
  }
}

