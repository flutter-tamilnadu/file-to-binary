import 'package:flutter/material.dart';

import 'base64_crafter_widget.dart';

void main() {

  runApp(const MaterialApp(
    title: 'Base64 Encoder / Decoder',
    home: FilePickerWithBase64Viewer(),
  ));
}