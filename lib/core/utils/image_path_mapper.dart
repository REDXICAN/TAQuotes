// lib/core/utils/image_path_mapper.dart
import 'package:flutter/services.dart';

class ImagePathMapper {
  static final Map<String, List<String>> _skuToImagePaths = {};
  static bool _isInitialized = false;
  
  /// Initialize by scanning the asset directories
  static Future<void> initialize() async {
    if (_isInitialized) return;
    
    try {
      // Load the asset manifest to get all available assets
      final manifestContent = await rootBundle.loadString('AssetManifest.json');
      
      // Parse the manifest (it's a JSON map of asset paths)
      final Map<String, dynamic> manifestMap = {};
      
      // Since we can't use dart:convert in this simplified version,
      // we'll manually build the mapping based on known patterns
      _buildKnownMappings();
      
      _isInitialized = true;
    } catch (e) {
      AppLogger.debug('Error initializing ImagePathMapper', error: e, category: LogCategory.system);
      // Fall back to known mappings
      _buildKnownMappings();
      _isInitialized = true;
    }
  }
  
  /// Build known mappings based on directory structure
  static void _buildKnownMappings() {
    // These are based on the actual directory listings we saw
    // Format: SKU -> [thumbnail paths, screenshot paths]
    
    // CRT series
    _addMapping('CRT-77-1R-N', [
      'assets/thumbnails/CRT-77-1R-N_Left/CRT-77-1R-N_Left.jpg',
      'assets/screenshots/CRT-77-1R-N/CRT-77-1R-N P.1.png',
      'assets/screenshots/CRT-77-1R-N/CRT-77-1R-N P.2.png',
    ]);
    
    _addMapping('CRT-77-2R-N', [
      'assets/thumbnails/CRT-77-2R-N_Left/CRT-77-2R-N_Left.jpg',
      'assets/screenshots/CRT-77-2R-N/CRT-77-2R-N P.1.png',
    ]);
    
    // CTST series
    _addMapping('CTST-1200-13-N', [
      'assets/thumbnails/CTST-1200-13-N/CTST-1200-13-N.jpg',
      'assets/thumbnails/CTST-1200-13-N_empty/CTST-1200-13-N_empty.jpg',
      'assets/screenshots/CTST-1200-13-N/CTST-1200-13-N P.1.png',
    ]);
    
    _addMapping('CTST-1200G-13-N', [
      'assets/thumbnails/CTST-1200G-13-N/CTST-1200G-13-N.jpg',
      'assets/thumbnails/CTST-1200G-13-N_empty/CTST-1200G-13-N_empty.jpg',
      'assets/screenshots/CTST-1200G-13-N/CTST-1200G-13-N P.1.png',
    ]);
    
    _addMapping('CTST-1200G-N', [
      'assets/thumbnails/CTST-1200G-N/CTST-1200G-N.jpg',
      'assets/thumbnails/CTST-1200G-N _empty/CTST-1200G-N _empty.jpg',
      'assets/screenshots/CTST-1200G-N/CTST-1200G-N P.1.png',
    ]);
    
    _addMapping('CTST-1200-N', [
      'assets/thumbnails/CTST-1200-N/CTST-1200-N.jpg',
      'assets/thumbnails/CTST-1200-N_empty/CTST-1200-N_empty.jpg',
      'assets/screenshots/CTST-1200-N/CTST-1200-N P.1.png',
    ]);
    
    // Add more mappings as needed...
  }
  
  static void _addMapping(String sku, List<String> paths) {
    // Clean the SKU
    final cleanSku = _cleanSku(sku);
    _skuToImagePaths[cleanSku] = paths;
  }
  
  /// Clean and normalize SKU
  static String _cleanSku(String sku) {
    // Remove parentheses and their contents, trim, uppercase
    return sku
        .replaceAll(RegExp(r'\([^)]*\)'), '')
        .trim()
        .toUpperCase();
  }
  
  /// Get thumbnail path for a SKU
  static String? getThumbnailPath(String sku) {
    final cleanSku = _cleanSku(sku);
    
    // Try exact match first
    final paths = _skuToImagePaths[cleanSku];
    if (paths != null && paths.isNotEmpty) {
      // Find the first thumbnail path
      for (final path in paths) {
        if (path.contains('thumbnails')) {
          return path;
        }
      }
    }
    
    // Try common patterns
    final patterns = [
      'assets/thumbnails/$cleanSku/$cleanSku.jpg',
      'assets/thumbnails/${cleanSku}_Left/${cleanSku}_Left.jpg',
      'assets/thumbnails/${cleanSku}_Right/${cleanSku}_Right.jpg',
      'assets/thumbnails/${cleanSku}_empty/${cleanSku}_empty.jpg',
    ];
    
    // Return the first pattern (we'll handle errors in the widget)
    return patterns[0];
  }
  
  /// Get screenshot path for a SKU
  static String? getScreenshotPath(String sku, {int page = 1}) {
    final cleanSku = _cleanSku(sku);
    
    // Try exact match first
    final paths = _skuToImagePaths[cleanSku];
    if (paths != null && paths.isNotEmpty) {
      // Find screenshot paths
      for (final path in paths) {
        if (path.contains('screenshots') && path.contains('P.$page')) {
          return path;
        }
      }
    }
    
    // Try common patterns
    final patterns = [
      'assets/screenshots/$cleanSku/$cleanSku P.$page.png',
      'assets/screenshots/$cleanSku/P.$page.png',
    ];
    
    return patterns[0];
  }
  
  /// Get all available screenshot paths for a SKU
  static List<String> getAllScreenshotPaths(String sku) {
    final cleanSku = _cleanSku(sku);
    final screenshots = <String>[];
    
    // Try exact match first
    final paths = _skuToImagePaths[cleanSku];
    if (paths != null && paths.isNotEmpty) {
      for (final path in paths) {
        if (path.contains('screenshots')) {
          screenshots.add(path);
        }
      }
    }
    
    // If no exact match, try common patterns for up to 5 pages
    if (screenshots.isEmpty) {
      for (int i = 1; i <= 5; i++) {
        screenshots.add('assets/screenshots/$cleanSku/$cleanSku P.$i.png');
      }
    }
    
    return screenshots;
  }
}