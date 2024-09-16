import 'package:flutter/material.dart';
import 'core/routes/route_generator.dart';

class VideoCallApp extends StatelessWidget {
  const VideoCallApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Video Call App',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      initialRoute: '/',
      onGenerateRoute: RouteGenerator.generateRoute,
    );
  }
}
