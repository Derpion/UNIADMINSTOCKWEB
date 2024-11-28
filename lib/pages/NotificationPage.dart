import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';

class AdminNotificationPage extends StatefulWidget {
  @override
  _AdminNotificationPageState createState() => _AdminNotificationPageState();
}

class _AdminNotificationPageState extends State<AdminNotificationPage> {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text("Admin Notifications"),
        centerTitle: true,
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: _firestore.collection('admin_notifications').orderBy('timestamp', descending: true).snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }

          if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
            return Center(child: Text('No notifications available.'));
          }

          List<QueryDocumentSnapshot> notifications = snapshot.data!.docs;

          return ListView.separated(
            itemCount: notifications.length,
            separatorBuilder: (context, index) => Divider(thickness: 1, color: Colors.grey), // Divider between each item
            itemBuilder: (context, index) {
              Map<String, dynamic> notificationData = notifications[index].data() as Map<String, dynamic>;

              String message = notificationData['message'] ?? 'No message';
              String status = notificationData['status'] ?? 'unread';
              Timestamp? timestamp = notificationData['timestamp'];
              String formattedDate = timestamp != null
                  ? DateFormat('yyyy-MM-dd HH:mm:ss').format(timestamp.toDate())
                  : 'No Date';

              return ListTile(
                leading: Icon(
                  status == 'unread' ? Icons.notifications : Icons.notifications_none,
                  color: status == 'unread' ? Colors.blue : Colors.grey,
                ),
                title: Text(message),
                subtitle: Text(formattedDate),
                trailing: status == 'unread'
                    ? ElevatedButton(
                  onPressed: () {
                    _markAsRead(notifications[index].id);
                  },
                  child: Text("Mark as Read"),
                )
                    : null,
              );
            },
          );
        },
      ),
    );
  }

  Future<void> _markAsRead(String docId) async {
    try {
      await _firestore.collection('admin_notifications').doc(docId).update({
        'status': 'read',
      });
      print("Notification marked as read.");
    } catch (e) {
      print("Failed to mark notification as read: $e");
    }
  }
}
