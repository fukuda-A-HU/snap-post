import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:launch_at_startup/launch_at_startup.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';

import 'src/app_settings.dart';
import 'src/desktop.dart';
import 'src/desktop_loader.dart';
import 'src/home_page.dart';
import 'src/images.dart';
import 'src/reply_target.dart';
import 'src/settings_page.dart';
import 'src/settings_store.dart';
import 'src/shot_list.dart';
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
        size: Size(980, 820),
        minimumSize: Size(720, 640),
        center: true,
        title: 'SnapPost',
      ),
      () async {
        if (startHidden) {
          await hideToTray();
        } else {
          await showMainWindow();
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

Future<void> showMainWindow() async {
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
  final ShotList _shots = ShotList();
  AppSettings _settings = AppSettings.defaults();
  List<WindowSummary> _windows = const <WindowSummary>[];
  var _ready = false;
  var _busy = false;
  var _showSettings = false;
  String? _captureError;

  @override
  void initState() {
    super.initState();
    trayManager.addListener(this);
    widget.desktop.listenForActivation(_showFromAnotherLaunch);
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
            MenuItem(
              key: 'open',
              label: 'ウィンドウを開く',
              onClick: (_) => unawaited(_openWindow()),
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
    unawaited(_openWindow());
  }

  void _showFromAnotherLaunch() {
    unawaited(_openWindow());
  }

  Future<void> _openWindow() async {
    if (mounted) setState(() => _showSettings = false);
    await showMainWindow();
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
    await _applyStartup(settings.launchAtStartup);
  }

  Future<void> _capture() async {
    if (_busy) return;
    if (!_settings.hasTarget) {
      setState(() => _captureError = '対象ウィンドウが選ばれていません');
      return;
    }
    setState(() {
      _busy = true;
      _captureError = null;
    });
    try {
      final root = _saveRoot();
      final attempt = await _service.captureToDirectory(
        settings: _settings,
        directory: root,
      );
      if (!mounted) return;
      switch (attempt.status) {
        case CaptureStatus.saved:
          setState(() => _shots.add(attempt.path!));
        case CaptureStatus.missingTarget:
          setState(() => _captureError = '対象ウィンドウが選ばれていません');
        case CaptureStatus.notFound:
          setState(() => _captureError = '対象のウィンドウが見つかりません');
        case CaptureStatus.failed:
          setState(() => _captureError = 'スクリーンショットに失敗しました');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _post() async {
    if (_busy || _shots.selectedPaths.isEmpty) return;
    setState(() => _busy = true);
    try {
      final posted = await _service.openPost(
        settings: _settings,
        sourcePaths: _shots.selectedPaths,
        saveRoot: _saveRoot(),
        notify: _notify,
      );
      if (!posted || !mounted) return;
      final remove = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          content: const Text('投稿に使った画像をリストから外しますか？'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('いいえ'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('はい'),
            ),
          ],
        ),
      );
      if (remove == true && mounted) {
        setState(() => _shots.dropSelected());
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteAt(int index) async {
    final shot = _shots.removeAt(index);
    try {
      await File(shot.path).delete();
    } catch (_) {}
    if (mounted) setState(() {});
  }

  Future<void> _clearAll() async {
    final paths = _shots.paths.toList();
    _shots.clear();
    for (final filePath in paths) {
      try {
        await File(filePath).delete();
      } catch (_) {}
    }
    if (mounted) setState(() {});
  }

  Future<void> _updateReplyFromClipboard() async {
    String? text;
    try {
      text = await widget.desktop.readClipboardText();
    } catch (_) {
      text = null;
    }
    final raw = text?.trim() ?? '';
    if (parseStatusId(raw) == null) {
      await _notify('クリップボードからツイート URL を読めませんでした');
      return;
    }
    final updated = _settings.copyWith(replyTweet: raw);
    try {
      await widget.store.save(updated);
    } catch (_) {
      await _notify('つなげる先の保存に失敗しました');
      return;
    }
    if (!mounted) return;
    setState(() => _settings = updated);
  }

  Future<void> _setContinueThread(bool enabled) async {
    final updated = _settings.copyWith(continueThread: enabled);
    setState(() => _settings = updated);
    try {
      await widget.store.save(updated);
    } catch (_) {}
  }

  String _saveRoot() {
    final folder = _settings.saveFolder.trim();
    if (folder.isEmpty) return picturesDirectory(Platform.environment);
    return folder;
  }

  Future<void> _notify(String message) async {
    final notification = LocalNotification(title: 'SnapPost', body: message);
    await notification.show();
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
      home: !_ready
          ? const Scaffold(body: Center(child: CircularProgressIndicator()))
          : IndexedStack(
              index: _showSettings ? 1 : 0,
              sizing: StackFit.expand,
              children: [
                HomePage(
                  settings: _settings,
                  shots: _shots,
                  busy: _busy,
                  captureError: _captureError,
                  onCapture: () => unawaited(_capture()),
                  onOpenSettings: () => setState(() => _showSettings = true),
                  onToggle: (index, selected) {
                    setState(() => _shots.setSelected(index, selected));
                  },
                  onDelete: (index) => unawaited(_deleteAt(index)),
                  onClear: () => unawaited(_clearAll()),
                  onPost: () => unawaited(_post()),
                  onContinueThread: (value) =>
                      unawaited(_setContinueThread(value)),
                  onUpdateReply: () => unawaited(_updateReplyFromClipboard()),
                ),
                SettingsPage(
                  settings: _settings,
                  windows: _windows,
                  busy: _busy,
                  onRefresh: _refreshWindows,
                  onSave: _save,
                  onBack: () => setState(() => _showSettings = false),
                ),
              ],
            ),
    );
  }
}
