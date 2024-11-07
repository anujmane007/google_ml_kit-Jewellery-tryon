import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_ml_kit/google_ml_kit.dart';
import 'dart:ui' as ui;
import 'package:flutter/services.dart' show ByteData, WriteBuffer, rootBundle;

class RingTryOnApp extends StatefulWidget {
  final List<CameraDescription> cameras;
  const RingTryOnApp({Key? key, required this.cameras}) : super(key: key);

  @override
  _RingTryOnAppState createState() => _RingTryOnAppState();
}

class _RingTryOnAppState extends State<RingTryOnApp> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  late PoseDetector _poseDetector;
  ui.Image? _ringImage;
  bool _isProcessing = false;
  List<Pose> _poses = [];
  int _selectedCameraIdx = 1;
  int _frameCount = 0;

  // For smoothing positions
  Offset? _leftPinkyAverage;
  Offset? _rightPinkyAverage;
  final int _smoothingWindow = 5;
  List<Offset> _leftPinkyHistory = [];
  List<Offset> _rightPinkyHistory = [];

  // Threshold for significant movement detection
  final double _movementThreshold = 20.0;

  @override
  void initState() {
    super.initState();
    _initializeCamera();
    _poseDetector = GoogleMlKit.vision
        .poseDetector(poseDetectorOptions: PoseDetectorOptions());
    _loadRingImage();
  }

  Future<void> _initializeCamera() async {
    if (widget.cameras.length > 1) {
      _controller = CameraController(
        widget.cameras[_selectedCameraIdx],
        ResolutionPreset.high,
        enableAudio: false,
      );
    } else {
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
      _controller.startImageStream(_processCameraImage);
    });
  }

  Future<void> _loadRingImage() async {
    try {
      final ByteData data = await rootBundle.load('assets/ring.png');
      final ui.Codec codec =
          await ui.instantiateImageCodec(data.buffer.asUint8List());
      final ui.FrameInfo fi = await codec.getNextFrame();
      setState(() {
        _ringImage = fi.image;
      });
    } catch (e) {
      print('Error loading ring image: $e');
    }
  }

  void _processCameraImage(CameraImage image) async {
    if (_isProcessing) return;
    _isProcessing = true;

    if (_frameCount % 5 != 0) {
      _isProcessing = false;
      _frameCount++;
      return;
    }

    try {
      final WriteBuffer allBytes = WriteBuffer();
      for (Plane plane in image.planes) {
        allBytes.putUint8List(plane.bytes);
      }
      final bytes = allBytes.done().buffer.asUint8List();

      final Size imageSize =
          Size(image.width.toDouble(), image.height.toDouble());
      final inputImageRotation = InputImageRotation.rotation90deg;

      final inputImageFormat = InputImageFormat.nv21;
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
        title: Text('Ring Virtual Try-On'),
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
                painter: RingPainter(
                  _poses,
                  _ringImage,
                  MediaQuery.of(context).size,
                  leftPinkyHistory: _leftPinkyHistory,
                  rightPinkyHistory: _rightPinkyHistory,
                  smoothingWindow: _smoothingWindow,
                  movementThreshold: _movementThreshold,
                ),
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

class RingPainter extends CustomPainter {
  final List<Pose> poses;
  final ui.Image? ringImage;
  final Size previewSize;
  final List<Offset> leftPinkyHistory;
  final List<Offset> rightPinkyHistory;
  final int smoothingWindow;
  final double movementThreshold;

  RingPainter(
    this.poses,
    this.ringImage,
    this.previewSize, {
    required this.leftPinkyHistory,
    required this.rightPinkyHistory,
    required this.smoothingWindow,
    required this.movementThreshold,
  });

  Offset? _calculateMovingAverage(List<Offset> history) {
    if (history.isEmpty) return null;
    double sumX = 0, sumY = 0;
    for (var offset in history) {
      sumX += offset.dx;
      sumY += offset.dy;
    }
    return Offset(sumX / history.length, sumY / history.length);
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (poses.isEmpty || ringImage == null) return;

    for (var pose in poses) {
      final landmarks = pose.landmarks;
      if (landmarks.containsKey(PoseLandmarkType.leftPinky) &&
          landmarks.containsKey(PoseLandmarkType.rightPinky)) {
        final leftPinky = landmarks[PoseLandmarkType.leftPinky]!;
        final rightPinky = landmarks[PoseLandmarkType.rightPinky]!;

        final leftPinkyPos = Offset(
          leftPinky.x * size.width / previewSize.width,
          leftPinky.y * size.height / previewSize.height,
        );
        final rightPinkyPos = Offset(
          rightPinky.x * size.width / previewSize.width,
          rightPinky.y * size.height / previewSize.height,
        );

        if (leftPinkyHistory.length >= smoothingWindow)
          leftPinkyHistory.removeAt(0);
        leftPinkyHistory.add(leftPinkyPos);

        if (rightPinkyHistory.length >= smoothingWindow)
          rightPinkyHistory.removeAt(0);
        rightPinkyHistory.add(rightPinkyPos);

        final leftPinkySmoothed = _calculateMovingAverage(leftPinkyHistory);
        final rightPinkySmoothed = _calculateMovingAverage(rightPinkyHistory);

        if (leftPinkySmoothed != null && rightPinkySmoothed != null) {
          double dxDiff = (rightPinkySmoothed.dx - leftPinkySmoothed.dx).abs();
          double dyDiff = (rightPinkySmoothed.dy - leftPinkySmoothed.dy).abs();

          if (dxDiff > movementThreshold || dyDiff > movementThreshold) {
            final ringScale = (dxDiff * 0.15) / ringImage!.width;

            // Adjusted offset for stable ring placement
            final leftOffset = Offset(
              leftPinkySmoothed.dx - (ringImage!.width * ringScale) / 2,
              leftPinkySmoothed.dy -
                  (ringImage!.height * ringScale) / 2 -
                  10, // Slight upward adjustment
            );

            canvas.drawImageRect(
              ringImage!,
              Rect.fromLTWH(0, 0, ringImage!.width.toDouble(),
                  ringImage!.height.toDouble()),
              Rect.fromLTWH(leftOffset.dx, leftOffset.dy,
                  ringImage!.width * ringScale, ringImage!.height * ringScale),
              Paint(),
            );
          }
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}
