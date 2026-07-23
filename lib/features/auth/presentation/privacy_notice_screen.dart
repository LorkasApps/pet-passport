import 'package:flutter/material.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../data/privacy_notice_content.dart';

/// Read-only renderer for the bundled German privacy notice.
///
/// The source string lives in [kPrivacyNoticeDe]; sections are split on
/// `---` and each section leads with `## <title>` followed by body
/// paragraphs. We keep the rendering intentionally dumb (no full
/// Markdown lib) — the format is a stable in-repo constant, not user
/// input.
class PrivacyNoticeScreen extends StatelessWidget {
  const PrivacyNoticeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final sections = _splitSections(kPrivacyNoticeDe);
    return Scaffold(
      appBar: AppBar(title: Text(l.privacyNoticeTitle)),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: sections.length,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, i) => _SectionCard(section: sections[i]),
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({required this.section});

  final _Section section;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(section.title, style: theme.textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final para in section.paragraphs) ...[
              _RichParagraph(text: para),
              if (para != section.paragraphs.last)
                const SizedBox(height: 8),
            ],
          ],
        ),
      ),
    );
  }
}

/// Renders one paragraph, converting `**bold**` spans to bold weight.
/// The privacy notice uses this sparingly for lead-ins ("Lokal auf
/// deinem Gerät (immer):") — nothing more elaborate is needed.
class _RichParagraph extends StatelessWidget {
  const _RichParagraph({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.bodyMedium;
    final spans = <TextSpan>[];
    final re = RegExp(r'\*\*(.+?)\*\*');
    int cursor = 0;
    for (final m in re.allMatches(text)) {
      if (m.start > cursor) {
        spans.add(TextSpan(text: text.substring(cursor, m.start)));
      }
      spans.add(TextSpan(
        text: m.group(1),
        style: const TextStyle(fontWeight: FontWeight.bold),
      ));
      cursor = m.end;
    }
    if (cursor < text.length) {
      spans.add(TextSpan(text: text.substring(cursor)));
    }
    return RichText(
      text: TextSpan(style: base, children: spans),
    );
  }
}

class _Section {
  const _Section({required this.title, required this.paragraphs});

  final String title;
  final List<String> paragraphs;
}

List<_Section> _splitSections(String raw) {
  return raw
      .split('---')
      .map((chunk) => chunk.trim())
      .where((c) => c.isNotEmpty)
      .map(_parseSection)
      .toList(growable: false);
}

_Section _parseSection(String chunk) {
  final lines = chunk.split('\n');
  String title = '';
  final bodyLines = <String>[];
  for (final line in lines) {
    if (title.isEmpty && line.startsWith('## ')) {
      title = line.substring(3).trim();
    } else {
      bodyLines.add(line);
    }
  }
  final body = bodyLines.join('\n').trim();
  final paragraphs = body
      .split(RegExp(r'\n\s*\n'))
      .map((p) => p.replaceAll('\n', ' ').trim())
      .where((p) => p.isNotEmpty)
      .toList(growable: false);
  return _Section(title: title, paragraphs: paragraphs);
}
