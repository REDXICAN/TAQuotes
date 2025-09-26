// lib/core/models/models.dart
import '../services/app_logger.dart';

import '../utils/safe_conversions.dart';
import '../services/app_logger.dart';

// Export UserRole enum
export 'user_role.dart';
export 'project.dart';

// UserProfile Model
class UserProfile {
  final String uid;
  final String email;
  final String? displayName;
  final String role;
  final DateTime createdAt;
  final DateTime? lastLoginAt;
  final bool isAdmin;

  UserProfile({
    required this.uid,
    required this.email,
    this.displayName,
    required this.role,
    required this.createdAt,
    this.lastLoginAt,
    this.isAdmin = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': role,
      'createdAt': createdAt.toIso8601String(),
      'lastLoginAt': lastLoginAt?.toIso8601String(),
      'isAdmin': isAdmin,
    };
  }

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    // Helper function to parse dates safely
    DateTime? parseDate(dynamic value) {
      if (value == null) return null;
      try {
        if (value is DateTime) return value;
        if (value is String) {
          // Handle ISO format dates
          if (value.contains('T') || value.contains('-')) {
            return DateTime.parse(value);
          }
          // Try to parse as milliseconds
          final millis = int.tryParse(value);
          if (millis != null) {
            return DateTime.fromMillisecondsSinceEpoch(millis);
          }
        }
        if (value is int || value is double) {
          return DateTime.fromMillisecondsSinceEpoch(value.toInt());
        }
      } catch (e) {
        AppLogger.error('Error parsing date for UserProfile', error: e, category: LogCategory.data, data: {'value': value});
      }
      return null;
    }
    
    return UserProfile(
      uid: map['uid'] ?? map['id'] ?? '',
      email: map['email'] ?? '',
      displayName: map['displayName'] ?? map['display_name'],
      role: map['role'] ?? 'user',
      createdAt: parseDate(map['createdAt'] ?? map['created_at']) ?? DateTime.now(),
      lastLoginAt: parseDate(map['lastLoginAt'] ?? map['last_login_at']),
      isAdmin: map['isAdmin'] ?? map['is_admin'] ?? false,
    );
  }

  // JSON methods for compatibility
  String toJson() => toMap().toString();
  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile.fromMap(json);
}

// Client Model
class Client {
  final String? id;
  final String company;
  final String contactName;
  final String name;
  final String email;
  final String phone;
  final String? address;
  final String? city;
  final String? state;
  final String? zipCode;
  final String? country;
  final String? notes;
  final String? profilePictureUrl;
  final DateTime createdAt;
  final DateTime? updatedAt;

  Client({
    this.id,
    required this.company,
    required this.contactName,
    required this.name,
    required this.email,
    required this.phone,
    this.address,
    this.city,
    this.state,
    this.zipCode,
    this.country,
    this.notes,
    this.profilePictureUrl,
    required this.createdAt,
    this.updatedAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'company': company,
      'contactName': contactName,
      'name': name,
      'email': email,
      'phone': phone,
      'address': address,
      'city': city,
      'state': state,
      'zipCode': zipCode,
      'country': country,
      'notes': notes,
      'profilePictureUrl': profilePictureUrl,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
    };
  }

  factory Client.fromMap(Map<String, dynamic> map) {
    // Handle both snake_case and camelCase field names
    return Client(
      id: map['id'],
      company: map['company'] ?? '',
      contactName: map['contact_name'] ?? map['contactName'] ?? '',
      name: map['name'] ?? map['contact_name'] ?? '',
      email: map['email'] ?? '',
      phone: map['phone'] ?? '',
      address: map['address'],
      city: map['city'],
      state: map['state'],
      zipCode: map['zip_code'] ?? map['zipCode'],
      country: map['country'],
      notes: map['notes'],
      profilePictureUrl: map['profile_picture_url'] ?? map['profilePictureUrl'],
      createdAt: map['created_at'] != null 
          ? (map['created_at'] is int 
              ? DateTime.fromMillisecondsSinceEpoch(map['created_at'])
              : DateTime.parse(map['created_at']))
          : DateTime.now(),
      updatedAt: map['updated_at'] != null 
          ? (map['updated_at'] is int
              ? DateTime.fromMillisecondsSinceEpoch(map['updated_at'])
              : DateTime.parse(map['updated_at']))
          : null,
    );
  }

  // JSON methods for compatibility
  String toJson() => toMap().toString();
  factory Client.fromJson(Map<String, dynamic> json) => Client.fromMap(json);
}

