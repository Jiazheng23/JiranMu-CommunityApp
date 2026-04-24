// import 'package:flutter_local_notifications/flutter_local_notifications.dart';
//
// class NotificationService {
//   static final FlutterLocalNotificationsPlugin _plugin =
//   FlutterLocalNotificationsPlugin();
//
//   static Future<void> init() async {
//     const AndroidInitializationSettings androidInit =
//     AndroidInitializationSettings('@mipmap/ic_launcher');
//
//     const InitializationSettings settings =
//     InitializationSettings(android: androidInit);
//
//     await _plugin.initialize(settings: settings);
//     await _plugin
//         .resolvePlatformSpecificImplementation<
//         AndroidFlutterLocalNotificationsPlugin>()
//         ?.requestNotificationsPermission();
//   }
//
//
//   static Future<void> showNotification(String title, String body) async {
//     const AndroidNotificationDetails androidDetails =
//     AndroidNotificationDetails(
//       'chat_channel',
//       'Chat Notifications',
//       channelDescription: 'Chat message notifications',
//       importance: Importance.max,
//       priority: Priority.high,
//     );
//
//     const NotificationDetails details =
//     NotificationDetails(android: androidDetails);
//
//     final id = DateTime
//         .now()
//         .millisecondsSinceEpoch ~/ 1000;
//
//     await _plugin.show(
//       id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
//       title: title,
//       body: body,
//       notificationDetails: details,
//     );
//   }
// }