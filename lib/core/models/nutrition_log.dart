import 'dart:convert';

/// A single scanned food product from the Open Food Facts database.
///
/// Created when the user scans a barcode via the Capture screen.
/// Stored as JSON in the `nutrition_data` column of the captures table
/// and in the dedicated `nutrition_logs` table for longitudinal queries.
class NutritionLog {
  /// EAN / UPC barcode string.
  final String barcode;

  /// Human-readable product name (e.g. "Nutella 400 g").
  final String productName;

  /// Optional brand name.
  final String? brand;

  /// Nutri-Score grade if available (a / b / c / d / e).
  final String? nutriScore;

  /// NOVA food processing group (1–4), if available.
  final int? novaGroup;

  /// Per-100 g macronutrient breakdown.
  final NutritionFacts? per100g;

  /// The serving size string from Open Food Facts (e.g. "30 g").
  final String? servingSize;

  /// Per-serving macronutrient breakdown (when the API provides it).
  final NutritionFacts? perServing;

  /// URL to the product image, if any.
  final String? imageUrl;

  /// When this product was scanned.
  final DateTime scannedAt;

  /// Optional user-reported quantity eaten (e.g. "2 servings", "half bar").
  final String? quantityNote;

  const NutritionLog({
    required this.barcode,
    required this.productName,
    this.brand,
    this.nutriScore,
    this.novaGroup,
    this.per100g,
    this.servingSize,
    this.perServing,
    this.imageUrl,
    required this.scannedAt,
    this.quantityNote,
  });

  NutritionLog copyWith({
    String? barcode,
    String? productName,
    String? brand,
    bool clearBrand = false,
    String? nutriScore,
    bool clearNutriScore = false,
    int? novaGroup,
    bool clearNovaGroup = false,
    NutritionFacts? per100g,
    bool clearPer100g = false,
    String? servingSize,
    bool clearServingSize = false,
    NutritionFacts? perServing,
    bool clearPerServing = false,
    String? imageUrl,
    bool clearImageUrl = false,
    DateTime? scannedAt,
    String? quantityNote,
    bool clearQuantityNote = false,
  }) {
    return NutritionLog(
      barcode: barcode ?? this.barcode,
      productName: productName ?? this.productName,
      brand: clearBrand ? null : (brand ?? this.brand),
      nutriScore: clearNutriScore ? null : (nutriScore ?? this.nutriScore),
      novaGroup: clearNovaGroup ? null : (novaGroup ?? this.novaGroup),
      per100g: clearPer100g ? null : (per100g ?? this.per100g),
      servingSize: clearServingSize ? null : (servingSize ?? this.servingSize),
      perServing: clearPerServing ? null : (perServing ?? this.perServing),
      imageUrl: clearImageUrl ? null : (imageUrl ?? this.imageUrl),
      scannedAt: scannedAt ?? this.scannedAt,
      quantityNote: clearQuantityNote
          ? null
          : (quantityNote ?? this.quantityNote),
    );
  }

  Map<String, dynamic> toJson() => {
    'barcode': barcode,
    'product_name': productName,
    'brand': brand,
    'nutri_score': nutriScore,
    'nova_group': novaGroup,
    'per_100g': per100g?.toJson(),
    'serving_size': servingSize,
    'per_serving': perServing?.toJson(),
    'image_url': imageUrl,
    'scanned_at': scannedAt.toIso8601String(),
    'quantity_note': quantityNote,
  };

  factory NutritionLog.fromJson(Map<String, dynamic> json) {
    return NutritionLog(
      barcode: json['barcode'] as String,
      productName: json['product_name'] as String? ?? 'Unknown product',
      brand: json['brand'] as String?,
      nutriScore: json['nutri_score'] as String?,
      novaGroup: json['nova_group'] as int?,
      per100g: json['per_100g'] != null
          ? NutritionFacts.fromJson(json['per_100g'] as Map<String, dynamic>)
          : null,
      servingSize: json['serving_size'] as String?,
      perServing: json['per_serving'] != null
          ? NutritionFacts.fromJson(json['per_serving'] as Map<String, dynamic>)
          : null,
      imageUrl: json['image_url'] as String?,
      scannedAt: json['scanned_at'] != null
          ? DateTime.parse(json['scanned_at'] as String)
          : DateTime.now(),
      quantityNote: json['quantity_note'] as String?,
    );
  }