// Warehouse Stock Model
class WarehouseStock {
  final int available;
  final int reserved;
  final DateTime lastUpdate;
  final int? minStock;
  final String? location;
  
  WarehouseStock({
    required this.available,
    required this.reserved,
    required this.lastUpdate,
    this.minStock,
    this.location,
  });
  
  // Calculate actual available (available - reserved)
  int get actualAvailable => available - reserved;
  
  // Check if stock is low
  bool get isLowStock => minStock != null && actualAvailable <= minStock!;
  
  Map<String, dynamic> toMap() {
    return {
      'available': available,
      'reserved': reserved,
      'lastUpdate': lastUpdate.toIso8601String(),
      'minStock': minStock,
      'location': location,
    };
  }
  
  factory WarehouseStock.fromMap(Map<String, dynamic> map) {
    return WarehouseStock(
      available: map['available'] ?? 0,
      reserved: map['reserved'] ?? 0,
      lastUpdate: map['lastUpdate'] != null 
          ? DateTime.parse(map['lastUpdate']) 
          : DateTime.now(),
      minStock: map['minStock'],
      location: map['location'],
    );
  }
}

// Warehouse Info
class WarehouseInfo {
  static const Map<String, Map<String, String>> warehouses = {
    'CA1': {
      'name': 'Cancún Exhibición',
      'location': 'Cancún, Mexico',
      'timezone': 'America/Cancun',
      'flag': '🇲🇽',
    },
    '999': {
      'name': 'Mercancía Apartada',
      'location': 'Already Quoted/Reserved',
      'timezone': 'America/Mexico_City',
      'flag': '🔒',
    },
    'CA': {
      'name': 'Cancún',
      'location': 'Cancún, Mexico',
      'timezone': 'America/Cancun',
      'flag': '🇲🇽',
    },
    'CA2': {
      'name': 'Cancún Equipos a Prueba',
      'location': 'Cancún, Mexico',
      'timezone': 'America/Cancun',
      'flag': '🔧',
    },
    'CA3': {
      'name': 'Cancún Laboratorio',
      'location': 'Cancún, Mexico',
      'timezone': 'America/Cancun',
      'flag': '🔬',
    },
    'CA4': {
      'name': 'Cancún Área de Ajuste',
      'location': 'Cancún, Mexico',
      'timezone': 'America/Cancun',
      'flag': '⚙️',
    },
    'COCZ': {
      'name': 'Consignación Cancún Zicor',
      'location': 'Cancún, Mexico',
      'timezone': 'America/Cancun',
      'flag': '🤝',
    },
    'COPZ': {
      'name': 'Consignación Puebla Zicor',
      'location': 'Puebla, Mexico',
      'timezone': 'America/Mexico_City',
      'flag': '🤝',
    },
    'INT': {
      'name': 'Internacional',
      'location': 'International',
      'timezone': 'UTC',
      'flag': '🌎',
    },
    'MEE': {
      'name': 'México Proyectos Especiales',
      'location': 'Mexico City, Mexico',
      'timezone': 'America/Mexico_City',
      'flag': '🚀',
    },
    'PU': {
      'name': 'Puebla BINEX',
      'location': 'Puebla, Mexico',
      'timezone': 'America/Mexico_City',
      'flag': '🇲🇽',
    },
    'SI': {
      'name': 'Silao BINEX',
      'location': 'Silao, Mexico',
      'timezone': 'America/Mexico_City',
      'flag': '🇲🇽',
    },
    'XCA': {
      'name': 'Refrigeration X Cancún',
      'location': 'Cancún, Mexico',
      'timezone': 'America/Cancun',
      'flag': '❄️',
    },
    'XPU': {
      'name': 'Refrigeration X Puebla',
      'location': 'Puebla, Mexico',
      'timezone': 'America/Mexico_City',
      'flag': '❄️',
    },
  };
  
  static String getWarehouseName(String code) {
    return warehouses[code]?['name'] ?? code;
  }
  
  static String getWarehouseLocation(String code) {
    return warehouses[code]?['location'] ?? 'Unknown';
  }
  
  static String getWarehouseFlag(String code) {
    return warehouses[code]?['flag'] ?? '📦';
  }
}

