import 'package:flutter/material.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

/// Shared rename dialog for photo / document attachments. Returns:
///   - `null` if the user dismissed the dialog (unchanged)
///   - the trimmed non-empty title on save
///   - an empty string to signal "clear the title"
///
/// The subtitle (usually the original filename) is shown read-only below
/// the input so the user can tell which file they're renaming.
Future<String?> showAttachmentRenameDialog({
  required BuildContext context,
  required String? initialTitle,
  String? subtitle,
}) async {
  final l = AppL10n.of(context);
  final ctrl = TextEditingController(text: initialTitle ?? '');
  final result = await showDialog<String?>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(l.attachmentRenameTitle),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: ctrl,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: InputDecoration(hintText: l.attachmentRenameHint),
            onSubmitted: (_) => Navigator.pop(ctx, ctrl.text),
          ),
          if (subtitle != null && subtitle.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              subtitle,
              style: TextStyle(
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
                fontSize: 12,
              ),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx),
          child: Text(l.actionCancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(ctx, ctrl.text),
          child: Text(l.actionSave),
        ),
      ],
    ),
  );
  ctrl.dispose();
  return result;
}
