import 'dart:io';

import 'package:material_ui/material_ui.dart';

Widget? localBackground(String path) {
  final file = File(path);
  if (!file.existsSync()) return null;
  return Image.file(file, fit: BoxFit.cover, errorBuilder: (_, _, _) => const SizedBox.shrink());
}