// Product Model
class Product {
  final String? id;
  final String model;
  final String displayName;
  final String name;
  final String description;
  final String category;
  final String? subcategory;
  final String? productType;
  final String? sku;
  final double price;
  final String? imageUrl;
  final String? imageUrl2;  // P.2 screenshot
  final String? thumbnailUrl;
  final String? pdfUrl;  // PDF specification file
  final int stock;
  final String? warehouse;  // Warehouse location code (CA, PU, SI, etc.)
  final String? dimensions;
  final String? weight;
  final String? voltage;
  final String? amperage;
  final String? phase;
  final String? frequency;
  final String? plugType;
  final String? temperatureRange;
  final String? temperatureRangeMetric;
  final String? refrigerant;
  final String? compressor;
  final String? capacity;
  final int? doors;
  final int? shelves;
  final String? dimensionsMetric;
  final String? weightMetric;
  final String? features;
  final String? certifications;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isTopSeller;
  
  // Warehouse stock data
  final Map<String, WarehouseStock>? warehouseStock;

  Product({
    this.id,
    required this.model,
    required this.displayName,
    required this.name,
    required this.description,
    required this.category,
    this.subcategory,
    this.productType,
    this.sku,
    required this.price,
    this.imageUrl,
    this.imageUrl2,
    this.thumbnailUrl,
    this.pdfUrl,
    required this.stock,
    this.warehouse,
    this.dimensions,
    this.weight,
    this.voltage,
    this.amperage,
    this.phase,
    this.frequency,
    this.plugType,
    this.temperatureRange,
    this.temperatureRangeMetric,
    this.refrigerant,
    this.compressor,
    this.capacity,
    this.doors,
    this.shelves,
    this.dimensionsMetric,
    this.weightMetric,
    this.features,
    this.certifications,
    required this.createdAt,
    this.updatedAt,
    this.isTopSeller = false,
    this.warehouseStock,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'model': model,
      'displayName': displayName,
      'name': name,
      'description': description,
      'category': category,
      'subcategory': subcategory,
      'productType': productType,
      'sku': sku,
      'price': price,
      'imageUrl': imageUrl,
      'imageUrl2': imageUrl2,
      'thumbnailUrl': thumbnailUrl,
      'pdfUrl': pdfUrl,
      'stock': stock,
      'warehouse': warehouse,
      'dimensions': dimensions,
      'weight': weight,
      'voltage': voltage,
      'amperage': amperage,
      'phase': phase,
      'frequency': frequency,
      'plugType': plugType,
      'temperatureRange': temperatureRange,
      'temperatureRangeMetric': temperatureRangeMetric,
      'refrigerant': refrigerant,
      'compressor': compressor,
      'capacity': capacity,
      'doors': doors,
      'shelves': shelves,
      'dimensionsMetric': dimensionsMetric,
      'weightMetric': weightMetric,
      'features': features,
      'certifications': certifications,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt?.toIso8601String(),
      'isTopSeller': isTopSeller,
      'warehouseStock': warehouseStock?.map((key, value) => MapEntry(key, value.toMap())),
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    // Helper function to safely parse int from various types
    int? parseIntSafely(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) {
        // Remove non-numeric characters and try to parse
        final cleanValue = value.replaceAll(RegExp(r'[^0-9]'), '');
        if (cleanValue.isEmpty) return null;
        return int.tryParse(cleanValue);
      }
      if (value is double) return value.toInt();
      return null;
    }

    // Helper function to safely parse double
    double parseDoubleSafely(dynamic value, {double defaultValue = 0.0}) {
      if (value == null) return defaultValue;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value) ?? defaultValue;
      return defaultValue;
    }

    // Helper function to safely parse int with default
    int parseIntWithDefault(dynamic value, {int defaultValue = 0}) {
      return parseIntSafely(value) ?? defaultValue;
    }

