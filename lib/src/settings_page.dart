import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'hashtags.dart';
import 'window_match.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    required this.settings,
    required this.windows,
    required this.busy,
    required this.onRefresh,
    required this.onSave,
    required this.onBack,
    super.key,
  });

  final AppSettings settings;
  final List<WindowSummary> windows;
  final bool busy;
  final Future<void> Function() onRefresh;
  final Future<void> Function(AppSettings settings) onSave;
  final VoidCallback onBack;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final TextEditingController _titleController;
  late final TextEditingController _hashtagController;
  late final TextEditingController _textController;
  late final TextEditingController _folderController;
  late String _processExe;
  late bool _launchAtStartup;

  @override
  void initState() {
    super.initState();
    final settings = widget.settings;
    _processExe = settings.targetProcessExe;
    _launchAtStartup = settings.launchAtStartup;
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
    super.dispose();
  }

  AppSettings _draft() {
    return AppSettings(
      targetProcessExe: _processExe,
      targetTitleSubstring: _titleController.text.trim(),
      hashtags: normalizeHashtags(_hashtagController.text),
      fixedText: _textController.text.trim(),
      saveFolder: _folderController.text.trim(),
      launchAtStartup: _launchAtStartup,
      replyTweet: widget.settings.replyTweet,
    );
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
      appBar: AppBar(
        leading: IconButton(
          tooltip: '戻る',
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        title: const Text('設定'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
        children: [
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
          Text('投稿文', style: theme.textTheme.titleMedium),
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
          Align(
            alignment: Alignment.centerLeft,
            child: FilledButton(
              onPressed: widget.busy ? null : _save,
              child: const Text('保存'),
            ),
          ),
        ],
      ),
    );
  }
}
