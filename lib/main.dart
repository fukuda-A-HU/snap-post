import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hotkey_manager/hotkey_manager.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'src/app_settings.dart';
import 'src/desktop.dart';
import 'src/desktop_loader.dart';
import 'src/reply_target.dart';
import 'src/settings_page.dart';
import 'src/settings_store.dart';
import 'src/snap_service.dart';
import 'src/window_match.dart';

Future<void> main(List<String> args) async {
  WidgetsFlutterBinding.ensureInitialized();
  await windowManager.ensureInitialized();
  await windowManager.setPreventClose(true);
  windowManager.addListener(_HideOnClose());

  final startHidden = args.contains('--hidden');
  unawaited(
    windowManager.waitUntilReadyToShow(
      const WindowOptions(
        size: Size(900, 760),
        minimumSize: Size(680, 560),
        center: true,
        title: 'SnapPost',
      ),
      () async {
        if (startHidden) {
          await hideToTray();
        } else {
          await showSettingsWindow();
        }
      },
    ),
  );

  try {
    await localNotifier.setup(appName: 'SnapPost');
  } catch (_) {}

  if (Platform.isWindows) {
    final executable = Platform.resolvedExecutable;
    final appPath = executable.contains(' ') ? '"$executable"' : executable;
    launchAtStartup.setup(
      appName: 'SnapPost',
      appPath: appPath,
      args: const <String>['--hidden'],
    );
  }

  final store = SettingsStore(await resolveSettingsFile());
  final desktop = await loadDesktopBridge();
  runApp(SnapApp(store: store, desktop: desktop));
}

Future<void> hideToTray() async {
  await windowManager.setSkipTaskbar(true);
  await windowManager.hide();
}

Future<void> showSettingsWindow() async {
  await windowManager.setSkipTaskbar(false);
  await windowManager.show();
  await windowManager.focus();
}

class _HideOnClose extends WindowListener {
  @override
  void onWindowClose() {
    unawaited(hideToTray());
  }
}

class SnapApp extends StatefulWidget {
  const SnapApp({required this.store, required this.desktop, super.key});

  final SettingsStore store;
  final DesktopBridge desktop;

  @override
  State<SnapApp> createState() => _SnapAppState();
}

