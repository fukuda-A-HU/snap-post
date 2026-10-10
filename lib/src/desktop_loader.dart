import 'dart:io';

import 'desktop.dart';
import 'windows/windows_desktop.dart' deferred as windows_desktop;

Future<DesktopBridge> loadDesktopBridge() async {
  if (!Platform.isWindows) return UnsupportedDesktopBridge();
  await windows_desktop.loadLibrary();
  return windows_desktop.WindowsDesktopBridge();
}
