import 'package:flutter/material.dart';
import '../core/app_theme.dart';
import '../models/item_model.dart';
import '../models/outlet_model.dart';

class ProCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Gradient? gradient;
  final Color? color;
  const ProCard({super.key, required this.child, this.padding = const EdgeInsets.all(16), this.gradient, this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color ?? Colors.white,
        gradient: gradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: const Color(0xFFE2E8F0)),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(.04), blurRadius: 16, offset: const Offset(0, 8))],
      ),
      child: child,
    );
  }
}

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final s = status.toUpperCase();
    final color = s == 'CONFIRMED'
        ? AppColors.success
        : s == 'UNCHECKED'
            ? AppColors.accent
            : s == 'DRAFT'
                ? AppColors.secondary
                : AppColors.muted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(color: color.withOpacity(.12), borderRadius: BorderRadius.circular(999), border: Border.all(color: color.withOpacity(.35))),
      child: Text(s, style: TextStyle(color: color, fontWeight: FontWeight.w900, fontSize: 11)),
    );
  }
}

class ProInfoTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final Color color;
  const ProInfoTile({super.key, required this.icon, required this.title, required this.value, required this.color});

  @override
  Widget build(BuildContext context) {
    return ProCard(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            decoration: BoxDecoration(color: color.withOpacity(.14), borderRadius: BorderRadius.circular(16)),
            child: Icon(icon, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(title, style: const TextStyle(color: AppColors.muted, fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text(value, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(color: AppColors.text, fontSize: 18, fontWeight: FontWeight.w900)),
            ]),
          ),
        ],
      ),
    );
  }
}

class SectionTitle extends StatelessWidget {
  final String title;
  final String? subtitle;
  const SectionTitle(this.title, {super.key, this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10, top: 6),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: AppColors.text)),
        if (subtitle != null) ...[
          const SizedBox(height: 2),
          Text(subtitle!, style: const TextStyle(fontSize: 12, color: AppColors.muted, fontWeight: FontWeight.w600)),
        ],
      ]),
    );
  }
}

class SearchableSelect<T> extends StatelessWidget {
  final String label;
  final String hint;
  final T? value;
  final List<T> items;
  final String Function(T) titleBuilder;
  final String Function(T)? subtitleBuilder;
  final ValueChanged<T> onChanged;
  final IconData icon;

  const SearchableSelect({
    super.key,
    required this.label,
    required this.hint,
    required this.value,
    required this.items,
    required this.titleBuilder,
    required this.onChanged,
    this.subtitleBuilder,
    this.icon = Icons.search,
  });

  @override
  Widget build(BuildContext context) {
    final text = value == null ? hint : titleBuilder(value as T);
    return InkWell(
      onTap: () => _showPicker(context),
      borderRadius: BorderRadius.circular(16),
      child: InputDecorator(
        decoration: InputDecoration(labelText: label, prefixIcon: Icon(icon), suffixIcon: const Icon(Icons.keyboard_arrow_down_rounded)),
        child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: value == null ? AppColors.muted : AppColors.text, fontWeight: FontWeight.w700)),
      ),
    );
  }

  void _showPicker(BuildContext context) {
    final controller = TextEditingController();
    List<T> filtered = List<T>.from(items);
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Container(
          height: MediaQuery.of(ctx).size.height * .78,
          decoration: const BoxDecoration(color: AppColors.bg, borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
          padding: EdgeInsets.only(left: 16, right: 16, top: 16, bottom: MediaQuery.of(ctx).viewInsets.bottom + 16),
          child: Column(
            children: [
              Container(width: 48, height: 5, decoration: BoxDecoration(color: const Color(0xFFCBD5E1), borderRadius: BorderRadius.circular(99))),
              const SizedBox(height: 14),
              Text(label, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(prefixIcon: const Icon(Icons.search), hintText: 'Type and search $label'),
                onChanged: (q) {
                  final s = q.toLowerCase().trim();
                  setState(() {
                    filtered = items.where((e) {
                      final title = titleBuilder(e).toLowerCase();
                      final sub = (subtitleBuilder?.call(e) ?? '').toLowerCase();
                      return title.contains(s) || sub.contains(s);
                    }).toList();
                  });
                },
              ),
              const SizedBox(height: 10),
              Expanded(
                child: ListView.separated(
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final item = filtered[i];
                    return ListTile(
                      leading: CircleAvatar(backgroundColor: AppColors.primary.withOpacity(.12), child: Icon(icon, color: AppColors.primary)),
                      title: Text(titleBuilder(item), style: const TextStyle(fontWeight: FontWeight.w800)),
                      subtitle: subtitleBuilder == null || subtitleBuilder!(item).isEmpty ? null : Text(subtitleBuilder!(item)),
                      onTap: () {
                        Navigator.pop(ctx);
                        onChanged(item);
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class OutletSearchField extends StatelessWidget {
  final OutletModel? value;
  final List<OutletModel> outlets;
  final ValueChanged<OutletModel> onChanged;
  final String label;
  const OutletSearchField({super.key, required this.value, required this.outlets, required this.onChanged, this.label = 'Outlet'});

  @override
  Widget build(BuildContext context) {
    return SearchableSelect<OutletModel>(
      label: label,
      hint: 'Search outlet by name/code',
      value: value,
      items: outlets,
      icon: Icons.store_rounded,
      titleBuilder: (o) => o.outletName,
      subtitleBuilder: (o) => [o.outletCode, o.address].where((e) => e.isNotEmpty).join(' • '),
      onChanged: onChanged,
    );
  }
}

class ItemSearchField extends StatelessWidget {
  final ItemModel? value;
  final List<ItemModel> items;
  final ValueChanged<ItemModel> onChanged;
  const ItemSearchField({super.key, required this.value, required this.items, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return SearchableSelect<ItemModel>(
      label: 'Item',
      hint: 'Search item by name/code',
      value: value,
      items: items,
      icon: Icons.inventory_2_rounded,
      titleBuilder: (i) => i.itemName,
      subtitleBuilder: (i) => '${i.itemCode} • Rate: ${i.salesRate.toStringAsFixed(2)}',
      onChanged: onChanged,
    );
  }
}
