// lib/core/widgets/product_screenshots_popup.dart
import 'package:flutter/material.dart';

class ProductScreenshotsPopup extends StatefulWidget {
  final String sku;
  final String productName;

  const ProductScreenshotsPopup({
    super.key,
    required this.sku,
    required this.productName,
  });

  static Future<void> show(BuildContext context, String sku, String productName) {
    return showDialog(
      context: context,
      builder: (context) => ProductScreenshotsPopup(
        sku: sku,
        productName: productName,
      ),
    );
  }

  @override
  State<ProductScreenshotsPopup> createState() => _ProductScreenshotsPopupState();
}

class _ProductScreenshotsPopupState extends State<ProductScreenshotsPopup> {
  final PageController _pageController = PageController();
  int _currentPage = 0;
  final List<String> _screenshotPaths = [];

  @override
  void initState() {
    super.initState();
    _loadScreenshots();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _loadScreenshots() {
    final cleanSku = _cleanSku(widget.sku);
    // Try to load up to 5 screenshot pages
    for (int i = 1; i <= 5; i++) {
      _screenshotPaths.add('assets/screenshots/$cleanSku/$cleanSku P.$i.png');
    }
  }

  String _cleanSku(String sku) {
    return sku
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .trim()
        .toUpperCase();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);
    
    return Dialog(
      backgroundColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(20),
      child: Container(
        width: size.width * 0.9,
        height: size.height * 0.85,
        decoration: BoxDecoration(
          color: theme.scaffoldBackgroundColor,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            // Header
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: theme.primaryColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.productName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          'SKU: ${widget.sku}',
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.9),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    onPressed: () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            
            // Screenshots viewer
            Expanded(
              child: Stack(
                children: [
                  PageView.builder(
                    controller: _pageController,
                    onPageChanged: (index) {
                      setState(() {
                        _currentPage = index;
                      });
                    },
                    itemCount: _screenshotPaths.length,
                    itemBuilder: (context, index) {
                      return InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4.0,
                        child: Center(
                          child: Image.asset(
                            _screenshotPaths[index],
                            fit: BoxFit.contain,
                            errorBuilder: (context, error, stackTrace) {
                              if (index == 0) {
                                // Only show error for first screenshot
                                return Center(
                                  child: Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.image_not_supported_outlined,
                                        size: 64,
                                        color: Colors.grey[400],
                                      ),
                                      const SizedBox(height: 16),
                                      Text(
                                        'No specifications available',
                                        style: TextStyle(
                                          color: Colors.grey[600],
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        'SKU: ${widget.sku}',
                                        style: TextStyle(
                                          color: Colors.grey[500],
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              }
                              return const SizedBox.shrink();
                            },
                          ),
                        ),
                      );
                    },
                  ),
                  
                  // Navigation arrows
                  if (_screenshotPaths.length > 1) ...[
                    Positioned(
                      left: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_back_ios, color: Colors.white, size: 20),
                          ),
                          onPressed: _currentPage > 0
                              ? () {
                                  _pageController.previousPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                }
                              : null,
                        ),
                      ),
                    ),
                    Positioned(
                      right: 8,
                      top: 0,
                      bottom: 0,
                      child: Center(
                        child: IconButton(
                          icon: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: Colors.black54,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(Icons.arrow_forward_ios, color: Colors.white, size: 20),
                          ),
                          onPressed: _currentPage < _screenshotPaths.length - 1
                              ? () {
                                  _pageController.nextPage(
                                    duration: const Duration(milliseconds: 300),
                                    curve: Curves.easeInOut,
                                  );
                                }
                              : null,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            
            // Page indicator
            if (_screenshotPaths.length > 1)
              Container(
                padding: const EdgeInsets.all(16),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    _screenshotPaths.length,
                    (index) => Container(
                      width: 8,
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 4),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: _currentPage == index
                            ? theme.primaryColor
                            : Colors.grey[400],
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}