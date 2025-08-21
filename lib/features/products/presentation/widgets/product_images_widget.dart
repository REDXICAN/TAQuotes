import 'package:flutter/material.dart';
import '../../../../core/widgets/product_image_widget.dart';

class ProductImagesWidget extends StatefulWidget {
  final String sku;
  
  const ProductImagesWidget({
    super.key,
    required this.sku,
  });

  @override
  State<ProductImagesWidget> createState() => _ProductImagesWidgetState();
}

class _ProductImagesWidgetState extends State<ProductImagesWidget> {
  // Generate image paths for P.1 and P.2 screenshots
  List<String> get imagePaths => [
    'assets/screenshots/${widget.sku}/${widget.sku} P.1.png',
    'assets/screenshots/${widget.sku}/${widget.sku} P.2.png',
  ];

  void _showImagePopup(BuildContext context, int initialIndex) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (BuildContext context) {
        return ImagePopupViewer(
          imagePaths: imagePaths,
          initialIndex: initialIndex,
          sku: widget.sku,
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    // New layout: P1 on left, P2 below it - Full width
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Screenshot P.1 - using ProductImageWidget for proper fallback
        GestureDetector(
          onTap: () => _showImagePopup(context, 0),
          child: Container(
            width: double.infinity,
            height: 400, // Increased height for better view
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
              color: const Color(0xFFFFFFFF), // White background
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: ProductImageWidget(
                sku: widget.sku,
                useThumbnail: false, // Use screenshots for detail view
                fit: BoxFit.contain,
                width: double.infinity,
              ),
            ),
          ),
        ),
        const SizedBox(height: 8),
        
        // Screenshot P.2 - second page
        GestureDetector(
          onTap: () => _showImagePopup(context, 1),
          child: Container(
            width: double.infinity,
            height: 400, // Increased height for better view
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
              color: const Color(0xFFFFFFFF), // White background
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Image.asset(
                imagePaths[1],
                width: double.infinity,
                fit: BoxFit.contain,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback for P.2 - just show placeholder since P.2 may not exist
                  return Container(
                    color: Colors.grey.shade100,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.image_not_supported,
                          size: 48,
                          color: Colors.grey.shade400,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Page 2',
                          style: TextStyle(
                            color: Colors.grey.shade600,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// Popup viewer widget
class ImagePopupViewer extends StatefulWidget {
  final List<String> imagePaths;
  final int initialIndex;
  final String sku;

  const ImagePopupViewer({
    super.key,
    required this.imagePaths,
    required this.initialIndex,
    required this.sku,
  });

  @override
  State<ImagePopupViewer> createState() => _ImagePopupViewerState();
}

class _ImagePopupViewerState extends State<ImagePopupViewer> {
  late int currentIndex;
  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    currentIndex = widget.initialIndex;
    _pageController = PageController(initialPage: currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header with close button
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).primaryColor,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    widget.sku,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            // Image viewer with swipe
            Flexible(
              child: Container(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.of(context).size.height * 0.7,
                ),
                child: PageView.builder(
                  controller: _pageController,
                  onPageChanged: (index) {
                    setState(() {
                      currentIndex = index;
                    });
                  },
                  itemCount: widget.imagePaths.length,
                  itemBuilder: (context, index) {
                    return InteractiveViewer(
                      panEnabled: true,
                      minScale: 0.5,
                      maxScale: 4,
                      child: Center(
                        child: Image.asset(
                          widget.imagePaths[index],
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return Container(
                              color: Colors.grey.shade100,
                              child: Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.image_not_supported,
                                      size: 64,
                                      color: Colors.grey.shade400,
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Image not available',
                                      style: TextStyle(
                                        color: Colors.grey.shade600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    );
                  },
                ),
              ),
            ),
            
            // Page indicators
            Container(
              padding: const EdgeInsets.all(16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (int i = 0; i < widget.imagePaths.length; i++)
                    Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: currentIndex == i
                            ? Theme.of(context).primaryColor
                            : Colors.grey.shade300,
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}