import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers.dart';
import '../../core/formatters/money.dart';
import '../../domain/models/models.dart';
import '../widgets/app_shell.dart';

class FinancialScreen extends ConsumerWidget {
  const FinancialScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = ref.watch(profileProvider), i = ref.watch(incomesProvider), e = ref.watch(expensesProvider), l = ref.watch(liabilitiesProvider), cats = ref.watch(categoriesProvider);
    if ([p, i, e, l, cats].any((x) => x.isLoading)) return const AppShell(title: 'مالی من', index: 1, child: Center(child: CircularProgressIndicator()));
    return AppShell(title: 'مالی من', index: 1, actions: [IconButton(tooltip: 'ثبت سریع', onPressed: () => context.go('/smart-input'), icon: const Icon(Icons.auto_awesome))], floatingActionButton: FloatingActionButton.extended(onPressed: () => showModalBottomSheet(context: context, builder: (_) => const _AddSheet()), icon: const Icon(Icons.add), label: const Text('ثبت مورد')), child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      FinaroCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const SectionHeader(title: 'موجودی شروع دوره', subtitle: 'این عدد نقطه شروع محاسبات پیش‌بینی است.'), Text(MoneyFormatter.toman(p.value!.openingBalanceRials), style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900)), const SizedBox(height: 12), OutlinedButton.icon(onPressed: () => showDialog(context: context, builder: (_) => const BalanceDialog()), icon: const Icon(Icons.edit_outlined), label: const Text('ویرایش موجودی'))])),
      const SizedBox(height: 14),
      _RecordSection(title: 'درآمدها', icon: Icons.south_west, items: i.value!.map((x) => _RecordItem(id: x.id, title: x.title, subtitle: x.frequency, amount: x.amountRials, kind: 'income')).toList(), empty: 'هنوز درآمدی ثبت نشده است.', onAdd: () => showDialog(context: context, builder: (_) => const RecordDialog(type: 'income'))),
      _RecordSection(title: 'هزینه‌ها', icon: Icons.north_east, items: e.value!.map((x) => _RecordItem(id: x.id, title: x.title, subtitle: x.category, amount: x.amountRials, kind: 'expense')).toList(), empty: 'هنوز هزینه‌ای ثبت نشده است.', onAdd: () => showDialog(context: context, builder: (_) => const RecordDialog(type: 'expense'))),
      _RecordSection(title: 'تعهدات', icon: Icons.receipt_long_outlined, items: l.value!.map((x) => _RecordItem(id: x.id, title: x.title, subtitle: x.type, amount: x.type == 'قسط' ? x.installmentRials : x.totalRials, kind: 'liability')).toList(), empty: 'هنوز تعهدی ثبت نشده است.', onAdd: () => showDialog(context: context, builder: (_) => const RecordDialog(type: 'liability'))),
      FinaroCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const SectionHeader(title: 'دسته‌بندی‌ها', subtitle: 'دسته‌بندی هزینه‌ها را برای گزارش‌های دقیق‌تر مدیریت کنید.'), Wrap(spacing: 8, runSpacing: 8, children: cats.value!.map((x) => Chip(label: Text(x.title))).toList()), const SizedBox(height: 10), OutlinedButton.icon(onPressed: () => showDialog(context: context, builder: (_) => const CategoryDialog()), icon: const Icon(Icons.add), label: const Text('افزودن دسته‌بندی'))])),
    ]));
  }
}

class _RecordItem { const _RecordItem({required this.id, required this.title, required this.subtitle, required this.amount, required this.kind}); final String id, title, subtitle, kind; final int amount; }

class _RecordSection extends ConsumerWidget {
  const _RecordSection({required this.title, required this.icon, required this.items, required this.empty, required this.onAdd});
  final String title, empty; final IconData icon; final List<_RecordItem> items; final VoidCallback onAdd;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(padding: const EdgeInsets.only(bottom: 14), child: FinaroCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeader(title: title, action: IconButton(onPressed: onAdd, icon: const Icon(Icons.add))),
      if (items.isEmpty) Text(empty, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant))
      else ...items.take(10).map((x) => ListTile(contentPadding: EdgeInsets.zero, leading: CircleAvatar(child: Icon(icon, size: 18)), title: Text(x.title, style: const TextStyle(fontWeight: FontWeight.w700)), subtitle: Text(x.subtitle), trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text(MoneyFormatter.toman(x.amount), style: const TextStyle(fontWeight: FontWeight.w800)), PopupMenuButton<String>(onSelected: (v) async { if (v == 'delete') { await ref.read(repoProvider).delete(x.kind == 'income' ? 'income' : x.kind == 'expense' ? 'expense' : 'liability', x.id); ref.invalidate(incomesProvider); ref.invalidate(expensesProvider); ref.invalidate(liabilitiesProvider); } }, itemBuilder: (_) => const [PopupMenuItem(value: 'delete', child: Text('حذف'))])]))),
    ])));
  }
}