  /// Encode to JSON string for SQLite TEXT column storage.
  String encode() => jsonEncode(toJson());

  /// Decode from a nullable JSON string (SQLite TEXT column).
  static NutritionLog? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      return NutritionLog.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null;
    }
  }

  /// Encode a list of logs for the captures column.
  static String encodeList(List<NutritionLog> logs) {
    return jsonEncode(logs.map((l) => l.toJson()).toList());
  }

  /// Decode a list of logs from the captures column.
  static List<NutritionLog> decodeList(String? raw) {
    if (raw == null || raw.isEmpty) return const [];
    try {
      final list = jsonDecode(raw) as List;
      return list
          .map((e) => NutritionLog.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return const [];
    }
  }

  /// Short human-readable label for UI display.
  String get displayLabel {
    final b = brand != null ? '$brand · ' : '';
    return '$b$productName';
  }

  /// Sugar content summary for quick display.
  String get sugarSummary {
    final sugar = per100g?.sugars;
    if (sugar == null) return 'Sugar: n/a';
    return 'Sugar: ${sugar.toStringAsFixed(1)} g / 100 g';
  }
}

/// Macronutrient breakdown (per 100 g or per serving).
class NutritionFacts {
  /// Energy in kcal.
  final double? energyKcal;

  /// Total fat in grams.
  final double? fat;

  /// Saturated fat in grams.
  final double? saturatedFat;

  /// Total carbohydrates in grams.
  final double? carbohydrates;

  /// Sugars in grams (subset of carbohydrates).
  final double? sugars;

  /// Fiber in grams.
  final double? fiber;

  /// Protein in grams.
  final double? proteins;

  /// Salt in grams.
  final double? salt;

  /// Sodium in grams.
  final double? sodium;

  const NutritionFacts({
    this.energyKcal,
    this.fat,
    this.saturatedFat,
    this.carbohydrates,
    this.sugars,
    this.fiber,
    this.proteins,
    this.salt,
    this.sodium,
  });

  Map<String, dynamic> toJson() => {
    'energy_kcal': energyKcal,
    'fat': fat,
    'saturated_fat': saturatedFat,
    'carbohydrates': carbohydrates,
    'sugars': sugars,
    'fiber': fiber,
    'proteins': proteins,
    'salt': salt,
    'sodium': sodium,
  };

  factory NutritionFacts.fromJson(Map<String, dynamic> json) {
    return NutritionFacts(
      energyKcal: (json['energy_kcal'] as num?)?.toDouble(),
      fat: (json['fat'] as num?)?.toDouble(),
      saturatedFat: (json['saturated_fat'] as num?)?.toDouble(),
      carbohydrates: (json['carbohydrates'] as num?)?.toDouble(),
      sugars: (json['sugars'] as num?)?.toDouble(),
      fiber: (json['fiber'] as num?)?.toDouble(),
      proteins: (json['proteins'] as num?)?.toDouble(),
      salt: (json['salt'] as num?)?.toDouble(),
      sodium: (json['sodium'] as num?)?.toDouble(),
    );
  }

  /// One-line macro summary.
  String get macroLine {
    final parts = <String>[];
    if (energyKcal != null) parts.add('${energyKcal!.toStringAsFixed(0)} kcal');
    if (proteins != null) parts.add('P ${proteins!.toStringAsFixed(1)}g');
    if (carbohydrates != null)
      parts.add('C ${carbohydrates!.toStringAsFixed(1)}g');
    if (fat != null) parts.add('F ${fat!.toStringAsFixed(1)}g');
    if (sugars != null) parts.add('S ${sugars!.toStringAsFixed(1)}g');
    return parts.join(' · ');
  }
}
