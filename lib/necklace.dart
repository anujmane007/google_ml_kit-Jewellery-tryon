import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show ByteData, WriteBuffer, rootBundle;

class NecklaceTryOnApp extends StatefulWidget {
  final List<CameraDescription> cameras;
  const NecklaceTryOnApp({Key? key, required this.cameras}) : super(key: key);

  @override
  _NecklaceTryOnAppState createState() => _NecklaceTryOnAppState();
}

class _NecklaceTryOnAppState extends State<NecklaceTryOnApp> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  late PoseDetector _poseDetector;
  ui.Image? _necklaceImage;
  bool _isProcessing = false;
  List<Pose> _poses = [];
  int _selectedCameraIdx = 1;
  int _frameCount = 0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _poseDetector = GoogleMlKit.vision
        .poseDetector(poseDetectorOptions: PoseDetectorOptions());
    _loadNecklaceImage();
  }

  Future<void> _initializeCamera() async {
    print('Initializing camera...');

    if (widget.cameras.length > 1) {
      _controller = CameraController(
        widget.cameras[_selectedCameraIdx],
        ResolutionPreset.high, // High Resolution
        enableAudio: false,
      );
    } else {
      // default back camera if one camera available
      _controller = CameraController(
        widget.cameras[0],
        ResolutionPreset.high,
        enableAudio: false,
      );
    }

    _initializeControllerFuture = _controller.initialize().then((_) {
      if (!mounted) return;
      _controller.setFlashMode(FlashMode.off);
      setState(() {});
      print('Camera initialized.');
      _controller.startImageStream(_processCameraImage); //Process Camera image
    }).catchError((Object e) {
      if (e is CameraException) {
        switch (e.code) {
          case 'CameraAccessDenied':
            print('User denied camera access.');
            break;
          default:
            print('Handle other camera errors: $e');
            break;
        }
      }
    });
  }

  //Load Necklace Image
  Future<void> _loadNecklaceImage() async {
    print('Loading necklace image...');
    try {
      final ByteData data = await rootBundle.load('assets/necklace.png');
      final ui.Codec codec =
          await ui.instantiateImageCodec(data.buffer.asUint8List());
      final ui.FrameInfo fi = await codec.getNextFrame();
      setState(() {
        _necklaceImage = fi.image;
      });
      print('Necklace image loaded.');
    } catch (e) {
      print('Error loading necklace image: $e');
    }
  }

  //Process Every Camera frame by frame
  void _processCameraImage(CameraImage image) async {
    if (_isProcessing) return;
    _isProcessing = true;

    // Control Framecount
    if (_frameCount % 5 != 0) {
      // Process every 5th frame
      _isProcessing = false;
      _frameCount++;
      return;
    }
    print('Processing camera image...');

    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize =
          Size(image.width.toDouble(), image.height.toDouble());
      final inputImageRotation =
          InputImageRotation.rotation90deg; // Adjust for camera orientation

      final inputImageFormat = InputImageFormat.nv21; // Image format nv21
      final inputImageData = InputImageMetadata(
        size: imageSize,
        rotation: inputImageRotation,
        format: inputImageFormat,
        bytesPerRow: image.planes[0].bytesPerRow,
      );

      final inputImage =
          InputImage.fromBytes(bytes: bytes, metadata: inputImageData);
      final poses = await _poseDetector.processImage(inputImage);

      if (mounted) {
        setState(() {
          _poses = poses;
        });
      }

      if (poses.isEmpty) {
        print('No poses detected. Check the camera feed.');
      } else {
        print('Pose(s) detected.');
      }
    } catch (e) {
      print('Error processing image: $e');
    } finally {
      _isProcessing = false;
      _frameCount++;
    }
  }

  void _switchCamera() {
    setState(() {
      _selectedCameraIdx = (_selectedCameraIdx + 1) % widget.cameras.length;
      _initializeCamera();
    });
  }

  @override
  void dispose() {
    _controller.stopImageStream();
    _controller.dispose();
    _poseDetector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Necklace Virtual Try-On'),
        actions: [
          IconButton(
            icon: Icon(Icons.switch_camera),
            onPressed: _switchCamera,
          ),
        ],
      ),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return CameraPreview(
              _controller,
              child: CustomPaint(
                size: Size(
                  MediaQuery.of(context).size.width,
                  MediaQuery.of(context).size.height,
                ),
                painter: NecklacePainter(
                    //Paint the necklace on detected landmarks
                    _poses,
                    _necklaceImage,
                    MediaQuery.of(context).size),
              ),
            );
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
    );
  }
}

