import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:pet_passport/l10n/generated/app_l10n.dart';

import '../../../core/widgets/empty_state.dart';
import '../../pets/application/current_pet_provider.dart';
import '../application/foods_providers.dart';
import '../domain/food.dart';
import '../domain/food_enums.dart';

class DietListScreen extends ConsumerWidget {
  const DietListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l = AppL10n.of(context);
    final petAsync = ref.watch(currentPetProvider);
    return Scaffold(
      appBar: AppBar(title: Text(l.dietListTitle)),
      body: petAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('$e')),
        data: (pet) {
          if (pet == null) {
            return EmptyState(
              icon: Icons.pets_outlined,
              title: l.petsListEmpty,
            );
          }
          final listAsync = ref.watch(foodsForPetProvider(pet.uuid));
          return listAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('$e')),
            data: (list) {
              if (list.isEmpty) {
                return EmptyState(
                  icon: Icons.restaurant_outlined,
                  title: l.dietEmptyTitle,
                  message: l.dietEmptyMessage,
                );
              }
              final active = list.where((f) => f.isActive).toList();
              final inactive = list.where((f) => !f.isActive).toList();
              return ListView(
                children: [
                  if (active.isNotEmpty) ...[
                    _SectionHeader(text: l.dietActiveSection),
                    for (final f in active)
                      _FoodTile(food: f, petUuid: pet.uuid),
                  ],
                  if (inactive.isNotEmpty) ...[
                    _SectionHeader(text: l.dietInactiveSection),
                    for (final f in inactive)
                      _FoodTile(food: f, petUuid: pet.uuid),
                  ],
                ],
              );
            },
          );
        },
      ),
      floatingActionButton: petAsync.valueOrNull == null
          ? null
          : FloatingActionButton(
              onPressed: () =>
                  context.push('/pets/${petAsync.value!.uuid}/diet/new'),
              child: const Icon(Icons.add),
            ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 4),
      child: Text(
        text,
        style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: Theme.of(context).colorScheme.primary,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _FoodTile extends StatelessWidget {
  const _FoodTile({required this.food, required this.petUuid});
  final Food food;
  final String petUuid;

  @override
  Widget build(BuildContext context) {
    final l = AppL10n.of(context);
    final head = food.brand.isEmpty ? food.name : '${food.brand} · ${food.name}';
    final parts = <String>[
      _foodTypeLabel(l, food.foodType),
      if (food.timesOfDay.isNotEmpty) food.timesOfDay.join(' • '),
      if (food.remindersEnabled) l.foodRemindersOnChip,
    ];
    return ListTile(
      leading: const CircleAvatar(child: Icon(Icons.restaurant_outlined)),
      title: Text(head),
      subtitle: Text(parts.join('  ·  ')),
      trailing: const Icon(Icons.chevron_right),
      onTap: () =>
          context.push('/pets/$petUuid/diet/${food.uuid}/edit'),
    );
  }

  String _foodTypeLabel(AppL10n l, FoodType t) {
    switch (t) {
      case FoodType.dry:
        return l.foodTypeDry;
      case FoodType.wet:
        return l.foodTypeWet;
      case FoodType.raw:
        return l.foodTypeRaw;
      case FoodType.barf:
        return l.foodTypeBarf;
      case FoodType.treat:
        return l.foodTypeTreat;
      case FoodType.other:
        return l.foodTypeOther;
    }
  }
}
