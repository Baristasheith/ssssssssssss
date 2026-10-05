class ScannedProduct {
  const ScannedProduct({
    required this.barcode,
    required this.name,
    required this.price,
  });

  final String barcode;
  final String name;
  final double price;

  String get formattedPrice {
    final value = price.toStringAsFixed(2);
    return value.endsWith('.00') ? value.substring(0, value.length - 3) : value;
  }
}
