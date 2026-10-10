import 'dart:io';

import 'package:flutter/material.dart';

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
    required this.onClear,
    required this.onPost,
    required this.onContinueThread,
    required this.onUpdateReply,
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
  final VoidCallback onClear;
  final VoidCallback onPost;
  final ValueChanged<bool> onContinueThread;
  final VoidCallback onUpdateReply;

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
            _ReplyBar(
              settings: settings,
              busy: busy,
              onContinueThread: onContinueThread,
              onUpdateReply: onUpdateReply,
            ),
            const SizedBox(height: 8),
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
            FilledButton(
              onPressed: busy || selected == 0 ? null : onPost,
              child: const Text('投稿画面を開く'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: busy || shots.isEmpty ? null : onClear,
              child: const Text('全部消す'),
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

class _ReplyBar extends StatelessWidget {
  const _ReplyBar({
    required this.settings,
    required this.busy,
    required this.onContinueThread,
    required this.onUpdateReply,
  });

  final AppSettings settings;
  final bool busy;
  final ValueChanged<bool> onContinueThread;
  final VoidCallback onUpdateReply;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = displayReplyTarget(settings.replyTweet);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(color: theme.colorScheme.outlineVariant),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('つなげる先', style: theme.textTheme.titleSmall),
            const SizedBox(height: 4),
            Text(
              label,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium,
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('ツリーにつなげる'),
              value: settings.continueThread,
              onChanged: busy ? null : onContinueThread,
            ),
            OutlinedButton(
              onPressed: busy ? null : onUpdateReply,
              child: const Text('クリップボードから更新'),
            ),
          ],
        ),
      ),
    );
  }
}
