import 'dart:io';

import 'package:flutter/material.dart';
import 'package:path/path.dart' as path;

class PendingPage extends StatelessWidget {
  const PendingPage({
    required this.paths,
    required this.busy,
    required this.onRemove,
    required this.onClear,
    required this.onPost,
    required this.onBack,
    super.key,
  });

  final List<String> paths;
  final bool busy;
  final ValueChanged<int> onRemove;
  final VoidCallback onClear;
  final VoidCallback onPost;
  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('投稿待ち')),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('${paths.length}/4枚', style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            Expanded(
              child: paths.isEmpty
                  ? const Center(child: Text('投稿待ちの画像はありません'))
                  : ListView.separated(
                      itemCount: paths.length,
                      separatorBuilder: (context, index) =>
                          const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final filePath = paths[index];
                        return Row(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: Image.file(
                                File(filePath),
                                width: 96,
                                height: 72,
                                fit: BoxFit.cover,
                                errorBuilder: (context, error, stackTrace) =>
                                    const SizedBox(
                                      width: 96,
                                      height: 72,
                                      child: ColoredBox(
                                        color: Color(0xFFE5E7EB),
                                        child: Icon(Icons.broken_image),
                                      ),
                                    ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Text(
                                '${index + 1}. ${path.basename(filePath)}',
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            IconButton(
                              tooltip: '外す',
                              onPressed: busy ? null : () => onRemove(index),
                              icon: const Icon(Icons.close),
                            ),
                          ],
                        );
                      },
                    ),
            ),
            const SizedBox(height: 12),
            FilledButton(
              onPressed: busy || paths.isEmpty ? null : onPost,
              child: const Text('投稿画面を開く'),
            ),
            const SizedBox(height: 8),
            OutlinedButton(
              onPressed: busy || paths.isEmpty ? null : onClear,
              child: const Text('全部消す'),
            ),
            TextButton(
              onPressed: busy ? null : onBack,
              child: const Text('設定に戻る'),
            ),
          ],
        ),
      ),
    );
  }
}
