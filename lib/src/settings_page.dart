import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_settings.dart';
import 'hashtags.dart';
import 'reply_target.dart';
import 'window_match.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.settings,
    required this.windows,
    required this.busy,
    required this.onRefresh,
    required this.onSave,
    required this.onCapture,
    required this.onQuit,
    required this.onRecordingChanged,
    required this.onUpdateReplyTarget,
    required this.replyEpoch,
    super.key,
  });

  final AppSettings settings;
  final List<WindowSummary> windows;
  final bool busy;
  final Future<void> Function() onRefresh;
  final Future<void> Function(AppSettings settings) onSave;
  final Future<void> Function(AppSettings settings) onCapture;
  final Future<void> Function() onQuit;
  final ValueChanged<bool> onRecordingChanged;

  /// Reads a tweet URL from the clipboard and returns the status id.
  final Future<String?> Function() onUpdateReplyTarget;

  /// Changes when the reply target was updated outside this form.
  final int replyEpoch;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _hashtagController;
  late final TextEditingController _textController;
  late final TextEditingController _folderController;
  late final TextEditingController _replyController;
  late String _processExe;
  late HotkeyConfig _hotkey;
  late HotkeyConfig _finishHotkey;
  late bool _launchAtStartup;
  late bool _continueThread;
  late bool _batchMode;

  @override
  void initState() {
    super.initState();
    final settings = widget.settings;
    _processExe = settings.targetProcessExe;
    _hotkey = settings.hotkey;
    _finishHotkey = settings.finishHotkey;
    _launchAtStartup = settings.launchAtStartup;
    _continueThread = settings.continueThread;
    _batchMode = settings.batchMode;
    _replyController = TextEditingController(text: settings.replyTweet);
    _titleController = TextEditingController(
      text: settings.targetTitleSubstring,
    );
    _hashtagController = TextEditingController(
      text: formatHashtags(settings.hashtags),
    );
    _textController = TextEditingController(text: settings.fixedText);
    _folderController = TextEditingController(text: settings.saveFolder);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _hashtagController.dispose();
    _textController.dispose();
    _folderController.dispose();
    _replyController.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(SettingsPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.replyEpoch == oldWidget.replyEpoch) return;
    final next = widget.settings.replyTweet;
    if (_replyController.text == next) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _replyController.text == widget.settings.replyTweet) {
        return;
      }
      setState(() => _replyController.text = widget.settings.replyTweet);
    });
  }

  AppSettings _draft() {
    return AppSettings(
      targetProcessExe: _processExe,
      targetTitleSubstring: _titleController.text.trim(),
      hotkey: _hotkey,
      hashtags: normalizeHashtags(_hashtagController.text),
      fixedText: _textController.text.trim(),
      saveFolder: _folderController.text.trim(),
      launchAtStartup: _launchAtStartup,
      replyTweet: _replyController.text.trim(),
      continueThread: _continueThread,
      finishHotkey: _finishHotkey,
      batchMode: _batchMode,
    );
  }

  String get _replyValidation {
    final text = _replyController.text.trim();
    if (text.isEmpty) return '未設定';
    final id = parseStatusId(text);
    if (id == null) return 'URL または数値の id として読めません';
    return 'status id: $id';
  }

  Future<void> _updateReplyTarget() async {
    final id = await widget.onUpdateReplyTarget();
    if (!mounted) return;
    final message = id == null
        ? 'クリップボードからツイート URL を読めませんでした'
        : 'つなげる先を $id に更新しました';
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _save() async {
    final draft = _draft();
    _hashtagController.text = formatHashtags(draft.hashtags);
    try {
      await widget.onSave(draft);
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('保存しました')));
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('保存に失敗しました')));
    }
  }

  Future<void> _capture() async {
    final draft = _draft();
    _hashtagController.text = formatHashtags(draft.hashtags);
    try {
      await widget.onCapture(draft);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('撮影に失敗しました')));
    }
  }

  void _selectWindow(WindowSummary window) {
    final sameExe = widget.windows
        .where(
          (item) =>
              item.processExe.toLowerCase() == window.processExe.toLowerCase(),
        )
        .length;
    setState(() {
      _processExe = window.processExe;
      _titleController.text = sameExe > 1 ? window.title : '';
    });
  }

  bool _isSelected(WindowSummary window) {
    if (_processExe.isEmpty) return false;
    if (window.processExe.toLowerCase() != _processExe.toLowerCase()) {
      return false;
    }
    final part = _titleController.text.trim().toLowerCase();
    if (part.isEmpty) return true;
    return window.title.toLowerCase().contains(part);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final preview = formatHashtags(normalizeHashtags(_hashtagController.text));
    return Scaffold(
      appBar: AppBar(title: const Text('SnapPost')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
          Text(
            '選んだアプリのウィンドウだけを撮影し、画像をクリップボードに入れて X の投稿画面を開きます。',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'ウィンドウを閉じても終了せず、通知領域に残ります。終了は下のボタンかトレイの「終了」です。',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Text('対象ウィンドウ', style: theme.textTheme.titleMedium),
              const Spacer(),
              TextButton.icon(
                onPressed: widget.busy ? null : () => widget.onRefresh(),
                icon: const Icon(Icons.refresh),
                label: const Text('更新'),
              ),
            ],
          ),
          Text(
            _processExe.isEmpty ? '選択中: なし' : '選択中: $_processExe',
            style: theme.textTheme.bodyMedium,
          ),
          const SizedBox(height: 8),
          DecoratedBox(
            decoration: BoxDecoration(
              border: Border.all(color: theme.colorScheme.outlineVariant),
              borderRadius: BorderRadius.circular(8),
            ),
            child: SizedBox(
              height: 220,
              child: widget.windows.isEmpty
                  ? const Center(child: Text('表示できるウィンドウがありません'))
                  : ListView.builder(
                      itemCount: widget.windows.length,
                      itemBuilder: (context, index) {
                        final window = widget.windows[index];
                        final selected = _isSelected(window);
                        return ListTile(
                          selected: selected,
                          dense: true,
                          title: Text(
                            window.title,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          subtitle: Text(window.processExe),
                          trailing: selected
                              ? const Icon(Icons.check_circle, size: 18)
                              : null,
                          onTap: widget.busy
                              ? null
                              : () => _selectWindow(window),
                        );
                      },
                    ),
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(
              labelText: 'タイトルの部分一致（任意）',
              helperText: '同じ実行ファイルのウィンドウが複数あるときに使います',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 24),
          Text('ショートカットキー', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          const Text('撮影'),
          const SizedBox(height: 4),
          _HotkeyButton(
            hotkey: _hotkey,
            onChanged: (hotkey) => setState(() => _hotkey = hotkey),
            onRecording: widget.onRecordingChanged,
          ),
          const SizedBox(height: 8),
          const Text('まとめて投稿'),
          const SizedBox(height: 4),
          _HotkeyButton(
            hotkey: _finishHotkey,
            onChanged: (hotkey) => setState(() => _finishHotkey = hotkey),
            onRecording: widget.onRecordingChanged,
          ),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('まとめて投稿する（最大4枚）'),
            subtitle: const Text('オンのときは撮影でたまり、まとめて投稿で一度に開きます。4枚目で自動的に投稿します。'),
            value: _batchMode,
            onChanged: widget.busy
                ? null
                : (value) => setState(() => _batchMode = value),
          ),
          const SizedBox(height: 24),
          Text('投稿', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _hashtagController,
            decoration: const InputDecoration(
              labelText: 'ハッシュタグ',
              helperText: 'スペースまたはカンマ区切り。# は付けても付けなくても構いません',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Text(
            preview.isEmpty ? '正規化: （なし）' : '正規化: $preview',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _textController,
            minLines: 2,
            maxLines: 4,
            decoration: const InputDecoration(
              labelText: '固定テキスト（任意）',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'X の投稿画面は画像を自動では添付できません。開いたら Ctrl+V で貼り付けてください。',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          Text('つなげるツイート', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _replyController,
            decoration: const InputDecoration(
              labelText: 'ツイート URL または status id',
              helperText: 'x.com / twitter.com の /status/数字、または数字だけ。クエリは無視します',
              border: OutlineInputBorder(),
            ),
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 8),
          Text(_replyValidation, style: theme.textTheme.bodySmall),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('ツリーにつなげる'),
            subtitle: const Text('オンのとき、投稿画面を in_reply_to 付きで開きます'),
            value: _continueThread,
            onChanged: widget.busy
                ? null
                : (value) => setState(() => _continueThread = value),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton(
              onPressed: widget.busy ? null : _updateReplyTarget,
              child: const Text('つなげる先を更新'),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '投稿したあとにそのツイートのリンクをコピーし、このボタンかトレイの「つなげる先を更新」で次の返信先にします。',
            style: theme.textTheme.bodySmall,
          ),
          const SizedBox(height: 24),
          Text('保存', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          TextField(
            controller: _folderController,
            decoration: const InputDecoration(
              labelText: '保存フォルダ',
              helperText: r'空欄のときは %USERPROFILE%\Pictures\SnapPost',
              border: OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          SwitchListTile(
            contentPadding: EdgeInsets.zero,
            title: const Text('Windowsの起動時に自動で起動する'),
            value: _launchAtStartup,
            onChanged: widget.busy
                ? null
                : (value) => setState(() => _launchAtStartup = value),
          ),
          const SizedBox(height: 16),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              FilledButton(
                onPressed: widget.busy ? null : _save,
                child: const Text('保存'),
              ),
              FilledButton.tonal(
                onPressed: widget.busy ? null : _capture,
                child: const Text('今すぐ撮る'),
              ),
              OutlinedButton(
                onPressed: widget.busy ? null : () => widget.onQuit(),
                child: const Text('終了'),
              ),
            ],
          ),
          if (widget.busy) ...[
            const SizedBox(height: 16),
            const LinearProgressIndicator(),
          ],
        ],
      ),
    );
  }
}

class _HotkeyButton extends StatefulWidget {
  const _HotkeyButton({
    required this.hotkey,
    required this.onChanged,
    required this.onRecording,
  });

  final HotkeyConfig hotkey;
  final ValueChanged<HotkeyConfig> onChanged;
  final ValueChanged<bool> onRecording;

  @override
  State<_HotkeyButton> createState() => _HotkeyButtonState();
}

class _HotkeyButtonState extends State<_HotkeyButton> {
  final FocusNode _focusNode = FocusNode();
  var _recording = false;

  @override
  void dispose() {
    if (_recording) {
      HardwareKeyboard.instance.removeHandler(_onKey);
    }
    _focusNode.dispose();
    super.dispose();
  }

  void _begin() {
    if (_recording) return;
    setState(() => _recording = true);
    HardwareKeyboard.instance.addHandler(_onKey);
    widget.onRecording(true);
    _focusNode.requestFocus();
  }

  void _end() {
    if (!_recording) return;
    HardwareKeyboard.instance.removeHandler(_onKey);
    widget.onRecording(false);
    if (mounted) setState(() => _recording = false);
  }

  bool _onKey(KeyEvent event) {
    if (!_recording || event is! KeyDownEvent) return _recording;
    final key = event.logicalKey;
    if (key == LogicalKeyboardKey.escape) {
      _end();
      return true;
    }
    if (_isModifier(key)) return true;
    final keyboard = HardwareKeyboard.instance;
    widget.onChanged(
      HotkeyConfig(
        keyId: key.keyId,
        control: keyboard.isControlPressed,
        shift: keyboard.isShiftPressed,
        alt: keyboard.isAltPressed,
        meta: keyboard.isMetaPressed,
      ),
    );
    _end();
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final label = _recording
        ? 'キーを押してください（Esc で取消）'
        : describeHotkey(widget.hotkey);
    return Focus(
      focusNode: _focusNode,
      child: OutlinedButton.icon(
        onPressed: _recording ? null : _begin,
        icon: const Icon(Icons.keyboard),
        label: Text(label),
      ),
    );
  }
}

String describeHotkey(HotkeyConfig config) {
  final key = LogicalKeyboardKey.findKeyByKeyId(config.keyId);
  final parts = <String>[
    if (config.control) 'Ctrl',
    if (config.shift) 'Shift',
    if (config.alt) 'Alt',
    if (config.meta) 'Win',
    key?.keyLabel ?? '?',
  ];
  return parts.join('+');
}

bool _isModifier(LogicalKeyboardKey key) {
  return key == LogicalKeyboardKey.control ||
      key == LogicalKeyboardKey.controlLeft ||
      key == LogicalKeyboardKey.controlRight ||
      key == LogicalKeyboardKey.shift ||
      key == LogicalKeyboardKey.shiftLeft ||
      key == LogicalKeyboardKey.shiftRight ||
      key == LogicalKeyboardKey.alt ||
      key == LogicalKeyboardKey.altLeft ||
      key == LogicalKeyboardKey.altRight ||
      key == LogicalKeyboardKey.meta ||
      key == LogicalKeyboardKey.metaLeft ||
      key == LogicalKeyboardKey.metaRight ||
      key == LogicalKeyboardKey.capsLock ||
      key == LogicalKeyboardKey.fn;
}
