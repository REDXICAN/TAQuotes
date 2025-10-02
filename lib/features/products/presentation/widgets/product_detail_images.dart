import 'package:flutter/material.dart';
import 'dart:io';
import 'package:open_file/open_file.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/services/pdf_service.dart';
import '../../../../core/services/app_logger.dart';

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
  File? _pdfFile;
  String? _pdfUrl;
  bool _isLoadingPdf = false;
  bool _showPdf = false;

  @override
  void initState() {
    super.initState();
    _checkForPdf();
  }
  
  Future<void> _checkForPdf() async {
    setState(() => _isLoadingPdf = true);
    try {
      final pdfResult = await PdfService.findPdfForSku(widget.sku);
      if (mounted) {
        setState(() {
          if (pdfResult is File) {
            _pdfFile = pdfResult;
          } else if (pdfResult is String) {
            _pdfUrl = pdfResult;
          }
          _isLoadingPdf = false;
        });
      }
    } catch (e) {
      AppLogger.error('Error checking for PDF', error: e, category: LogCategory.ui);
      if (mounted) {
        setState(() => _isLoadingPdf = false);
      }
    }
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // screenHeight kept for potential future responsive sizing
    // ignore: unused_local_variable
    final screenHeight = MediaQuery.of(context).size.height;
    final screenWidth = MediaQuery.of(context).size.width;
    final isDesktop = screenWidth > 1200;
    final isTablet = screenWidth > 600 && screenWidth <= 1200;
    
    // Clean SKU for image paths
    final cleanSku = widget.sku.toUpperCase().trim();
    
    return Column(
      children: [
        // PDF Buttons if PDF is available
        if ((_pdfFile != null || _pdfUrl != null) && !_isLoadingPdf)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () => _viewPdf(context),
                  icon: const Icon(Icons.picture_as_pdf),
                  label: const Text('View PDF'),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
                const SizedBox(width: 16),
                OutlinedButton.icon(
                  onPressed: _downloadPdf,
                  icon: const Icon(Icons.download),
                  label: const Text('Download PDF'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                ),
              ],
            ),
          ),
        
        // Loading indicator for PDF check
        if (_isLoadingPdf)
          Container(
            margin: const EdgeInsets.only(bottom: 16),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
                SizedBox(width: 8),
                Text('Checking for PDF documentation...'),
              ],
            ),
          ),
        
        // Image carousel or PDF viewer - full height
        Expanded(
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.grey.shade300),
              color: Colors.white,
            ),
          child: _showPdf && (_pdfFile != null || _pdfUrl != null)
            ? _buildPdfViewer()
            : Stack(
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
                            color: Colors.black.withValues(alpha: 0.5),
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
                            color: Colors.black.withValues(alpha: 0.5),
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
      return GestureDetector(
        onTap: () => _showZoomedImage(context, firebaseUrl, sku, pageNumber),
        child: MouseRegion(
          cursor: SystemMouseCursors.click,
          child: Container(
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
    
    return GestureDetector(
      onTap: () => _showZoomedImage(context, null, sku, pageNumber),
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
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
    ),
      ),
    );
  }
  
  void _showZoomedImage(BuildContext context, String? imageUrl, String sku, int pageNumber) {
    showDialog(
      context: context,
      barrierColor: Colors.black87,
      builder: (BuildContext context) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.all(20),
          child: Stack(
            alignment: Alignment.center,
            children: [
              // Close button
              Positioned(
                top: 10,
                right: 10,
                child: IconButton(
                  icon: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.5),
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(Icons.close, color: Colors.white, size: 24),
                  ),
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              // Zoomable image
              Container(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.of(context).size.width * 0.9,
                  maxHeight: MediaQuery.of(context).size.height * 0.9,
                ),
                child: InteractiveViewer(
                  minScale: 0.5,
                  maxScale: 4.0,
                  child: imageUrl != null
                      ? Image.network(
                          imageUrl,
                          fit: BoxFit.contain,
                          errorBuilder: (context, error, stackTrace) {
                            return _buildAssetImageForZoom(sku, pageNumber);
                          },
                        )
                      : _buildAssetImageForZoom(sku, pageNumber),
                ),
              ),
              // SKU and page info
              Positioned(
                bottom: 10,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '$sku - Page $pageNumber',
                    style: const TextStyle(color: Colors.white, fontSize: 14),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
  
  Widget _buildAssetImageForZoom(String sku, int pageNumber) {
    return Image.asset(
      'assets/screenshots/$sku/$sku P.$pageNumber.png',
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) {
        return Container(
          color: Colors.grey[900],
          child: Center(
            child: Text(
              'Image not available',
              style: TextStyle(color: Colors.grey[400]),
            ),
          ),
        );
      },
    );
  }
  
  Widget _buildPdfViewer() {
    return Stack(
      children: [
        _pdfUrl != null
          ? SfPdfViewer.network(
              _pdfUrl!,
              enableDoubleTapZooming: true,
              canShowScrollHead: true,
              canShowScrollStatus: true,
            )
          : SfPdfViewer.file(
              _pdfFile!,
              enableDoubleTapZooming: true,
              canShowScrollHead: true,
              canShowScrollStatus: true,
            ),
        // Close PDF button
        Positioned(
          top: 8,
          right: 8,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () {
                setState(() {
                  _showPdf = false;
                });
              },
              tooltip: 'Close PDF',
            ),
          ),
        ),
      ],
    );
  }
  
  void _viewPdf(BuildContext context) {
    setState(() {
      _showPdf = true;
    });
  }
  
  Future<void> _downloadPdf() async {
    if (_pdfFile == null && _pdfUrl == null) return;
    
    try {
      if (_pdfUrl != null) {
        // For web, open PDF URL in new tab
        final Uri url = Uri.parse(_pdfUrl!);
        if (await canLaunchUrl(url)) {
          await launchUrl(url, mode: LaunchMode.externalApplication);
        } else {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Could not open PDF'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      } else if (_pdfFile != null) {
        // For desktop/mobile, open local PDF file
        final result = await OpenFile.open(_pdfFile!.path);
        
        if (result.type != ResultType.done) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Could not open PDF: ${result.message}'),
                backgroundColor: Colors.orange,
              ),
            );
          }
        }
      }
    } catch (e) {
      AppLogger.error('Error opening PDF', error: e, category: LogCategory.ui);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error opening PDF file'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
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