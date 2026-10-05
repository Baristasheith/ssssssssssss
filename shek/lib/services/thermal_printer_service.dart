import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../models/scanned_product.dart';

class ThermalPrinterService {
  const ThermalPrinterService();

  Future<List<BluetoothInfo>> getPairedPrinters() async {
    final hasPermission =
        await PrintBluetoothThermal.isPermissionBluetoothGranted;
    if (!hasPermission) {
      throw StateError('لم يتم منح إذن Bluetooth. اسمح به ثم حاول مجددًا.');
    }

    final isBluetoothEnabled = await PrintBluetoothThermal.bluetoothEnabled;
    if (!isBluetoothEnabled) {
      throw StateError('Bluetooth غير مفعّل على الهاتف.');
    }

    return PrintBluetoothThermal.pairedBluetooths;
  }

  Future<bool> get isConnected => PrintBluetoothThermal.connectionStatus;

  Future<bool> connect(String macAddress) {
    return PrintBluetoothThermal.connect(macPrinterAddress: macAddress);
  }

  Future<bool> disconnect() => PrintBluetoothThermal.disconnect;

  Future<bool> printProduct({
    required ScannedProduct product,
    required PaperSize paperSize,
  }) async {
    if (!await isConnected) {
      throw StateError('اتصل بالطابعة قبل الطباعة.');
    }

    final profile = await CapabilityProfile.load();
    final generator = Generator(paperSize, profile);
    final ticket = <int>[
      ...generator.reset(),
      ...await _renderProductDetails(product, paperSize, generator),
      ...generator.feed(1),
      ...generator.barcode(
        Barcode.code128(('{B${product.barcode}').split('')),
        width: 2,
        height: 72,
        textPos: BarcodeText.below,
      ),
      ...generator.feed(3),
      ...generator.cut(),
    ];

    final didPrint = await PrintBluetoothThermal.writeBytes(ticket);
    if (!didPrint) {
      throw StateError('تعذرت الطباعة. تحقق من اتصال الطابعة والورق.');
    }
    return didPrint;
  }

  Future<List<int>> _renderProductDetails(
    ScannedProduct product,
    PaperSize paperSize,
    Generator generator,
  ) async {
    final width = paperSize == PaperSize.mm80 ? 576 : 384;
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder)
      ..drawColor(Colors.white, BlendMode.src);

    var top = 18.0;
    top = _drawText(
      canvas,
      'بطاقة سعر',
      top: top,
      width: width,
      fontSize: 22,
      bold: true,
    );
    top = _drawText(
      canvas,
      product.name,
      top: top + 10,
      width: width,
      fontSize: 30,
      bold: true,
    );
    top = _drawText(
      canvas,
      product.formattedPrice,
      top: top + 14,
      width: width,
      fontSize: 56,
      bold: true,
    );
    top += 20;

    final picture = recorder.endRecording();
    final raster = await picture.toImage(width, top.ceil());
    final pngData = await raster.toByteData(format: ui.ImageByteFormat.png);
    raster.dispose();
    picture.dispose();
    if (pngData == null) {
      throw StateError('تعذر تجهيز صورة بطاقة السعر للطباعة.');
    }

    final decoded = img.decodeImage(
      Uint8List.view(
        pngData.buffer,
        pngData.offsetInBytes,
        pngData.lengthInBytes,
      ),
    );
    if (decoded == null) {
      throw StateError('تعذر تحويل بطاقة السعر إلى صيغة الطابعة.');
    }

    return generator.imageRaster(decoded);
  }

  double _drawText(
    Canvas canvas,
    String value, {
    required double top,
    required int width,
    required double fontSize,
    required bool bold,
  }) {
    final painter = TextPainter(
      text: TextSpan(
        text: value,
        style: TextStyle(
          color: Colors.black,
          fontSize: fontSize,
          fontWeight: bold ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      textDirection: TextDirection.rtl,
      textAlign: TextAlign.center,
    )..layout(maxWidth: width - 28);

    painter.paint(canvas, Offset((width - painter.width) / 2, top));
    return top + painter.height;
  }
}
