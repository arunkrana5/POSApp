import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/locale_provider.dart';
import '../providers/notification_provider.dart';
import '../providers/theme_provider.dart';

class NotificationSheet extends StatefulWidget {
  const NotificationSheet({super.key});

  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => const NotificationSheet(),
    );
  }

  @override
  State<NotificationSheet> createState() => _NotificationSheetState();
}

class _NotificationSheetState extends State<NotificationSheet> {
  String _selectedFilter = 'ALL';

  @override
  Widget build(BuildContext context) {
    final notifProvider = Provider.of<NotificationProvider>(context);
    final localeProvider = Provider.of<LocaleProvider>(context);
    final themeProvider = Provider.of<TenantThemeProvider>(context);
    final isHindi = localeProvider.isHindi;

    final allItems = notifProvider.notifications;
    final filteredItems = allItems.where((n) {
      if (_selectedFilter == 'UNREAD') return !n.isRead;
      if (_selectedFilter == 'PUSH') return n.source == 'PUSH';
      return true;
    }).toList();

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: BoxDecoration(
        color: themeProvider.cardBgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Column(
        children: [
          // Drag handle pill
          const SizedBox(height: 12),
          Container(
            width: 44,
            height: 5,
            decoration: BoxDecoration(
              color: Colors.grey.shade300,
              borderRadius: BorderRadius.circular(10),
            ),
          ),
          const SizedBox(height: 12),

          // Header
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: themeProvider.primaryColor.withOpacity(0.1),
                        shape: BoxShape.circle,
                      ),
                      child: Icon(Icons.notifications_active_rounded, color: themeProvider.primaryColor, size: 22),
                    ),
                    const SizedBox(width: 10),
                    Text(
                      isHindi ? 'सूचना सेंटर' : 'Notifications Center',
                      style: TextStyle(
                        fontFamily: themeProvider.fontFamily,
                        fontSize: 18 * themeProvider.fontSizeScale,
                        fontWeight: FontWeight.bold,
                        color: themeProvider.textColor,
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (notifProvider.unreadCount > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: Colors.red.shade700,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          '${notifProvider.unreadCount} ${isHindi ? "नया" : "NEW"}',
                          style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                        ),
                      ),
                  ],
                ),
                if (allItems.isNotEmpty)
                  TextButton.icon(
                    style: TextButton.styleFrom(foregroundColor: themeProvider.primaryColor),
                    icon: const Icon(Icons.done_all_rounded, size: 16),
                    label: Text(
                      isHindi ? 'सभी पढ़ें' : 'Mark All Read',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    onPressed: () {
                      notifProvider.markAllAsRead();
                    },
                  ),
              ],
            ),
          ),
          const SizedBox(height: 8),

          // Filter pills
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Row(
              children: [
                _buildFilterChip('ALL', isHindi ? 'सभी (${allItems.length})' : 'All (${allItems.length})', themeProvider),
                const SizedBox(width: 8),
                _buildFilterChip('UNREAD', isHindi ? 'अपठित (${notifProvider.unreadCount})' : 'Unread (${notifProvider.unreadCount})', themeProvider),
              ],
            ),
          ),
          const Divider(height: 24),

          // Notification List
          Expanded(
            child: filteredItems.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.notifications_off_rounded, size: 54, color: Colors.grey.shade300),
                        const SizedBox(height: 12),
                        Text(
                          isHindi ? 'कोई सूचना नहीं है' : 'No Notifications Available',
                          style: TextStyle(
                            fontFamily: themeProvider.fontFamily,
                            fontSize: 15 * themeProvider.fontSizeScale,
                            fontWeight: FontWeight.bold,
                            color: Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    itemCount: filteredItems.length,
                    separatorBuilder: (ctx, i) => const SizedBox(height: 8),
                    itemBuilder: (ctx, index) {
                      final item = filteredItems[index];
                      return Dismissible(
                        key: Key('notif_${item.id}'),
                        direction: DismissDirection.endToStart,
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 20),
                          decoration: BoxDecoration(
                            color: Colors.red.shade600,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(Icons.delete_forever_rounded, color: Colors.white),
                        ),
                        onDismissed: (_) {
                          notifProvider.deleteNotification(item.id);
                        },
                        child: Container(
                          decoration: BoxDecoration(
                            color: item.isRead ? Colors.white : themeProvider.primaryColor.withOpacity(0.04),
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: item.isRead
                                  ? Colors.grey.shade200
                                  : themeProvider.primaryColor.withOpacity(0.25),
                              width: 1.2,
                            ),
                          ),
                          child: ListTile(
                            onTap: () {
                              if (!item.isRead) {
                                notifProvider.markAsRead(item.id);
                              }
                              if (item.gotoUrl.isNotEmpty) {
                                Navigator.pop(context);
                                Navigator.pushNamed(context, item.gotoUrl);
                              }
                            },
                            leading: Stack(
                              children: [
                                CircleAvatar(
                                  backgroundColor: _getCategoryColor(item.category).withOpacity(0.12),
                                  child: Icon(
                                    _getCategoryIcon(item.category),
                                    color: _getCategoryColor(item.category),
                                    size: 20,
                                  ),
                                ),
                                if (!item.isRead)
                                  Positioned(
                                    right: 0,
                                    top: 0,
                                    child: Container(
                                      width: 10,
                                      height: 10,
                                      decoration: BoxDecoration(
                                        color: themeProvider.primaryColor,
                                        shape: BoxShape.circle,
                                        border: Border.all(color: Colors.white, width: 1.5),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            title: Text(
                              item.title,
                              style: TextStyle(
                                fontFamily: themeProvider.fontFamily,
                                fontWeight: item.isRead ? FontWeight.w600 : FontWeight.w800,
                                fontSize: 14 * themeProvider.fontSizeScale,
                                color: themeProvider.textColor,
                              ),
                            ),
                            subtitle: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const SizedBox(height: 3),
                                Text(
                                  item.message,
                                  style: TextStyle(
                                    fontFamily: themeProvider.fontFamily,
                                    fontSize: 12 * themeProvider.fontSizeScale,
                                    color: themeProvider.textColor.withOpacity(0.7),
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    Icon(Icons.access_time_rounded, size: 12, color: Colors.grey.shade500),
                                    const SizedBox(width: 4),
                                    Text(
                                      item.createdDate,
                                      style: TextStyle(fontSize: 10, color: Colors.grey.shade500),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                            trailing: IconButton(
                              icon: const Icon(Icons.close_rounded, size: 18, color: Colors.grey),
                              onPressed: () {
                                notifProvider.deleteNotification(item.id);
                              },
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String key, String label, TenantThemeProvider themeProvider) {
    final isSelected = _selectedFilter == key;
    return GestureDetector(
      onTap: () => setState(() => _selectedFilter = key),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: isSelected ? themeProvider.primaryColor : Colors.grey.shade100,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? themeProvider.primaryColor : Colors.grey.shade300,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: isSelected ? Colors.white : Colors.grey.shade800,
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat.toUpperCase()) {
      case 'SALE':
      case 'PAYMENT':
        return Icons.payments_rounded;
      case 'STOCK':
      case 'LOW_STOCK':
        return Icons.inventory_2_rounded;
      case 'UDHAAR':
      case 'CUSTOMER':
        return Icons.people_alt_rounded;
      default:
        return Icons.notifications_active_rounded;
    }
  }

  Color _getCategoryColor(String cat) {
    switch (cat.toUpperCase()) {
      case 'SALE':
      case 'PAYMENT':
        return Colors.green.shade700;
      case 'STOCK':
      case 'LOW_STOCK':
        return Colors.orange.shade800;
      case 'UDHAAR':
      case 'CUSTOMER':
        return Colors.purple.shade700;
      default:
        return Colors.blue.shade700;
    }
  }
}
