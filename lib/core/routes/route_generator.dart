import 'package:flutter/material.dart';
import 'package:videocall/core/routes/app_routes.dart';
import 'package:videocall/features/dashboard/presentation/dashboard_screen.dart';
import 'package:videocall/features/videocall/presentation/videocall_screen.dart';

Route<dynamic> onGenerateRoute(RouteSettings settings) {
  Object? argument = settings.arguments;
  switch (settings.name) {
    case AppRoutes.dashboard:
      return MaterialPageRoute(builder: (context) => const DashboardScreen());
    case AppRoutes.videoCall:
      return MaterialPageRoute(
          builder: (context) => VideoCallScreen(roomId: argument as String));
    default:
      return MaterialPageRoute(builder: (context) => const DashboardScreen());
  }
}
