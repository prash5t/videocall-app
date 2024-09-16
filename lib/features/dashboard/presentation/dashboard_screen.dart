import 'package:flutter/material.dart';
import 'package:socket_io_client/socket_io_client.dart' as IO;
import '../../videocall/presentation/videocall_screen.dart';
import '../../../core/routes/app_routes.dart';

class DashboardScreen extends StatefulWidget {
  final String userEmail;

  const DashboardScreen({Key? key, required this.userEmail}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final TextEditingController _emailController = TextEditingController();
  late IO.Socket socket;

  @override
  void initState() {
    super.initState();
    _connectSocket();
  }

  void _connectSocket() {
    socket = IO.io('http://10.10.10.39:5008', <String, dynamic>{
      'transports': ['websocket'],
      'autoConnect': false,
      'query': {'email': widget.userEmail}
    });

    socket.connect();
    socket.on('incoming_call', _handleIncomingCall);
  }

  void _handleIncomingCall(dynamic data) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Incoming call from ${data['caller_email']}'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              socket.emit('call_response', {
                'call_id': data['call_id'],
                'response': 'reject',
                'caller_email': data['caller_email'],
                'callee_email': widget.userEmail,
              });
            },
            child: Text('Reject'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              socket.emit('call_response', {
                'call_id': data['call_id'],
                'response': 'accept',
                'caller_email': data['caller_email'],
                'callee_email': widget.userEmail,
              });
              _navigateToVideoCall(data['call_id'], data['caller_email']);
            },
            child: Text('Accept'),
          ),
        ],
      ),
    );
  }

  void _initiateCall() {
    final calleeEmail = _emailController.text.trim();
    if (calleeEmail.isNotEmpty) {
      socket.emit('call_request', {
        'caller_email': widget.userEmail,
        'callee_email': calleeEmail,
      });

      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('Calling $calleeEmail...'),
          content: Text('Waiting for response...'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
                // Implement call cancellation logic here
              },
              child: Text('Cancel'),
            ),
          ],
        ),
      );

      socket.once('call_accepted', (data) {
        Navigator.of(context).pop(); // Close the calling dialog
        _navigateToVideoCall(data['call_id'], calleeEmail);
      });

      socket.once('call_rejected', (data) {
        Navigator.of(context).pop(); // Close the calling dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Call not accepted')),
        );
      });

      socket.once('user_unavailable', (data) {
        Navigator.of(context).pop(); // Close the calling dialog
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('User is unavailable')),
        );
      });
    }
  }

  void _navigateToVideoCall(String callId, String otherUserEmail) {
    Navigator.pushNamed(
      context,
      AppRoutes.videoCall,
      arguments: {
        'callId': callId,
        'userEmail': widget.userEmail,
        'otherUserEmail': otherUserEmail,
        'socket': socket,
      },
    ).then((_) => _emailController.clear());
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Dashboard')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'Enter email to call',
                border: OutlineInputBorder(),
              ),
            ),
            SizedBox(height: 16),
            ElevatedButton(
              onPressed: _initiateCall,
              child: Text('Start Video Call'),
            ),
          ],
        ),
      ),
    );
  }

  @override
  void dispose() {
    socket.disconnect();
    _emailController.dispose();
    super.dispose();
  }
}
