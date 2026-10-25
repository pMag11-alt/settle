import 'package:flutter/material.dart';

import '../domain/model.dart';
import '../domain/money.dart';

const avatarColors = [
  Color(0xFF0F766E),
  Color(0xFFB45309),
  Color(0xFF7C3AED),
  Color(0xFFBE123C),
  Color(0xFF1D4ED8),
  Color(0xFF4D7C0F),
  Color(0xFFC2410C),
  Color(0xFF0E7490),
];

Color memberColor(Member m) => avatarColors[m.color % avatarColors.length];

class MemberAvatar extends StatelessWidget {
  const MemberAvatar(this.member, {super.key, this.radius = 18});

  final Member member;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final initials = member.name.trim().isEmpty
        ? '?'
        : member.name.trim().split(RegExp(r'\s+')).take(2).map((w) => w.characters.first.toUpperCase()).join();
    return CircleAvatar(
      radius: radius,
      backgroundColor: memberColor(member),
      child: Text(
        initials,
        style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600, fontSize: radius * 0.8),
      ),
    );
  }
}

IconData categoryIcon(Category c) => switch (c) {
  Category.food => Icons.restaurant,
  Category.groceries => Icons.shopping_basket_outlined,
  Category.travel => Icons.flight_takeoff,
  Category.stay => Icons.hotel_outlined,
  Category.rent => Icons.receipt_long_outlined,
  Category.fun => Icons.celebration_outlined,
  Category.shopping => Icons.shopping_bag_outlined,
  Category.other => Icons.more_horiz,
};

Color categoryColor(Category c) => switch (c) {
  Category.food => const Color(0xFFE76F51),
  Category.groceries => const Color(0xFF6A994E),
  Category.travel => const Color(0xFF3A86FF),
  Category.stay => const Color(0xFF8338EC),
  Category.rent => const Color(0xFF6C757D),
  Category.fun => const Color(0xFFFF006E),
  Category.shopping => const Color(0xFFFFB703),
  Category.other => const Color(0xFF8D99AE),
};

/// Positive amounts in green, negative in red, zero muted.
class BalanceText extends StatelessWidget {
  const BalanceText(this.amount, this.currency, {super.key, this.style});

  final int amount;
  final Currency currency;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final color = amount > 0
        ? positiveColor(context)
        : amount < 0
        ? scheme.error
        : scheme.onSurfaceVariant;
    return Text(
      amount == 0 ? 'settled' : currency.format(amount.abs()),
      style: (style ?? Theme.of(context).textTheme.titleSmall)!.copyWith(color: color, fontWeight: FontWeight.w600),
    );
  }
}

Color positiveColor(BuildContext context) =>
    Theme.of(context).brightness == Brightness.dark ? const Color(0xFF4ADE80) : const Color(0xFF15803D);

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.actions = const [],
  });

  final IconData icon;
  final String title;
  final String message;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 56, color: theme.colorScheme.primary),
            const SizedBox(height: 16),
            Text(title, style: theme.textTheme.titleLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              message,
              style: theme.textTheme.bodyMedium?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              textAlign: TextAlign.center,
            ),
            if (actions.isNotEmpty) ...[
              const SizedBox(height: 24),
              Wrap(spacing: 12, runSpacing: 12, alignment: WrapAlignment.center, children: actions),
            ],
          ],
        ),
      ),
    );
  }
}

/// A titled card section used across the group tabs.
class Section extends StatelessWidget {
  const Section({super.key, required this.title, required this.child, this.trailing});

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 8),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: Text(title, style: Theme.of(context).textTheme.titleMedium)),
                ?trailing,
              ],
            ),
            const SizedBox(height: 8),
            child,
          ],
        ),
      ),
    );
  }
}
