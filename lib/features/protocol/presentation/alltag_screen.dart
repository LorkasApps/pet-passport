import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../../../core/widgets/empty_state.dart';

class AlltagScreen extends ConsumerWidget {
  const AlltagScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    return EmptyState(
      icon: Icons.article_outlined,
      title: l.alltagEmptyTitle,
      message: l.alltagEmptyMessage,
    );
  }
}