    // Helper function to parse DateTime from various formats
    DateTime parseDateTime(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is DateTime) return value;
      if (value is String) {
        try {
          return DateTime.parse(value);
        } catch (e) {
          // Log parsing error and return current time as fallback
          AppLogger.warning('Failed to parse date string "$value"', error: e, category: LogCategory.data);
          return DateTime.now();
        }
      }
      if (value is int) {
        // Assume it's a timestamp in milliseconds
        return DateTime.fromMillisecondsSinceEpoch(value);
      }
      return DateTime.now();
    }

    return Product(
      id: map['id'],
      model: map['model'] ?? '',
      displayName: map['displayName'] ?? map['name'] ?? '',
      name: map['name'] ?? '',
      description: map['description'] ?? '',
      category: map['category'] ?? '',
      subcategory: map['subcategory'],
      productType: map['productType'] ?? map['product_type'],  // Handle both formats
      sku: map['sku'],
      price: parseDoubleSafely(map['price']),
      imageUrl: map['imageUrl'] ?? map['image_url'],  // Handle both formats
      imageUrl2: map['imageUrl2'] ?? map['image_url2'],  // P.2 screenshot
      thumbnailUrl: map['thumbnailUrl'] ?? map['thumbnail_url'],  // Handle both formats
      pdfUrl: map['pdfUrl'] ?? map['pdf_url'],  // PDF specification file
      stock: parseIntWithDefault(map['stock']),
      warehouse: map['warehouse'],
      dimensions: map['dimensions'],
      weight: map['weight'],
      voltage: map['voltage'],
      amperage: map['amperage'] ?? map['Amps'] ?? map['amps'],  // Handle multiple field names
      phase: map['phase'],
      frequency: map['frequency'],
      plugType: map['plugType'] ?? map['plug_type'] ?? map['Plug Type'],  // Handle multiple formats
      temperatureRange: map['temperatureRange'] ?? map['temperature_range'] ?? map['Temperature Range'],
      temperatureRangeMetric: map['temperatureRangeMetric'] ?? map['temperature_range_metric'] ?? map['Temperature Range (Metric)'],
      refrigerant: map['refrigerant'] ?? map['Refrigerant'],
      compressor: map['compressor'] ?? map['Compressor'],
      capacity: map['capacity'] ?? map['Capacity'],
      doors: parseIntSafely(map['doors'] ?? map['Doors']),
      shelves: parseIntSafely(map['shelves'] ?? map['Shelves']),
      dimensionsMetric: map['dimensionsMetric'] ?? map['dimensions_metric'] ?? map['Dimensions (Metric)'],
      weightMetric: map['weightMetric'] ?? map['weight_metric'] ?? map['Weight (Metric)'],
      features: map['features'] ?? map['Features'],
      certifications: map['certifications'] ?? map['Certifications'],
      createdAt: parseDateTime(map['createdAt'] ?? map['created_at']),  // Handle both formats
      updatedAt: map['updatedAt'] ?? map['updated_at'] != null 
          ? parseDateTime(map['updatedAt'] ?? map['updated_at']) 
          : null,
      isTopSeller: map['isTopSeller'] ?? map['is_top_seller'] ?? false,
      warehouseStock: _parseWarehouseStock(map),
    );
  }
  
  // Helper function to parse warehouse stock data
  static Map<String, WarehouseStock>? _parseWarehouseStock(Map<String, dynamic> map) {
    final stockData = <String, WarehouseStock>{};
    
    // Try to parse from warehouseStock field
    if (map['warehouseStock'] != null && map['warehouseStock'] is Map) {
      final warehouseData = map['warehouseStock'] as Map;
      warehouseData.forEach((key, value) {
        if (value is Map) {
          stockData[key.toString()] = WarehouseStock.fromMap(Map<String, dynamic>.from(value));
        }
      });
      return stockData.isNotEmpty ? stockData : null;
    }
    
    // Parse individual warehouse columns (from Excel import)
    final warehouses = ['CA1', '999', 'CA', 'CA2', 'CA3', 'CA4', 'COCZ', 'COPZ', 'INT', 'MEE', 'PU', 'SI', 'XCA', 'XPU'];
    for (final warehouse in warehouses) {
      final stockValue = map[warehouse];
      if (stockValue != null) {
        final quantity = stockValue is int ? stockValue : 
                        stockValue is double ? stockValue.toInt() : 
                        stockValue is String ? int.tryParse(stockValue) ?? 0 : 0;
        
        if (quantity > 0) {
          stockData[warehouse] = WarehouseStock(
            available: quantity,
            reserved: 0,
            lastUpdate: DateTime.now(),
          );
        }
      }
    }
    
    return stockData.isNotEmpty ? stockData : null;
  }

  // JSON methods for compatibility
  String toJson() => toMap().toString();
  factory Product.fromJson(Map<String, dynamic> json) => Product.fromMap(json);
  
  // Helper methods for warehouse stock
  int get totalAvailableStock {
    // Always use the simple stock field as the primary source
    return stock;
  }
  
  int get totalReservedStock {
    if (warehouseStock == null || warehouseStock!.isEmpty) return 0;
    
    int total = 0;
    warehouseStock!.forEach((_, stock) {
      total += stock.reserved;
    });
    return total;
  }
  
  Map<String, int> get availableByWarehouse {
    if (warehouseStock == null || warehouseStock!.isEmpty) return {};
    
    final result = <String, int>{};
    warehouseStock!.forEach((warehouse, stock) {
      result[warehouse] = stock.actualAvailable;
    });
    return result;
  }
}

