import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:jewel_tryon/screens/first.dart';

List<CameraDescription>? cameras;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  //Camera Initialization
  cameras = await availableCameras();
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Jewel Try-On',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      //UI Screen
      home: FirstScreen(cameras: cameras),
    );
  }
}