class _AddSheet extends StatelessWidget {
  const _AddSheet();
  @override Widget build(BuildContext context) => SafeArea(child: Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [const SectionHeader(title: 'چه چیزی می‌خواهید ثبت کنید؟'), ListTile(leading: const Icon(Icons.south_west), title: const Text('درآمد'), onTap: () { Navigator.pop(context); showDialog(context: context, builder: (_) => const RecordDialog(type: 'income')); }), ListTile(leading: const Icon(Icons.north_east), title: const Text('هزینه'), onTap: () { Navigator.pop(context); showDialog(context: context, builder: (_) => const RecordDialog(type: 'expense')); }), ListTile(leading: const Icon(Icons.receipt_long), title: const Text('تعهد'), onTap: () { Navigator.pop(context); showDialog(context: context, builder: (_) => const RecordDialog(type: 'liability')); })])));
}

class BalanceDialog extends ConsumerStatefulWidget { const BalanceDialog({super.key}); @override ConsumerState<BalanceDialog> createState() => _BalanceState(); }
class _BalanceState extends ConsumerState<BalanceDialog> { final ctl = TextEditingController(); @override Widget build(BuildContext context) => AlertDialog(title: const Text('موجودی شروع دوره'), content: TextField(controller: ctl, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مبلغ به تومان')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')), FilledButton(onPressed: () async { final n = MoneyFormatter.tomanToRials(ctl.text); await ref.read(repoProvider).updateOpeningBalance(n); ref.invalidate(profileProvider); if (mounted) Navigator.pop(context); }, child: const Text('ذخیره'))]); @override void dispose() { ctl.dispose(); super.dispose(); } }

class RecordDialog extends ConsumerStatefulWidget {
  const RecordDialog({super.key, required this.type});
  final String type;
  @override ConsumerState<RecordDialog> createState() => _RecordState();
}

class _RecordState extends ConsumerState<RecordDialog> {
  final title = TextEditingController();
  final amount = TextEditingController();
  String freq = 'ماهانه';
  String category = 'متفرقه';

  @override void dispose() { title.dispose(); amount.dispose(); super.dispose(); }

  Future<void> save() async {
    final id = DateTime.now().microsecondsSinceEpoch.toString();
    final d = DateTime.now().toIso8601String().substring(0, 10);
    final a = MoneyFormatter.tomanToRials(amount.text);
    final repo = ref.read(repoProvider);
    if (widget.type == 'income') {
      await repo.addIncome(Income(id: id, title: title.text.trim(), amountRials: a, frequency: freq, start: d, payDay: freq == 'ماهانه' ? DateTime.now().day : null));
    } else if (widget.type == 'expense') {
      await repo.addExpense(Expense(id: id, title: title.text.trim(), amountRials: a, frequency: freq, category: category, date: d, startDate: d, paymentDay: freq == 'ماهانه' ? DateTime.now().day : null));
    } else {
      await repo.addLiability(Liability(id: id, title: title.text.trim(), type: 'بدهی', totalRials: a, paymentDate: d));
    }
    ref.invalidate(incomesProvider); ref.invalidate(expensesProvider); ref.invalidate(liabilitiesProvider);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final frequencies = const ['یک‌بار', 'همین ماه', 'روزانه', 'هفتگی', 'ماهانه', 'سالانه'];
    return AlertDialog(
      title: Text(widget.type == 'income' ? 'درآمد جدید' : widget.type == 'expense' ? 'هزینه جدید' : 'تعهد جدید'),
      content: SingleChildScrollView(child: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(controller: title, decoration: const InputDecoration(labelText: 'عنوان')),
        const SizedBox(height: 10),
        TextField(controller: amount, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مبلغ تومان')),
        if (widget.type != 'liability') ...[
          const SizedBox(height: 10),
          DropdownButtonFormField<String>(initialValue: freq, decoration: const InputDecoration(labelText: 'دوره'), items: frequencies.map((x) => DropdownMenuItem(value: x, child: Text(x))).toList(), onChanged: (v) => setState(() => freq = v ?? freq)),
        ],
        if (widget.type == 'expense') ...[
          const SizedBox(height: 10),
          TextField(decoration: const InputDecoration(labelText: 'دسته‌بندی'), onChanged: (v) => category = v),
        ],
      ])),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')), FilledButton(onPressed: save, child: const Text('ذخیره'))],
    );
  }
}

class CategoryDialog extends ConsumerStatefulWidget { const CategoryDialog({super.key}); @override ConsumerState<CategoryDialog> createState() => _CatState(); }
class _CatState extends ConsumerState<CategoryDialog> { final ctl = TextEditingController(); @override Widget build(BuildContext context) => AlertDialog(title: const Text('دسته‌بندی جدید'), content: TextField(controller: ctl, decoration: const InputDecoration(labelText: 'نام دسته‌بندی')), actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text('انصراف')), FilledButton(onPressed: () async { final n = ctl.text.trim(); if (n.isEmpty) return; await ref.read(repoProvider).addCategory(Category(id: DateTime.now().microsecondsSinceEpoch.toString(), title: n)); ref.invalidate(categoriesProvider); if (mounted) Navigator.pop(context); }, child: const Text('افزودن'))]); @override void dispose() { ctl.dispose(); super.dispose(); } }
