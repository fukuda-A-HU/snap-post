class WindowTarget {
  const WindowTarget({required this.processExe, required this.titleSubstring});

  final String processExe;
  final String titleSubstring;
}

class WindowSummary {
  const WindowSummary({
    required this.hwnd,
    required this.title,
    required this.processExe,
  });

  final int hwnd;
  final String title;
  final String processExe;
}

/// Picks a visible window by executable name and an optional title substring.
///
/// When several windows match and [foregroundHwnd] is one of them, that window
/// is preferred.
WindowSummary? findMatchingWindow(
  List<WindowSummary> windows,
  WindowTarget target, {
  int? foregroundHwnd,
}) {
  final exe = target.processExe.trim().toLowerCase();
  if (exe.isEmpty) return null;
  final titlePart = target.titleSubstring.trim().toLowerCase();
  WindowSummary? first;
  for (final window in windows) {
    if (window.processExe.toLowerCase() != exe) continue;
    if (titlePart.isNotEmpty &&
        !window.title.toLowerCase().contains(titlePart)) {
      continue;
    }
    if (foregroundHwnd != null && window.hwnd == foregroundHwnd) {
      return window;
    }
    first ??= window;
  }
  return first;
}
