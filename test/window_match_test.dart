import 'package:flutter_test/flutter_test.dart';
import 'package:snap_post/src/window_match.dart';

void main() {
  const windows = <WindowSummary>[
    WindowSummary(hwnd: 1, title: 'VRChat', processExe: 'VRChat.exe'),
    WindowSummary(hwnd: 2, title: 'Other', processExe: 'notepad.exe'),
    WindowSummary(hwnd: 3, title: 'VRChat Home', processExe: 'vrchat.exe'),
  ];

  test('matches the executable and an optional title substring', () {
    expect(
      findMatchingWindow(
        windows,
        const WindowTarget(processExe: 'VRChat.exe', titleSubstring: ''),
      )?.hwnd,
      1,
    );
    expect(
      findMatchingWindow(
        windows,
        const WindowTarget(processExe: 'vrchat.exe', titleSubstring: 'home'),
      )?.hwnd,
      3,
    );
    expect(
      findMatchingWindow(
        windows,
        const WindowTarget(processExe: '', titleSubstring: 'VRChat'),
      ),
      isNull,
    );
    expect(
      findMatchingWindow(
        windows,
        const WindowTarget(processExe: 'missing.exe', titleSubstring: ''),
      ),
      isNull,
    );
  });

  test('prefers the foreground window when several match', () {
    expect(
      findMatchingWindow(
        windows,
        const WindowTarget(processExe: 'VRChat.exe', titleSubstring: ''),
        foregroundHwnd: 3,
      )?.hwnd,
      3,
    );
  });
}
