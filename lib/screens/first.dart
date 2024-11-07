import 'package:flutter/material.dart';
import 'package:jewel_tryon/necklace.dart';
import 'package:jewel_tryon/ring.dart';
import 'package:camera/camera.dart';

//First Screen
class FirstScreen extends StatefulWidget {
  final List<CameraDescription>? cameras;

  const FirstScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  State<FirstScreen> createState() => _FirstScreenState();
}

class _FirstScreenState extends State<FirstScreen> {
  //List of ornaments images
  final List<String> images = [
    'assets/ring.png',
    'assets/necklace.png',
  ];

  //Button Text
  final List<String> buttonsText = [
    'Ring Try-On',
    'Necklace Try-On',
  ];

  int currentIndex = 0;
  final PageController _pageController = PageController();

  //Next Image
  void nextImage() {
    if (currentIndex < images.length - 1) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    }
  }

  //Previous Image
  void previousImage() {
    if (currentIndex > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeIn,
      );
    }
  }

  //Navigate Based on click index if 0 then Ring else if 1 then necklace
  void navigateToTryOn() {
    if (currentIndex == 0) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => RingTryOnApp(cameras: widget.cameras!)),
      );
    } else if (currentIndex == 1 && widget.cameras != null) {
      Navigator.push(
        context,
        MaterialPageRoute(
            builder: (context) => NecklaceTryOnApp(cameras: widget.cameras!)),
      );
    }
  }

  @override

  //Widget Builder
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Jewellery Try-On"),
        centerTitle: true,
      ),
      body: Column(
        mainAxisAlignment: MainAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                PageView.builder(
                  controller: _pageController,
                  itemCount: images.length,
                  onPageChanged: (index) {
                    setState(() {
                      currentIndex = index;
                    });
                  },
                  itemBuilder: (context, index) {
                    return Container(
                      padding: const EdgeInsets.all(10),
                      child: Card(
                        elevation: 5,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: AspectRatio(
                            aspectRatio: 1,
                            child: Image.asset(
                              images[index],
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
                Positioned(
                  left: 10,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_left),
                    onPressed: previousImage,
                  ),
                ),
                Positioned(
                  right: 10,
                  child: IconButton(
                    icon: const Icon(Icons.arrow_right),
                    onPressed: nextImage,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Center(
            child: ElevatedButton(
              onPressed: navigateToTryOn,
              child: Text(buttonsText[currentIndex]),
            ),
          ),
        ],
      ),
    );
  }
}
