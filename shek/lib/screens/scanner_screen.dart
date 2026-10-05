import 'package:esc_pos_utils_plus/esc_pos_utils_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:print_bluetooth_thermal/print_bluetooth_thermal.dart';

import '../models/scanned_product.dart';
import '../services/thermal_printer_service.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  final _formKey = GlobalKey<FormState>();
  final _barcodeController = TextEditingController();
  final _nameController = TextEditingController();
  final _priceController = TextEditingController();
  final _printerService = const ThermalPrinterService();
  final _scannerController = MobileScannerController(
    formats: const [
      BarcodeFormat.codabar,
      BarcodeFormat.code128,
      BarcodeFormat.code39,
      BarcodeFormat.code93,
      BarcodeFormat.ean13,
      BarcodeFormat.ean8,
      BarcodeFormat.itf2of5,
      BarcodeFormat.itf14,
      BarcodeFormat.upcA,
      BarcodeFormat.upcE,
    ],
  );

  List<BluetoothInfo> _printers = [];
  String? _selectedPrinterMac;
  PaperSize _paperSize = PaperSize.mm58;
  bool _isScanning = true;
  bool _isLoadingPrinters = false;
  bool _isConnecting = false;
  bool _isPrinting = false;
  bool _isPrinterConnected = false;
  bool _barcodeWasDetected = false;
  String? _printerError;

  @override
  void initState() {
    super.initState();
    _refreshPrinters();
  }

  @override
  void dispose() {
    _scannerController.dispose();
    _barcodeController.dispose();
    _nameController.dispose();
    _priceController.dispose();
    super.dispose();
  }

  Future<void> _refreshPrinters() async {
    setState(() {
      _isLoadingPrinters = true;
      _printerError = null;
    });

    try {
      final printers = await _printerService.getPairedPrinters();
      final connected = await _printerService.isConnected;
      if (!mounted) return;
      setState(() {
        _printers = printers;
        _isPrinterConnected = connected;
        if (_selectedPrinterMac != null &&
            !printers.any(
              (printer) => printer.macAdress == _selectedPrinterMac,
            )) {
          _selectedPrinterMac = null;
        }
        _printerError = printers.isEmpty
            ? 'لا توجد طابعات مقترنة. اربط الطابعة من إعدادات Bluetooth أولًا.'
            : null;
      });
    } on PlatformException catch (error) {
      if (!mounted) return;
      setState(
        () => _printerError = error.message ?? 'تعذر الوصول إلى Bluetooth.',
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _printerError = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _isLoadingPrinters = false);
    }
  }

  void _onBarcodeDetected(BarcodeCapture capture) {
    if (!_isScanning || _barcodeWasDetected) return;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue?.trim();
      if (value == null || value.isEmpty) continue;

      setState(() {
        _barcodeController.text = value;
        _barcodeWasDetected = true;
        _isScanning = false;
      });
      return;
    }
  }

  Future<void> _connectPrinter() async {
    final macAddress = _selectedPrinterMac;
    if (macAddress == null) {
      _showMessage('اختر طابعة أولًا.');
      return;
    }

    setState(() => _isConnecting = true);
    try {
      final connected = await _printerService.connect(macAddress);
      if (!mounted) return;
      setState(() => _isPrinterConnected = connected);
      _showMessage(
        connected ? 'تم الاتصال بالطابعة.' : 'تعذر الاتصال بالطابعة.',
      );
    } on PlatformException catch (error) {
      if (mounted) _showMessage(error.message ?? 'تعذر الاتصال بالطابعة.');
    } catch (error) {
      if (mounted) _showMessage(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _isConnecting = false);
    }
  }

  Future<void> _disconnectPrinter() async {
    try {
      await _printerService.disconnect();
      if (!mounted) return;
      setState(() => _isPrinterConnected = false);
      _showMessage('تم فصل الطابعة.');
    } on PlatformException catch (error) {
      if (mounted) _showMessage(error.message ?? 'تعذر فصل الطابعة.');
    } catch (error) {
      if (mounted) _showMessage(_errorMessage(error));
    }
  }

  Future<void> _printLabel() async {
    if (!_formKey.currentState!.validate()) return;

    final normalizedPrice = _priceController.text.trim().replaceAll(',', '.');
    final product = ScannedProduct(
      barcode: _barcodeController.text.trim(),
      name: _nameController.text.trim(),
      price: double.parse(normalizedPrice),
    );

    setState(() => _isPrinting = true);
    try {
      await _printerService.printProduct(
        product: product,
        paperSize: _paperSize,
      );
      if (!mounted) return;
      _showMessage('تم إرسال بطاقة السعر إلى الطابعة.');
    } on PlatformException catch (error) {
      if (mounted) _showMessage(error.message ?? 'تعذرت الطباعة.');
    } catch (error) {
      if (mounted) _showMessage(_errorMessage(error));
    } finally {
      if (mounted) setState(() => _isPrinting = false);
    }
  }

  void _startScanning() {
    setState(() {
      _barcodeWasDetected = false;
      _isScanning = true;
      _barcodeController.clear();
      _nameController.clear();
      _priceController.clear();
    });
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _errorMessage(Object error) {
    if (error is StateError) return error.message.toString();
    return 'حدث خطأ غير متوقع: $error';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('ماسح الأسعار'),
        centerTitle: true,
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 8, 18, 28),
          children: [
            _buildIntro(),
            const SizedBox(height: 18),
            _buildScannerCard(),
            const SizedBox(height: 18),
            _buildProductForm(),
            const SizedBox(height: 18),
            _buildPrinterCard(),
          ],
        ),
      ),
    );
  }

  Widget _buildIntro() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'امسح، أدخل السعر، واطبع',
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.bold,
              ),
        ),
        const SizedBox(height: 4),
        Text(
          'وجّه الكاميرا نحو باركود المنتج لإنشاء بطاقة سعر.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Colors.black54,
              ),
        ),
      ],
    );
  }

  Widget _buildScannerCard() {
    return Card(
      clipBehavior: Clip.antiAlias,
      margin: EdgeInsets.zero,
      child: SizedBox(
        height: 210,
        child: _isScanning
            ? Stack(
                fit: StackFit.expand,
                children: [
                  MobileScanner(
                    controller: _scannerController,
                    onDetect: _onBarcodeDetected,
                    errorBuilder: (context, error) => Center(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Text(
                          'تعذر تشغيل الكاميرا. تحقق من إذن الكاميرا ثم أعد المحاولة.\n${error.errorCode.name}',
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ),
                  ),
                  IgnorePointer(
                    child: Center(
                      child: Container(
                        width: 260,
                        height: 92,
                        decoration: BoxDecoration(
                          border: Border.all(
                            color: Theme.of(context).colorScheme.primary,
                            width: 3,
                          ),
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    bottom: 12,
                    left: 12,
                    right: 12,
                    child: Text(
                      'ضع الباركود داخل الإطار',
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                            color: Colors.white,
                            shadows: const [
                              Shadow(color: Colors.black87, blurRadius: 8),
                            ],
                          ),
                    ),
                  ),
                ],
              )
            : _scanAgainPrompt(),
      ),
    );
  }

  Widget _scanAgainPrompt() {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.qr_code_2_rounded,
            size: 42,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(height: 6),
          const Text('تم مسح الباركود'),
          TextButton.icon(
            onPressed: _startScanning,
            icon: const Icon(Icons.refresh),
            label: const Text('مسح منتج آخر'),
          ),
        ],
      ),
    );
  }

  Widget _buildProductForm() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'بيانات المنتج',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          const SizedBox(height: 12),
          TextFormField(
            controller: _barcodeController,
            readOnly: true,
            decoration: const InputDecoration(
              labelText: 'الباركود',
              prefixIcon: Icon(Icons.document_scanner_outlined),
              hintText: 'يظهر بعد المسح',
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'امسح باركود المنتج.'
                : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _nameController,
            textInputAction: TextInputAction.next,
            decoration: const InputDecoration(
              labelText: 'اسم المنتج',
              prefixIcon: Icon(Icons.inventory_2_outlined),
            ),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'أدخل اسم المنتج.'
                : null,
          ),
          const SizedBox(height: 10),
          TextFormField(
            controller: _priceController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            inputFormatters: [
              FilteringTextInputFormatter.allow(RegExp(r'[\d.,]')),
            ],
            decoration: const InputDecoration(
              labelText: 'السعر',
              prefixIcon: Icon(Icons.sell_outlined),
              hintText: 'مثال: 12.50',
            ),
            validator: (value) {
              final parsed =
                  double.tryParse((value ?? '').trim().replaceAll(',', '.'));
              if (parsed == null || !parsed.isFinite || parsed <= 0) {
                return 'أدخل سعرًا صحيحًا أكبر من صفر.';
              }
              return null;
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPrinterCard() {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.print_outlined,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'الطابعة الحرارية',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                ),
                IconButton(
                  tooltip: 'تحديث الطابعات',
                  onPressed: _isLoadingPrinters ? null : _refreshPrinters,
                  icon: _isLoadingPrinters
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.refresh),
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (_printers.isNotEmpty)
              DropdownButtonFormField<String>(
                initialValue: _selectedPrinterMac,
                decoration: const InputDecoration(
                  labelText: 'اختر طابعة مقترنة',
                  prefixIcon: Icon(Icons.bluetooth),
                ),
                items: _printers
                    .map(
                      (printer) => DropdownMenuItem(
                        value: printer.macAdress,
                        child: Text(
                          printer.name.isEmpty
                              ? printer.macAdress
                              : printer.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(),
                onChanged: _isConnecting || _isPrinting
                    ? null
                    : (mac) => setState(() => _selectedPrinterMac = mac),
              )
            else if (_printerError != null)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Text(
                  _printerError!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            const SizedBox(height: 10),
            DropdownButtonFormField<PaperSize>(
              initialValue: _paperSize,
              decoration: const InputDecoration(
                labelText: 'عرض الورق',
                prefixIcon: Icon(Icons.receipt_long_outlined),
              ),
              items: const [
                DropdownMenuItem(
                  value: PaperSize.mm58,
                  child: Text('58 مم'),
                ),
                DropdownMenuItem(
                  value: PaperSize.mm80,
                  child: Text('80 مم'),
                ),
              ],
              onChanged: _isPrinting
                  ? null
                  : (size) {
                      if (size != null) setState(() => _paperSize = size);
                    },
            ),
            const SizedBox(height: 12),
            if (_isPrinterConnected)
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isPrinting ? null : _disconnectPrinter,
                  icon: const Icon(Icons.bluetooth_connected),
                  label: const Text('متصل — فصل الطابعة'),
                ),
              )
            else
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _isConnecting || _selectedPrinterMac == null
                      ? null
                      : _connectPrinter,
                  icon: _isConnecting
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.bluetooth),
                  label: const Text('اتصال بالطابعة'),
                ),
              ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: _isPrinting || !_isPrinterConnected ? null : _printLabel,
                icon: _isPrinting
                    ? const SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.print),
                label: Text(_isPrinting ? 'جارٍ الطباعة...' : 'طباعة بطاقة السعر'),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'يجب إقران الطابعة بالهاتف من إعدادات Bluetooth قبل الاتصال.',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Colors.black54,
                  ),
            ),
          ],
        ),
      ),
    );
  }
}
