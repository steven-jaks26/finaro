import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers.dart';
import '../../core/formatters/money.dart';
import '../../core/formatters/jalali.dart';
import '../../domain/financial_engine.dart';
import '../../domain/models/models.dart';
import '../../domain/recommendation_engine.dart';
import '../widgets/app_shell.dart';
import '../widgets/chart.dart';

class ForecastScreen extends ConsumerStatefulWidget {
  const ForecastScreen({super.key});
  @override
  ConsumerState<ForecastScreen> createState() => _ForecastState();
}

class _ForecastState extends ConsumerState<ForecastScreen> {
  int horizonMonths = 6;
  Map<String, bool> _activeSelection = {};
  Map<String, bool> _draftSelection = {};
  bool _selectionInitialized = false;
  bool _incomeExpanded = true;
  bool _expenseExpanded = true;
  bool _liabilityExpanded = true;

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(profileProvider), i = ref.watch(incomesProvider), e = ref.watch(expensesProvider), l = ref.watch(liabilitiesProvider);
    if ([p, i, e, l].any((x) => x.isLoading)) return const AppShell(title: 'پیش‌بینی مالی', index: 2, child: Center(child: CircularProgressIndicator()));
    final profile = p.value!, incomes = i.value!, expenses = e.value!, liabilities = l.value!;
    final allIds = [...incomes.map((x) => x.id), ...expenses.map((x) => x.id), ...liabilities.map((x) => x.id)];
    if (!_selectionInitialized || allIds.any((id) => !_activeSelection.containsKey(id))) {
      _activeSelection = {for (final id in allIds) id: true};
      _draftSelection = {..._activeSelection};
      _selectionInitialized = true;
    }

    final days = _daysForMonths(horizonMonths);
    final selectedIncomes = incomes.where((x) => _activeSelection[x.id] != false).toList();
    final selectedExpenses = expenses.where((x) => _activeSelection[x.id] != false).toList();
    final selectedLiabilities = liabilities.where((x) => _activeSelection[x.id] != false).toList();
    final snapshot = FinancialEngine.calculate(profile: profile, incomes: selectedIncomes, expenses: selectedExpenses, liabilities: selectedLiabilities, forecastDays: days);
    final recommendations = RecommendationEngine.build(profile: profile, incomes: selectedIncomes, expenses: selectedExpenses, liabilities: selectedLiabilities, forecastDays: days, limit: 5);

