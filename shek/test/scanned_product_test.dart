import 'package:flutter_test/flutter_test.dart';
import 'package:price_label_scanner/models/scanned_product.dart';

void main() {
  group('ScannedProduct', () {
    test('formats whole prices without decimal places', () {
      const product = ScannedProduct(barcode: '12345678', name: 'Tea', price: 12);

      expect(product.formattedPrice, '12');
    });

    test('keeps non-zero decimal places', () {
      const product =
          ScannedProduct(barcode: '12345678', name: 'Tea', price: 12.5);

      expect(product.formattedPrice, '12.50');
    });
  });
}