// Quote Model
class Quote {
  final String? id;
  final String? quoteNumber;
  final String clientId;
  final String? clientName;
  final Client? client;
  final List<QuoteItem> items;
  final double subtotal;
  final double discountAmount;
  final String discountType; // 'percentage' or 'fixed'
  final double discountValue;
  final double tax;
  final double total;
  final double totalAmount;
  final String status;
  final bool archived;
  final String? notes;
  final String? comments;
  final bool includeCommentInEmail;
  final DateTime createdAt;
  final DateTime? expiresAt;
  final String createdBy;
  final String? projectId;
  final String? projectName;

  Quote({
    this.id,
    this.quoteNumber,
    required this.clientId,
    this.clientName,
    this.client,
    required this.items,
    required this.subtotal,
    this.discountAmount = 0,
    this.discountType = 'fixed',
    this.discountValue = 0,
    required this.tax,
    required this.total,
    double? totalAmount,
    required this.status,
    this.archived = false,
    this.notes,
    this.comments,
    this.includeCommentInEmail = false,
    required this.createdAt,
    this.expiresAt,
    required this.createdBy,
    this.projectId,
    this.projectName,
  }) : totalAmount = totalAmount ?? total;

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'quoteNumber': quoteNumber,
      'clientId': clientId,
      'clientName': clientName,
      'client': client?.toMap(),
      'items': items.map((x) => x.toMap()).toList(),
      'subtotal': subtotal,
      'discountAmount': discountAmount,
      'discountType': discountType,
      'discountValue': discountValue,
      'tax': tax,
      'total': total,
      'totalAmount': totalAmount,
      'status': status,
      'archived': archived,
      'notes': notes,
      'comments': comments,
      'includeCommentInEmail': includeCommentInEmail,
      'createdAt': createdAt.toIso8601String(),
      'expiresAt': expiresAt?.toIso8601String(),
      'createdBy': createdBy,
      'projectId': projectId,
      'projectName': projectName,
    };
  }

  factory Quote.fromMap(Map<String, dynamic> map) {
    return Quote(
      id: map['id'],
      quoteNumber: map['quoteNumber'],
      clientId: map['clientId'] ?? '',
      clientName: map['clientName'],
      client: map['client'] != null ? Client.fromMap(map['client']) : null,
      items: List<QuoteItem>.from(
        (map['items'] ?? []).map((x) => QuoteItem.fromMap(x)),
      ),
      subtotal: SafeConversions.toPrice(map['subtotal']),
      discountAmount: SafeConversions.toPrice(map['discountAmount'] ?? map['discount_amount']),
      discountType: map['discountType'] ?? map['discount_type'] ?? 'fixed',
      discountValue: SafeConversions.toDouble(map['discountValue'] ?? map['discount_value']),
      tax: SafeConversions.toPrice(map['tax'] ?? map['tax_amount']),
      total: SafeConversions.toPrice(map['total'] ?? map['total_amount']),
      totalAmount: SafeConversions.toPrice(map['totalAmount'] ?? map['total_amount'] ?? map['total']),
      status: map['status'] ?? 'draft',
      archived: map['archived'] ?? false,
      notes: map['notes'],
      comments: map['comments'],
      includeCommentInEmail: map['includeCommentInEmail'] ?? map['include_comment_in_email'] ?? false,
      createdAt:
          DateTime.parse(map['createdAt'] ?? DateTime.now().toIso8601String()),
      expiresAt:
          map['expiresAt'] != null ? DateTime.parse(map['expiresAt']) : null,
      createdBy: map['createdBy'] ?? '',
      projectId: map['projectId'] ?? map['project_id'],
      projectName: map['projectName'] ?? map['project_name'],
    );
  }

  // JSON methods for compatibility
  String toJson() => toMap().toString();
  factory Quote.fromJson(Map<String, dynamic> json) => Quote.fromMap(json);
}

// QuoteItem Model
class QuoteItem {
  final String productId;
  final String productName;
  final Product? product;
  final int quantity;
  final double unitPrice;
  final double total;
  final double totalPrice;
  final DateTime addedAt;
  final double discount; // Individual discount percentage
  final String note; // Individual product note (never null, empty string by default)
  final String? sequenceNumber; // Custom numbering

