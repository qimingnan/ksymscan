import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_barcode_scanning/google_mlkit_barcode_scanning.dart';

import '../../common/application.dart';
import '../../generated/l10n.dart';
import '../../model/qr_bar_data.dart';
import '../../utils/pub_method.dart';
import '../bar_create_view.dart';
import '../qr_create_view.dart';
import 'detector_view.dart';
import 'painters/barcode_detector_painter.dart';

class BarcodeScannerView extends StatefulWidget {
  @override
  State<BarcodeScannerView> createState() => _BarcodeScannerViewState();
}

class _BarcodeScannerViewState extends State<BarcodeScannerView> {
  final BarcodeScanner _barcodeScanner = BarcodeScanner();
  bool _canProcess = true;
  bool _isBusy = false;
  CustomPaint? _customPaint;
  String? _text;
  var _cameraLensDirection = CameraLensDirection.back;

  List<IconData> imageUrl = [
    Icons.text_fields_sharp,
    Icons.person_2_sharp,
    Icons.email_sharp,
    Icons.phone_android_sharp,
    Icons.link_sharp,
    Icons.wifi_password_sharp,
    Icons.sms_sharp,
    Icons.android_sharp,
  ];

  var title = [];

  @override
  void dispose() {
    _canProcess = false;
    _barcodeScanner.close();
    super.dispose();
  }

  @override
  void initState() {
    // TODO: implement initState
    super.initState();
  }

  initTitle() {
    title = S.of(context).qrTitle.split(',');
  }

  @override
  Widget build(BuildContext context) {
    initTitle();
    return DetectorView(
      title: S.of(context).scanTitle,
      customPaint: _customPaint,
      text: _text,
      onImage: _processImage,
      initialCameraLensDirection: _cameraLensDirection,
      onCameraLensDirectionChanged: (value) => _cameraLensDirection = value,
    );
  }

  Future<void> _processImage(InputImage inputImage) async {
    if (!_canProcess) return;
    if (_isBusy) return;
    _isBusy = true;
    setState(() {
      _text = '';
    });
    final barcodes = await _barcodeScanner.processImage(inputImage);
    if (inputImage.metadata?.size != null &&
        inputImage.metadata?.rotation != null) {
      final painter = BarcodeDetectorPainter(
        barcodes,
        inputImage.metadata!.size,
        inputImage.metadata!.rotation,
        _cameraLensDirection,
      );
      _customPaint = CustomPaint(painter: painter);
      for (final Barcode barcode in barcodes) {
        skipBarcode(barcode);
      }
    } else {
      String text = 'Barcodes found: ${barcodes.length}\n\n';
      for (final barcode in barcodes) {
        text += 'Barcode: ${barcode.rawValue}\n\n';
        skipBarcode(barcode);
      }
      _text = text;
      // TODO: set _customPaint to draw boundingRect on top of image
      _customPaint = null;
    }
    _isBusy = false;
    if (mounted) {
      setState(() {});
    }
  }

  void skipBarcode(Barcode barcode) {
    var qrBarData = QrBarData();
    qrBarData.contents = [];
    var selectTitleIndex = 0;
    if (BarcodeFormat.qrCode == barcode.format) {
      if (barcode.type == BarcodeType.url) {
        selectTitleIndex = 4;
        qrBarData.contents?.add(barcode.displayValue.toString());
      } else if (barcode.type == BarcodeType.email) {
        selectTitleIndex = 2;
        var value = barcode.value as BarcodeEmail;
        qrBarData.contents?.add(value.address ?? '');
      } else if (barcode.type == BarcodeType.phone) {
        selectTitleIndex = 3;
      } else if (barcode.type == BarcodeType.wifi) {
        selectTitleIndex = 5;
      } else if (barcode.type == BarcodeType.text) {
        selectTitleIndex = 0;
      } else if (barcode.type == BarcodeType.contactInfo) {
        selectTitleIndex = 1;
        var value = barcode.value as BarcodeContactInfo;
        qrBarData.contents?.add(value.firstName ?? '');
        qrBarData.contents?.add(value.phoneNumbers[0].number ?? '');
        qrBarData.contents?.add(value.emails[0].address ?? '');
        qrBarData.contents?.add(value.organizationName ?? '');
      } else if (barcode.type == BarcodeType.unknown) {
        selectTitleIndex = 1;
      } else {
        selectTitleIndex = 7; // Default to SMS or other
      }
      if (selectTitleIndex != 7) {
        qrBarData.iconUrl = imageUrl[selectTitleIndex].codePoint;
        qrBarData.title = title[selectTitleIndex];
        qrBarData.enumType = barcode.type.name;
        qrBarData.index = selectTitleIndex;
      }
      qrBarData.content = barcode.rawValue;

      Application.addQrBarData(qrBarData);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => QrCreateViewPage(
            qrBarData: qrBarData,
          ),
        ),
      );
    } else {
      switch (barcode.format.index) {
        case 2:
          selectTitleIndex = 0; // Code128
          break;
        case 3:
          selectTitleIndex = 4; // Code39
          break;
        case 4:
          selectTitleIndex = 6; // Code93
          break;
        case 5:
          selectTitleIndex = 7; // Codabar
          break;
        case 7:
          selectTitleIndex = 8; // EAN13
          break;
        case 8:
          selectTitleIndex = 9; // EAN8
          break;
        case 11:
          selectTitleIndex = 10; // UPC-A
          break;
        case 12:
          selectTitleIndex = 11; // UPC-E
          break;
        default:
          selectTitleIndex = 11; // Default to unknown barcode type
      }

      qrBarData.imgUrl = barcode.format.name;
      qrBarData.title = barcode.format.name;
      qrBarData.content = barcode.rawValue;
      qrBarData.contents = [barcode.displayValue.toString()];
      qrBarData.index = selectTitleIndex;
      Application.addQrBarData(qrBarData);
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BarCreateViewPage(
            qrBarData: qrBarData,
          ),
        ),
      );
    }
  }
}