class _SnapAppState extends State<SnapApp> with TrayListener {
  late final SnapService _service = SnapService(widget.desktop);
  AppSettings _settings = AppSettings.defaults();
  List<WindowSummary> _windows = const <WindowSummary>[];
  HotKey? _registeredHotkey;
  var _ready = false;
  var _busy = false;
  var _hotkeyPaused = false;
  var _replyEpoch = 0;

  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    unawaited(_start());
  }

  @override
  void dispose() {
    trayManager.removeListener(this);
    super.dispose();
  }

  Future<void> _start() async {
    final settings = await widget.store.load();
    if (!mounted) return;
    setState(() {
      _settings = settings;
      _ready = true;
    });
    await _setupTray();
    await _applyHotkey(settings.hotkey);
    await _applyStartup(settings.launchAtStartup);
    await _refreshWindows();
  }

  Future<void> _setupTray() async {
    if (!Platform.isWindows) return;
    try {
      await trayManager.setIcon('assets/tray_icon.png');
      await trayManager.setToolTip('SnapPost');
      await trayManager.setContextMenu(
        Menu(
          items: <MenuItem>[
            MenuItem(key: 'open', label: '設定を開く', onClick: (_) => _open()),
            MenuItem(
              key: 'capture',
              label: '今すぐ撮る',
              onClick: (_) => unawaited(_captureSaved()),
            ),
            MenuItem(
              key: 'reply',
              label: 'つなげる先を更新',
              onClick: (_) => unawaited(_updateReplyFromClipboard()),
            ),
            MenuItem.separator(),
            MenuItem(
              key: 'exit',
              label: '終了',
              onClick: (_) => unawaited(_quit()),
            ),
          ],
        ),
      );
    } catch (_) {}
  }

  @override
  void onTrayIconMouseUp() {
    unawaited(showSettingsWindow());
  }

  void _open() {
    unawaited(showSettingsWindow());
  }

  Future<void> _refreshWindows() async {
    try {
      final windows = await widget.desktop.listVisibleWindows();
      if (!mounted) return;
      setState(() => _windows = windows);
    } catch (_) {
      if (!mounted) return;
      setState(() => _windows = const <WindowSummary>[]);
    }
  }

  Future<void> _save(AppSettings settings) async {
    await widget.store.save(settings);
    if (!mounted) return;
    setState(() => _settings = settings);
    await _applyHotkey(settings.hotkey);
    await _applyStartup(settings.launchAtStartup);
  }

  Future<void> _captureSaved() => _capture(_settings);

  /// Returns the status id stored from the clipboard, or null when it is not
  /// a tweet URL or numeric id.
  Future<String?> _updateReplyFromClipboard() async {
    String? text;
    try {
      text = await widget.desktop.readClipboardText();
    } catch (_) {
      text = null;
    }
    final id = parseStatusId(text ?? '');
    if (id == null) {
      await _notify('クリップボードからツイート URL を読めませんでした');
      return null;
    }
    final updated = _settings.copyWith(replyTweet: id);
    try {
      await widget.store.save(updated);
    } catch (_) {
      await _notify('つなげる先の保存に失敗しました');
      return null;
    }
    if (!mounted) return id;
    setState(() {
      _settings = updated;
      _replyEpoch++;
    });
    await _notify('つなげる先を $id に更新しました');
    return id;
  }

  Future<void> _capture(AppSettings settings) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await _service.captureAndPost(settings: settings, notify: _notify);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _notify(String message) async {
    final notification = LocalNotification(title: 'SnapPost', body: message);
    await notification.show();
  }

  Future<void> _applyHotkey(HotkeyConfig config) async {
    if (!Platform.isWindows || _hotkeyPaused) return;
    try {
      final previous = _registeredHotkey;
      if (previous != null) {
        await hotKeyManager.unregister(previous);
        _registeredHotkey = null;
      }
      final hotkey = _hotKeyFromConfig(config);
      await hotKeyManager.register(
        hotkey,
        keyDownHandler: (_) => unawaited(_captureSaved()),
      );
      _registeredHotkey = hotkey;
    } catch (_) {}
  }

  Future<void> _setRecording(bool recording) async {
    _hotkeyPaused = recording;
    if (!Platform.isWindows) return;
    if (recording) {
      final previous = _registeredHotkey;
      if (previous != null) {
        try {
          await hotKeyManager.unregister(previous);
        } catch (_) {}
        _registeredHotkey = null;
      }
      return;
    }
    await _applyHotkey(_settings.hotkey);
  }

  Future<void> _applyStartup(bool enabled) async {
    if (!Platform.isWindows) return;
    try {
      if (enabled) {
        await launchAtStartup.enable();
      } else {
        await launchAtStartup.disable();
      }
    } catch (_) {}
  }

  Future<void> _quit() async {
    final previous = _registeredHotkey;
    if (previous != null) {
      try {
        await hotKeyManager.unregister(previous);
      } catch (_) {}
    }
    try {
      await trayManager.destroy();
    } catch (_) {}
    exit(0);
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SnapPost',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF1D9BF0)),
        useMaterial3: true,
      ),
      home: _ready
          ? SettingsPage(
              settings: _settings,
              windows: _windows,
              busy: _busy,
              onRefresh: _refreshWindows,
              onSave: _save,
              onCapture: (draft) async {
                await _save(draft);
                await _capture(draft);
              },
              onQuit: _quit,
              onRecordingChanged: (recording) =>
                  unawaited(_setRecording(recording)),
              onUpdateReplyTarget: _updateReplyFromClipboard,
              replyEpoch: _replyEpoch,
            )
          : const Scaffold(body: Center(child: CircularProgressIndicator())),
    );
  }
}

HotKey _hotKeyFromConfig(HotkeyConfig config) {
  final key =
      LogicalKeyboardKey.findKeyByKeyId(config.keyId) ??
      LogicalKeyboardKey.keyS;
  return HotKey(
    key: key,
    modifiers: <HotKeyModifier>[
      if (config.control) HotKeyModifier.control,
      if (config.shift) HotKeyModifier.shift,
      if (config.alt) HotKeyModifier.alt,
      if (config.meta) HotKeyModifier.meta,
    ],
    scope: HotKeyScope.system,
  );
}