  QuoteItem({
    required this.productId,
    required this.productName,
    this.product,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    double? totalPrice,
    required this.addedAt,
    this.discount = 0.0,
    this.note = '',
    this.sequenceNumber,
  }) : totalPrice = totalPrice ?? total;

  Map<String, dynamic> toMap() {
    return {
      'productId': productId,
      'productName': productName,
      'product': product?.toMap(),
      'quantity': quantity,
      'unitPrice': unitPrice,
      'total': total,
      'totalPrice': totalPrice,
      'addedAt': addedAt.toIso8601String(),
      'discount': discount,
      'note': note.isEmpty ? null : note, // Store as null in DB if empty to save space
      'sequenceNumber': sequenceNumber,
    };
  }

  factory QuoteItem.fromMap(Map<String, dynamic> map) {
    return QuoteItem(
      productId: map['productId'] ?? map['product_id'] ?? '',
      productName: map['productName'] ?? map['product_name'] ?? '',
      product: map['product'] != null ? Product.fromMap(map['product']) : null,
      quantity: map['quantity'] ?? 1,
      unitPrice: SafeConversions.toPrice(map['unitPrice'] ?? map['unit_price']),
      total: SafeConversions.toPrice(map['total'] ?? map['total_price']),
      totalPrice: SafeConversions.toPrice(map['totalPrice'] ?? map['total_price'] ?? map['total']),
      addedAt:
          DateTime.parse(map['addedAt'] ?? map['added_at'] ?? DateTime.now().toIso8601String()),
      discount: (map['discount'] ?? 0).toDouble(),
      note: map['note'] ?? '',
      sequenceNumber: map['sequenceNumber'] ?? map['sequence_number'],
    );
  }

  // Copy with method for updating items
  QuoteItem copyWith({
    String? productId,
    String? productName,
    Product? product,
    int? quantity,
    double? unitPrice,
    double? total,
    double? totalPrice,
    DateTime? addedAt,
    double? discount,
    String? note,
    String? sequenceNumber,
  }) {
    return QuoteItem(
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      product: product ?? this.product,
      quantity: quantity ?? this.quantity,
      unitPrice: unitPrice ?? this.unitPrice,
      total: total ?? this.total,
      totalPrice: totalPrice ?? this.totalPrice,
      addedAt: addedAt ?? this.addedAt,
      discount: discount ?? this.discount,
      note: note ?? this.note,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
    );
  }

  // JSON methods for compatibility
  String toJson() => toMap().toString();
  factory QuoteItem.fromJson(Map<String, dynamic> json) => QuoteItem.fromMap(json);
}

// CartItem Model
class CartItem {
  final String? id;
  final String? userId;
  final String productId;
  final String productName;
  final Product? product;
  final int quantity;
  final double unitPrice;
  final double total;
  final DateTime addedAt;
  final double discount; // Individual discount percentage (0-100)
  final String note; // Individual product note (never null, empty string by default)
  final String? sequenceNumber; // Custom numbering (001, 002, etc.)

  CartItem({
    this.id,
    this.userId,
    required this.productId,
    required this.productName,
    this.product,
    required this.quantity,
    required this.unitPrice,
    required this.total,
    required this.addedAt,
    this.discount = 0.0,
    this.note = '',
    this.sequenceNumber,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'userId': userId,
      'productId': productId,
      'productName': productName,
      'product': product?.toMap(),
      'quantity': quantity,
      'unitPrice': unitPrice,
      'total': total,
      'addedAt': addedAt.toIso8601String(),
      'discount': discount,
      'note': note.isEmpty ? null : note, // Store as null in DB if empty to save space
      'sequenceNumber': sequenceNumber,
    };
  }

  factory CartItem.fromMap(Map<String, dynamic> map) {
    return CartItem(
      id: map['id'],
      userId: map['userId'],
      productId: map['productId'] ?? '',
      productName: map['productName'] ?? '',
      product: map['product'] != null ? Product.fromMap(map['product']) : null,
      quantity: map['quantity'] ?? 1,
      unitPrice: (map['unitPrice'] ?? 0).toDouble(),
      total: SafeConversions.toPrice(map['total']),
      addedAt:
          DateTime.parse(map['addedAt'] ?? DateTime.now().toIso8601String()),
      discount: (map['discount'] ?? 0).toDouble(),
      note: map['note'] ?? '',
      sequenceNumber: map['sequenceNumber'],
    );
  }

  // JSON methods for compatibility
  String toJson() => toMap().toString();
  factory CartItem.fromJson(Map<String, dynamic> json) => CartItem.fromMap(json);
}