    return AppShell(title: 'پیش‌بینی مالی', index: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      FinaroCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionHeader(title: 'افق پیش‌بینی', subtitle: 'انتخاب افق فقط روی محاسبه اثر می‌گذارد و هیچ رکورد مالی را تغییر نمی‌دهد.'),
        const SizedBox(height: 10),
        Wrap(spacing: 8, runSpacing: 8, children: [2, 4, 6, 12, 24, 60].map((m) => ChoiceChip(label: Text(_horizonLabel(m)), selected: horizonMonths == m, onSelected: (_) => setState(() => horizonMonths = m))).toList()),
      ])),
      const SizedBox(height: 14),
      _selectionCard(incomes, expenses, liabilities),
      const SizedBox(height: 14),
      FinaroCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        SectionHeader(title: 'وضعیت آینده', subtitle: 'بر اساس رکوردهای انتخاب‌شده در افق ${_horizonLabel(horizonMonths)}'),
        const SizedBox(height: 10),
        BalanceChart(points: snapshot.points),
      ])),
      const SizedBox(height: 14),
      Row(children: [Expanded(child: _Kpi(title: 'کمترین موجودی', value: MoneyFormatter.toman(snapshot.minimumBalanceRials), bad: snapshot.minimumBalanceRials < 0)), const SizedBox(width: 10), Expanded(child: _Kpi(title: 'تاریخ کمینه', value: JalaliDate.fromGregorian(DateTime.parse(snapshot.minimumPoint.date)).display))]),
      const SizedBox(height: 10),
      _Kpi(title: 'روزهای منفی', value: '${snapshot.negativeDays} روز', bad: snapshot.negativeDays > 0),
      const SizedBox(height: 14),
      snapshot.isCritical ? const StatusBanner(icon: Icons.warning_amber_rounded, title: 'هشدار نقدینگی', message: 'در افق انتخاب‌شده حداقل یک روز با موجودی منفی پیش‌بینی شده است.', tone: Colors.red) : const StatusBanner(icon: Icons.check_circle_outline, title: 'پیش‌بینی پایدار', message: 'در افق انتخاب‌شده موجودی پیش‌بینی‌شده منفی نمی‌شود.', tone: Colors.green),
      const SizedBox(height: 14),
      _recommendationsCard(recommendations),
      const SizedBox(height: 14),
      FinaroCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionHeader(title: 'شبیه‌سازی تصمیم', subtitle: 'قبل از تغییر واقعی، اثر افزایش درآمد، کاهش هزینه، هزینه یا درآمد یک‌باره و تعویق تعهد را ببینید.'),
        const SizedBox(height: 10),
        FilledButton.icon(onPressed: () => context.go('/scenario'), icon: const Icon(Icons.science_outlined), label: const Text('ساخت سناریوی What-If')),
      ])),
      const SizedBox(height: 14),
      FinaroCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const SectionHeader(title: 'ماه‌های پیش‌رو', subtitle: 'برای تصمیم‌گیری سریع، ابتدا کمینه و روزهای منفی را بررسی کنید.'), ...snapshot.points.where((x) => _monthMarker(x.date)).take(12).map((x) => ListTile(contentPadding: EdgeInsets.zero, title: Text(JalaliDate.fromGregorian(DateTime.parse(x.date)).display), trailing: Text(MoneyFormatter.toman(x.balanceRials), style: const TextStyle(fontWeight: FontWeight.w800))))])),
    ]));
  }

  Widget _selectionCard(List<Income> incomes, List<Expense> expenses, List<Liability> liabilities) {
    final selected = _activeSelection.values.where((x) => x).length;
    final total = _activeSelection.length;
    return FinaroCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      SectionHeader(title: 'چه چیزهایی در پیش‌بینی لحاظ شوند؟', subtitle: '$selected از $total رکورد فعال است.'),
      const SizedBox(height: 8),
      _selectionSection('درآمد', incomes, _incomeExpanded, () => setState(() => _incomeExpanded = !_incomeExpanded)),
      _selectionSection('هزینه', expenses, _expenseExpanded, () => setState(() => _expenseExpanded = !_expenseExpanded)),
      _selectionSection('تعهدات', liabilities, _liabilityExpanded, () => setState(() => _liabilityExpanded = !_liabilityExpanded)),
      const SizedBox(height: 8),
      Row(children: [Expanded(child: OutlinedButton(onPressed: () => setState(() { for (final id in _draftSelection.keys) { _draftSelection[id] = true; } }), child: const Text('انتخاب همه'))), const SizedBox(width: 8), Expanded(child: OutlinedButton(onPressed: () => setState(() { for (final id in _draftSelection.keys) { _draftSelection[id] = false; } }), child: const Text('حذف انتخاب‌ها')))]),
      const SizedBox(height: 8),
      FilledButton.icon(onPressed: () => setState(() => _activeSelection = {..._draftSelection}), icon: const Icon(Icons.check), label: const Text('اعمال تغییرات')),
    ]));
  }

  Widget _selectionSection(String title, List<dynamic> records, bool expanded, VoidCallback toggle) {
    return ExpansionTile(initiallyExpanded: expanded, onExpansionChanged: (_) => toggle(), title: Text('$title (${records.length})', style: const TextStyle(fontWeight: FontWeight.w800)), children: records.map((record) {
      final String id = record.id, label = record.title;
      final int amount = record is Income ? record.amountRials : record is Expense ? record.amountRials : record.installmentRials > 0 ? record.installmentRials : record.totalRials;
      final String date = record is Income ? record.start : record is Expense ? (record.startDate.isEmpty ? record.date : record.startDate) : record.paymentDate;
      return CheckboxListTile(value: _draftSelection[id] != false, onChanged: (v) => setState(() => _draftSelection[id] = v ?? false), title: Text(label), subtitle: Text('${MoneyFormatter.toman(amount)} • ${date.replaceAll('-', '/')}'), controlAffinity: ListTileControlAffinity.leading);
    }).toList());
  }

  Widget _recommendationsCard(List<FinancialRecommendation> items) {
    return FinaroCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      const SectionHeader(title: 'پیشنهادهای مبتنی بر پیش‌بینی', subtitle: 'فقط اقداماتی نمایش داده می‌شوند که شبیه‌سازی آن‌ها وضعیت مالی را واقعاً بهتر کند.'),
      const SizedBox(height: 8),
      if (items.isEmpty) const Padding(padding: EdgeInsets.symmetric(vertical: 10), child: Text('در این افق و با این انتخاب‌ها، اقدام قطعیِ بهبوددهنده‌ای پیدا نشد.')),
      ...items.map((x) => ListTile(contentPadding: EdgeInsets.zero, leading: const Icon(Icons.lightbulb_outline), title: Text(x.title, style: const TextStyle(fontWeight: FontWeight.w800)), subtitle: Text('${_impactText(x)}\nفرض: ${x.assumption}'))),
    ]));
  }

  String _impactText(FinancialRecommendation x) {
    final impact = x.impact;
    final min = MoneyFormatter.toman(impact.minimumBalanceDeltaRials);
    final fin = MoneyFormatter.toman(impact.finalBalanceDeltaRials);
    final neg = impact.negativeDaysDelta;
    return 'اثر شبیه‌سازی: کمینه $min، موجودی نهایی $fin، روزهای منفی ${neg > 0 ? '+' : ''}$neg';
  }

  int _daysForMonths(int months) {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month + months, now.day);
    return end.difference(DateTime(now.year, now.month, now.day)).inDays;
  }
}

String _horizonLabel(int m) => m == 12 ? '۱ سال' : m == 24 ? '۲ سال' : m == 60 ? '۵ سال' : '$m ماه';
bool _monthMarker(String date) { final parts = date.split('-'); return parts.length == 3 && parts[2] == '01'; }
class _Kpi extends StatelessWidget { const _Kpi({required this.title, required this.value, this.bad = false}); final String title, value; final bool bad; @override Widget build(BuildContext c) => FinaroCard(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 11, color: Theme.of(c).colorScheme.onSurfaceVariant)), const SizedBox(height: 6), Text(value, style: TextStyle(fontWeight: FontWeight.w900, color: bad ? Theme.of(c).colorScheme.error : null))])); }
