import 'package:flutter/material.dart';
import '../../../../core/widgets/simple_image_widget.dart';

class ProductDetailImages extends StatefulWidget {
  final String sku;
  final String? imageUrl;
  final String? imageUrl2;
  final String? thumbnailUrl;
  
  const ProductDetailImages({
    super.key,
    required this.sku,
    this.imageUrl,
    this.imageUrl2,
    this.thumbnailUrl,
  });

  @override
  State<ProductDetailImages> createState() => _ProductDetailImagesState();
}

class _ProductDetailImagesState extends State<ProductDetailImages> {
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
    
    // Clean SKU for image paths
    final cleanSku = widget.sku.toUpperCase().trim();
    
    return Column(
      children: [
        // Image carousel - full height
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
              color: Colors.white,
            ),
          child: Stack(
            children: [
              // PageView for P.1 and P.2
              PageView(
                controller: _pageController,
                onPageChanged: (index) {
                  setState(() {
                    _currentPage = index;
                  });
                },
                children: [
                  // P.1
                  _buildImagePage(cleanSku, 1, widget.imageUrl),
                  // P.2
                  _buildImagePage(cleanSku, 2, widget.imageUrl2),
                ],
              ),
              
              // Navigation arrows for desktop/tablet
              if (isDesktop || isTablet) ...[
                // Left arrow
                if (_currentPage > 0)
                  Positioned(
                    left: 16,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: IconButton(
                        onPressed: () {
                          _pageController.previousPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_back_ios,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
                // Right arrow
                if (_currentPage < 1)
                  Positioned(
                    right: 16,
                    top: 0,
                    bottom: 0,
                    child: Center(
                      child: IconButton(
                        onPressed: () {
                          _pageController.nextPage(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeInOut,
                          );
                        },
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.black.withOpacity(0.5),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.arrow_forward_ios,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
              
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
        ),
        
        const SizedBox(height: 16),
        
        // Instructions text for mobile
        if (screenWidth <= 600)
          Text(
            'Swipe left/right to see more images',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey.shade600,
            ),
          ),
      ],
    );
  }
  
  Widget _buildImagePage(String sku, int pageNumber, String? firebaseUrl) {
    // If we have a Firebase URL for this page, use it
    if (firebaseUrl != null && firebaseUrl.isNotEmpty) {
      return Container(
        color: Colors.white,
        child: Center(
          child: Image.network(
            firebaseUrl,
            fit: BoxFit.contain,
            loadingBuilder: (context, child, loadingProgress) {
              if (loadingProgress == null) return child;
              return Center(
                child: CircularProgressIndicator(
                  value: loadingProgress.expectedTotalBytes != null
                      ? loadingProgress.cumulativeBytesLoaded /
                          loadingProgress.expectedTotalBytes!
                      : null,
                ),
              );
            },
            errorBuilder: (context, error, stackTrace) {
              // Fall back to asset loading
              return _buildAssetImage(sku, pageNumber);
            },
          ),
        ),
      );
    }
    
    return _buildAssetImage(sku, pageNumber);
  }
  
  Widget _buildAssetImage(String sku, int pageNumber) {
    // Build list of paths to try for this page
    final paths = [
      'assets/screenshots/$sku/$sku P.$pageNumber.png',
      'assets/screenshots/$sku/P.$pageNumber.png',
      // Try without -N suffix
      'assets/screenshots/${sku.replaceAll(RegExp(r'-N\d?$'), '')}/${sku.replaceAll(RegExp(r'-N\d?$'), '')} P.$pageNumber.png',
    ];
    
    return Container(
      color: Colors.white,
      child: Center(
        child: _ImageWithFallback(
          paths: paths,
          fit: BoxFit.contain,
          placeholder: Container(
            color: Colors.grey[100],
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_outlined,
                    size: 48,
                    color: Colors.grey[400],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '$sku P.$pageNumber',
                    style: TextStyle(
                      color: Colors.grey[500],
                      fontSize: 14,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ImageWithFallback extends StatefulWidget {
  final List<String> paths;
  final BoxFit fit;
  final Widget placeholder;
  
  const _ImageWithFallback({
    required this.paths,
    required this.placeholder,
    required this.fit,
  });
  
  @override
  State<_ImageWithFallback> createState() => _ImageWithFallbackState();
}

class _ImageWithFallbackState extends State<_ImageWithFallback> {
  int _currentIndex = 0;
  bool _allFailed = false;
  
  @override
  Widget build(BuildContext context) {
    if (_allFailed || _currentIndex >= widget.paths.length) {
      return widget.placeholder;
    }
    
    return Image.asset(
      widget.paths[_currentIndex],
      fit: widget.fit,
      errorBuilder: (context, error, stackTrace) {
        if (_currentIndex < widget.paths.length - 1) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _currentIndex++;
              });
            }
          });
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              setState(() {
                _allFailed = true;
              });
            }
          });
        }
        return widget.placeholder;
      },
    );
  }
}