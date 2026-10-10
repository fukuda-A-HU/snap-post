import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher_string.dart';

import 'app_settings.dart';
import 'reply_target.dart';
import 'shot_list.dart';

class HomePage extends StatelessWidget {
  const HomePage({
    required this.settings,
    required this.shots,
    required this.busy,
    required this.captureError,
    required this.onCapture,
    required this.onOpenSettings,
    required this.onToggle,
    required this.onDelete,
    required this.onPost,
    required this.onReplyDraft,
    required this.onReplyCommit,
    required this.onReadClipboard,
    super.key,
  });

  final AppSettings settings;
  final ShotList shots;
  final bool busy;
  final String? captureError;
  final VoidCallback onCapture;
  final VoidCallback onOpenSettings;
  final void Function(int index, bool selected) onToggle;
  final ValueChanged<int> onDelete;
  final VoidCallback onPost;
  final ValueChanged<String> onReplyDraft;
  final ValueChanged<String> onReplyCommit;
  final Future<String?> Function() onReadClipboard;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final selected = shots.selectedCount;
    return Scaffold(
      appBar: AppBar(
        title: const Text('SnapPost'),
        actions: [
          IconButton(
            tooltip: '設定',
            onPressed: onOpenSettings,
            icon: const Icon(Icons.settings),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SizedBox(
              height: 72,
              child: FilledButton.icon(
                onPressed: busy ? null : onCapture,
                icon: const Icon(Icons.photo_camera, size: 32),
                label: const Text('撮影', style: TextStyle(fontSize: 24)),
              ),
            ),
            if (captureError != null) ...[
              const SizedBox(height: 8),
              Text(
                captureError!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.error,
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: onOpenSettings,
                  child: const Text('ウィンドウを選ぶ'),
                ),
              ),
            ],
            const SizedBox(height: 12),
            Text('選択中 $selected/4', style: theme.textTheme.titleMedium),
            if (shots.selectionFull)
              Text(
                '投稿に使えるのは4枚までです。ほかを選ぶには、どれかのチェックを外してください。',
                style: theme.textTheme.bodySmall,
              ),
            const SizedBox(height: 8),
            Expanded(
              child: shots.isEmpty
                  ? const Center(child: Text('撮影した画像がここに並びます'))
                  : GridView.builder(
                      gridDelegate:
                          const SliverGridDelegateWithMaxCrossAxisExtent(
                            maxCrossAxisExtent: 280,
                            mainAxisExtent: 248,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      itemCount: shots.length,
                      itemBuilder: (context, index) {
                        final shot = shots.shots[index];
                        final canCheck = shot.selected || !shots.selectionFull;
                        return _ShotCard(
                          shot: shot,
                          enabled: canCheck && !busy,
                          onOpen: () => _openFull(context, shot.path),
                          onToggle: (value) => onToggle(index, value),
                          onDelete: () => onDelete(index),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            ThreadSection(
              savedReply: settings.replyTweet,
              busy: busy,
              onDraft: onReplyDraft,
              onCommit: onReplyCommit,
              onReadClipboard: onReadClipboard,
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: busy || selected == 0 ? null : onPost,
              child: const Text('投稿画面を開く'),
            ),
          ],
        ),
      ),
    );
  }

  void _openFull(BuildContext context, String filePath) {
    showDialog<void>(
      context: context,
      builder: (context) => Dialog(
        child: InteractiveViewer(
          child: Image.file(File(filePath), fit: BoxFit.contain),
        ),
      ),
    );
  }
}

class _ShotCard extends StatelessWidget {
  const _ShotCard({
    required this.shot,
    required this.enabled,
    required this.onOpen,
    required this.onToggle,
    required this.onDelete,
  });

  final Shot shot;
  final bool enabled;
  final VoidCallback onOpen;
  final ValueChanged<bool> onToggle;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: InkWell(
              onTap: onOpen,
              child: Image.file(
                File(shot.path),
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) =>
                    const Center(child: Icon(Icons.broken_image)),
              ),
            ),
          ),
          CheckboxListTile(
            dense: true,
            contentPadding: const EdgeInsets.only(left: 8),
            title: const Text('投稿に使う'),
            value: shot.selected,
            onChanged: enabled ? (value) => onToggle(value ?? false) : null,
          ),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton.icon(
              onPressed: onDelete,
              icon: const Icon(Icons.delete_outline),
              label: const Text('削除'),
            ),
          ),
        ],
      ),
    );
  }
}

class ThreadSection extends StatefulWidget {
  const ThreadSection({
    required this.savedReply,
    required this.busy,
    required this.onDraft,
    required this.onCommit,
    required this.onReadClipboard,
    super.key,
  });

  final String savedReply;
  final bool busy;
  final ValueChanged<String> onDraft;
  final ValueChanged<String> onCommit;
  final Future<String?> Function() onReadClipboard;

  @override
  State<ThreadSection> createState() => _ThreadSectionState();
}

class _ThreadSectionState extends State<ThreadSection> {
  late final TextEditingController _controller;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(text: widget.savedReply);
    widget.onDraft(_controller.text);
  }

  @override
  void didUpdateWidget(ThreadSection oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.savedReply != oldWidget.savedReply &&
        widget.savedReply != _controller.text.trim()) {
      _controller.text = widget.savedReply;
      widget.onDraft(_controller.text);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _publish(String value) {
    widget.onDraft(value);
    final trimmed = value.trim();
    if (trimmed.isEmpty || parseStatusId(trimmed) != null) {
      widget.onCommit(trimmed);
    }
  }

  Future<void> _paste() async {
    final text = await widget.onReadClipboard();
    if (!mounted) return;
    final value = text?.trim() ?? '';
    _controller.text = value;
    setState(() {});
    _publish(value);
  }

  Future<void> _open() async {
    final shown = displayReplyTarget(_controller.text);
    final uri = Uri.tryParse(shown);
    if (uri == null || !uri.hasScheme) return;
    await launchUrlString(uri.toString(), mode: LaunchMode.externalApplication);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final status = replyFieldStatus(_controller.text);
    final canOpen = parseStatusId(_controller.text) != null;
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('ツリーにつなげる', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            TextField(
              controller: _controller,
              enabled: !widget.busy,
              decoration: const InputDecoration(
                labelText: 'ツイート URL または id',
                border: OutlineInputBorder(),
                isDense: true,
              ),
              onChanged: (value) {
                setState(() {});
                _publish(value);
              },
            ),
            const SizedBox(height: 6),
            Text(status, style: theme.textTheme.bodySmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton(
                  onPressed: widget.busy ? null : _paste,
                  child: const Text('クリップボードから貼り付け'),
                ),
                OutlinedButton(
                  onPressed: widget.busy
                      ? null
                      : () {
                          _controller.clear();
                          setState(() {});
                          _publish('');
                        },
                  child: const Text('クリア'),
                ),
                TextButton(
                  onPressed: widget.busy || !canOpen ? null : _open,
                  child: const Text('開く'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
