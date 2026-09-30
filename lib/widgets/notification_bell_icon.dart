import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../providers/notification_provider.dart';
import 'notification_sheet.dart';

class NotificationBellIcon extends StatelessWidget {
  const NotificationBellIcon({super.key});

  @override
  Widget build(BuildContext context) {
    final notifProvider = Provider.of<NotificationProvider>(context);
    final count = notifProvider.unreadCount;

    return Stack(
      children: [
        IconButton(
          icon: const Icon(Icons.notifications_rounded, color: Colors.white),
          tooltip: 'Notifications',
          onPressed: () {
            NotificationSheet.show(context);
          },
        ),
        if (count > 0)
          Positioned(
            right: 6,
            top: 6,
            child: GestureDetector(
              onTap: () {
                NotificationSheet.show(context);
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: const BoxDecoration(
                  color: Colors.redAccent,
                  shape: BoxShape.circle,
                ),
                constraints: const BoxConstraints(
                  minWidth: 18,
                  minHeight: 18,
                ),
                child: Text(
                  count > 99 ? '99+' : '$count',
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
      ],
    );
  }
}
