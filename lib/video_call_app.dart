import 'package:flutter/material.dart';
import 'core/routes/route_generator.dart';
import 'core/routes/app_routes.dart';

class VideoCallApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Call App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      onGenerateRoute: RouteGenerator.generateRoute,
    );
  }
}
