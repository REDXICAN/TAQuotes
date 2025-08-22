import 'package:flutter/material.dart';
import '../../../../core/widgets/simple_product_image.dart';

class SimpleProductImagesWidget extends StatefulWidget {
  final String sku;
  
  const SimpleProductImagesWidget({
    super.key,
    required this.sku,
  });

  @override
  State<SimpleProductImagesWidget> createState() => _SimpleProductImagesWidgetState();
}

class _SimpleProductImagesWidgetState extends State<SimpleProductImagesWidget> {
  final PageController _pageController = PageController();
  int _currentPage = 0;

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth > 600 && screenWidth <= 1200;
    final isMobile = screenWidth <= 600;
    
    // Adjust height based on platform
    double carouselHeight;
    if (isDesktop) {
      carouselHeight = screenHeight * 0.85;
    } else if (isTablet) {
      carouselHeight = screenHeight * 0.75;
    } else {
      carouselHeight = 400;
    }
    
    return Column(
      children: [
        // Image carousel
        Container(
          height: carouselHeight,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.grey.shade300),
            color: Colors.white,
          ),
          child: Stack(
            children: [
              // PageView for images
              PageView.builder(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                itemCount: 2, // P.1 and P.2
                itemBuilder: (context, index) {
                  return MouseRegion(
                    cursor: SystemMouseCursors.click,
                    child: GestureDetector(
                      onTap: () => _showZoomedImage(context, index),
                      child: Container(
                        color: Colors.white,
                        child: Center(
                          child: SimpleProductImage(
                            sku: widget.sku,
                            imageType: ImageType.screenshot,
                            screenshotPage: index + 1,
                            fit: BoxFit.contain,
                            width: double.infinity,
                            height: carouselHeight,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
              
              // Navigation arrows for desktop/tablet
              if (isDesktop || isTablet) ...[
                // Left arrow
                Positioned(
                  left: 16,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton(
                      onPressed: _currentPage > 0
                          ? () {
                              _pageController.previousPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          : null,
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_back_ios,
                          color: _currentPage > 0 ? Colors.white : Colors.grey,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
                // Right arrow
                Positioned(
                  right: 16,
                  top: 0,
                  bottom: 0,
                  child: Center(
                    child: IconButton(
                      onPressed: _currentPage < 1
                          ? () {
                              _pageController.nextPage(
                                duration: const Duration(milliseconds: 300),
                                curve: Curves.easeInOut,
                              );
                            }
                          : null,
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.black.withOpacity(0.5),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.arrow_forward_ios,
                          color: _currentPage < 1 ? Colors.white : Colors.grey,
                          size: 20,
                        ),
                      ),
                    ),
                  ),
                ),
              ],
              
              // Click to zoom indicator
              Positioned(
                top: 16,
                right: 16,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.6),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.zoom_in,
                        color: Colors.white,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        isMobile ? 'Tap to zoom' : 'Click to zoom',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              
              // Page indicators at bottom
              Positioned(
                bottom: 16,
                left: 0,
                right: 0,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    2,
                    (index) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPage == index
                            ? Theme.of(context).primaryColor
                            : Colors.grey.shade400,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        
        const SizedBox(height: 16),
        
        // Instructions text
        if (isMobile)
          Text(
            'Swipe left/right to navigate • Tap to zoom',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
      ],
    );
  }

  void _showZoomedImage(BuildContext context, int index) {
    showDialog(
      context: context,
      barrierDismissible: true,
      barrierColor: Colors.black87,
      builder: (BuildContext context) {
        return SimpleZoomableImageViewer(
          sku: widget.sku,
          initialIndex: index,
        );
      },
    );
  }
}

// Zoomable image viewer for full screen
class SimpleZoomableImageViewer extends StatefulWidget {
  final String sku;
  final int initialIndex;

  const SimpleZoomableImageViewer({
    super.key,
    required this.sku,
    required this.initialIndex,
  });

  @override
  State<SimpleZoomableImageViewer> createState() => _SimpleZoomableImageViewerState();
}

class _SimpleZoomableImageViewerState extends State<SimpleZoomableImageViewer> {
  late PageController _pageController;
  late int _currentIndex;
  final TransformationController _transformationController = TransformationController();

  @override
  void initState() {
    super.initState();
    _currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    _transformationController.dispose();
    super.dispose();
  }

  void _resetZoom() {
    _transformationController.value = Matrix4.identity();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.zero,
      child: Stack(
        children: [
          // Black background
          Container(
            color: Colors.black,
            child: PageView.builder(
              controller: _pageController,
              onPageChanged: (index) {
                setState(() {
                  _currentIndex = index;
                  _resetZoom();
                });
              },
              itemCount: 2, // P.1 and P.2
              itemBuilder: (context, index) {
                return InteractiveViewer(
                  transformationController: index == _currentIndex ? _transformationController : null,
                  panEnabled: true,
                  boundaryMargin: const EdgeInsets.all(20),
                  minScale: 0.5,
                  maxScale: 4,
                  child: Center(
                    child: SimpleProductImage(
                      sku: widget.sku,
                      imageType: ImageType.screenshot,
                      screenshotPage: index + 1,
                      fit: BoxFit.contain,
                    ),
                  ),
                );
              },
            ),
          ),
          
          // Close button
          Positioned(
            top: 40,
            right: 20,
            child: IconButton(
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.close,
                  color: Colors.white,
                  size: 24,
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          
          // SKU label
          Positioned(
            top: 40,
            left: 20,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black.withOpacity(0.5),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Text(
                widget.sku,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ),
          
          // Page indicator
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    'Page ${_currentIndex + 1} of 2',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
              ],
            ),
          ),
          
          // Zoom instructions
          Positioned(
            bottom: 80,
            left: 0,
            right: 0,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: const Text(
                  'Pinch to zoom • Double tap to reset',
                  style: TextStyle(
                    color: Colors.white70,
                    fontSize: 12,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}