import 'package:flutter/material.dart';
import '../../features/auth/presentation/login_screen.dart';
import '../../features/dashboard/presentation/dashboard_screen.dart';
import '../../features/videocall/presentation/videocall_screen.dart';
import 'app_routes.dart';

class RouteGenerator {
  static Route<dynamic> generateRoute(RouteSettings settings) {
    switch (settings.name) {
      case AppRoutes.login:
        return MaterialPageRoute(builder: (_) => LoginScreen());
      case AppRoutes.dashboard:
        final args = settings.arguments as Map<String, dynamic>?;
        return MaterialPageRoute(
          builder: (_) => DashboardScreen(
            userEmail: args?['userEmail'] ?? 'user1@example.com',
          ),
        );
      case AppRoutes.videoCall:
        final args = settings.arguments as Map<String, dynamic>;
        return MaterialPageRoute(
          builder: (_) => VideoCallScreen(
            callId: args['callId'],
            userEmail: args['userEmail'],
            otherUserEmail: args['otherUserEmail'],
            socket: args['socket'],
          ),
        );
      default:
        return MaterialPageRoute(builder: (_) => LoginScreen());
    }
  }
}