class NecklacePainter extends CustomPainter {
  final List<Pose> poses;
  final ui.Image? necklaceImage;
  final Size previewSize;

  NecklacePainter(this.poses, this.necklaceImage, this.previewSize);

  @override
  void paint(Canvas canvas, Size size) {
    if (poses.isEmpty || necklaceImage == null) {
      print('No poses or necklace image to render.');
      return;
    }

    for (var pose in poses) {
      final landmarks = pose.landmarks;

      // Check for required landmarks
      if (landmarks.containsKey(PoseLandmarkType.leftShoulder) &&
          landmarks.containsKey(PoseLandmarkType.rightShoulder)) {
        final leftShoulder = landmarks[PoseLandmarkType.leftShoulder]!;
        final rightShoulder = landmarks[PoseLandmarkType.rightShoulder]!;

        // Normalize shoulder coordinates to fit canvas size
        final leftShoulderX = leftShoulder.x * size.width / previewSize.width;
        final leftShoulderY = leftShoulder.y * size.height / previewSize.height;
        final rightShoulderX = rightShoulder.x * size.width / previewSize.width;
        final rightShoulderY =
            rightShoulder.y * size.height / previewSize.height;

        print('Normalized Left Shoulder: ($leftShoulderX, $leftShoulderY)');
        print('Normalized Right Shoulder: ($rightShoulderX, $rightShoulderY)');

        // Adjust the X position with a slight right bias for better centering
        final necklaceCenterX = (leftShoulderX * 0.7 + rightShoulderX * 0.3);

        // Y position to be slightly below the shoulder line
        final shoulderMidY = (leftShoulderY + rightShoulderY) / 2;
        final necklaceCenterY = shoulderMidY + 20.0;

        // Debugging calculated necklace center position
        print('Calculated Necklace Center X: $necklaceCenterX');
        print('Calculated Necklace Center Y: $necklaceCenterY');

        // Determine shoulder width and scale the necklace accordingly
        final shoulderWidth = (rightShoulderX - leftShoulderX).abs();
        final necklaceWidth = shoulderWidth * 0.8;
        final scaleFactor = necklaceWidth / necklaceImage!.width;
        print('Calculated Shoulder Width: $shoulderWidth');
        print('Calculated Necklace Width: $necklaceWidth');
        print('Calculated Scale Factor: $scaleFactor');

        // Adjust offset to horizontally and vertically center the necklace
        final offset = Offset(
          necklaceCenterX - (necklaceImage!.width * scaleFactor) / 2,
          necklaceCenterY - (necklaceImage!.height * scaleFactor) / 2,
        );
        print('Adjusted Offset for Necklace Position: $offset');

        // Define the source and destination rectangles for scaling and positioning
        final src = Rect.fromLTWH(
          0,
          0,
          necklaceImage!.width.toDouble(),
          necklaceImage!.height.toDouble(),
        );

        final dst = Rect.fromLTWH(
          offset.dx,
          offset.dy,
          necklaceImage!.width * scaleFactor,
          necklaceImage!.height * scaleFactor,
        );

        // Draw the necklace image on the canvas
        canvas.drawImageRect(necklaceImage!, src, dst, Paint());
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true; // Repaint whenever poses change
  }
}
