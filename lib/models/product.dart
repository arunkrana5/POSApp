class Product {
  final int id;
  final int? itemId;
  final String productCode;
  final String name;
  final String category;
  final String brand;
  final String unit;
  final String barcode;
  final double purchasePrice;
  final double sellingPrice;
  final double mrp;
  final double gstPercent;
  final double currentStock;
  final double minimumStock;
  final String batchNumber;
  final String rackNumber;
  final String expiryDate;
  final String hsnCode;
  final String imageUrl;

  Product({
    required this.id,
    this.itemId,
    required this.productCode,
    required this.name,
    required this.category,
    this.brand = '',
    required this.unit,
    required this.barcode,
    required this.purchasePrice,
    required this.sellingPrice,
    required this.mrp,
    this.gstPercent = 0.0,
    required this.currentStock,
    this.minimumStock = 5.0,
    this.batchNumber = '',
    this.rackNumber = '',
    this.expiryDate = '',
    this.hsnCode = '',
    this.imageUrl = '',
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'itemId': itemId,
      'productCode': productCode,
      'name': name,
      'category': category,
      'brand': brand,
      'unit': unit,
      'barcode': barcode,
      'purchasePrice': purchasePrice,
      'sellingPrice': sellingPrice,
      'mrp': mrp,
      'gstPercent': gstPercent,
      'currentStock': currentStock,
      'minimumStock': minimumStock,
      'batchNumber': batchNumber,
      'rackNumber': rackNumber,
      'expiryDate': expiryDate,
      'hsnCode': hsnCode,
      'imageUrl': imageUrl,
    };
  }

  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'] ?? map['ID'] ?? 0,
      itemId: (map['itemId'] as num?)?.toInt() ?? (map['ItemID'] as num?)?.toInt(),
      productCode: map['productCode'] ?? map['ProductCode'] ?? '',
      name: map['name'] ?? map['Name'] ?? '',
      category: map['category'] ?? map['Category'] ?? '',
      brand: map['brand'] ?? map['Brand'] ?? '',
      unit: map['unit'] ?? map['Unit'] ?? 'pcs',
      barcode: map['barcode'] ?? map['Barcode'] ?? '',
      purchasePrice: (map['purchasePrice'] as num?)?.toDouble() ?? (map['PurchasePrice'] as num?)?.toDouble() ?? 0.0,
      sellingPrice: (map['sellingPrice'] as num?)?.toDouble() ?? (map['SellingPrice'] as num?)?.toDouble() ?? 0.0,
      mrp: (map['mrp'] as num?)?.toDouble() ?? (map['MRP'] as num?)?.toDouble() ?? 0.0,
      gstPercent: (map['gstPercent'] as num?)?.toDouble() ?? (map['GSTPercent'] as num?)?.toDouble() ?? 0.0,
      currentStock: (map['currentStock'] as num?)?.toDouble() ?? (map['CurrentStock'] as num?)?.toDouble() ?? 0.0,
      minimumStock: (map['minimumStock'] as num?)?.toDouble() ?? (map['MinimumStock'] as num?)?.toDouble() ?? 5.0,
      batchNumber: map['batchNumber'] ?? map['BatchNumber'] ?? '',
      rackNumber: map['rackNumber'] ?? map['RackNumber'] ?? '',
      expiryDate: map['expiryDate'] != null ? map['expiryDate'].toString().split('T')[0] : '',
      hsnCode: map['hsnCode'] ?? map['HSNCode'] ?? '',
      imageUrl: map['imageUrl'] ?? map['ImageUrl'] ?? '',
    );
  }

  factory Product.fromJson(Map<String, dynamic> json) => Product.fromMap(json);
}
