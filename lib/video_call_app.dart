import 'package:flutter/material.dart';
import 'package:videocall/core/routes/route_generator.dart';

final navigatorKey = GlobalKey<NavigatorState>();

class VideoCallApp extends StatelessWidget {
  const VideoCallApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateRoute: onGenerateRoute,
      navigatorKey: navigatorKey,
    );
  }
}
