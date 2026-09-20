import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../core/formatters/jalali.dart';
import '../../core/formatters/money.dart';
import '../../domain/models/models.dart';
import '../../domain/scenario_engine.dart';
import '../widgets/app_shell.dart';

class ScenarioScreen extends ConsumerStatefulWidget {
  const ScenarioScreen({super.key});
  @override ConsumerState<ScenarioScreen> createState() => _ScenarioState();
}

class _ScenarioState extends ConsumerState<ScenarioScreen> {
  int horizonMonths = 6;
  ScenarioActionType type = ScenarioActionType.reduceExpensePercent;
  String? targetId;
  int percent = 10;
  int amountToman = 5000000;
  DateTime date = DateTime.now().add(const Duration(days: 30));

  @override
  Widget build(BuildContext context) {
    final p = ref.watch(profileProvider), i = ref.watch(incomesProvider), e = ref.watch(expensesProvider), l = ref.watch(liabilitiesProvider);
    if ([p, i, e, l].any((x) => x.isLoading)) return const AppShell(title: 'شبیه‌سازی تصمیم', index: 2, child: Center(child: CircularProgressIndicator()));
    final profile = p.value!, incomes = i.value!, expenses = e.value!, liabilities = l.value!;
    final records = _targets(incomes, expenses, liabilities);
    targetId ??= records.isEmpty ? null : records.first.id;
    final action = ScenarioAction(id: 'scenario-preview', type: type, targetId: targetId, percent: percent, amountRials: amountToman * 10, date: _iso(date));
    final comparison = _canCompare(action) ? ScenarioEngine.compare(profile: profile, incomes: incomes, expenses: expenses, liabilities: liabilities, action: action, forecastDays: _daysForMonths(horizonMonths)) : null;

    return AppShell(title: 'شبیه‌سازی تصمیم', index: 2, child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      FinaroCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const SectionHeader(title: 'اگر این تصمیم را بگیرم چه می‌شود؟', subtitle: 'سناریو فقط روی یک کپی محاسباتی اثر می‌گذارد و اطلاعات واقعی مالی را تغییر نمی‌دهد.'),
        const SizedBox(height: 14),
        DropdownButtonFormField<ScenarioActionType>(value: type, decoration: const InputDecoration(labelText: 'نوع تغییر'), items: const [
          DropdownMenuItem(value: ScenarioActionType.reduceExpensePercent, child: Text('کاهش درصدی یک هزینه تکرارشونده')),
          DropdownMenuItem(value: ScenarioActionType.increaseIncomePercent, child: Text('افزایش درصدی یک درآمد تکرارشونده')),
          DropdownMenuItem(value: ScenarioActionType.addOneTimeIncome, child: Text('درآمد یک‌باره')),
          DropdownMenuItem(value: ScenarioActionType.addOneTimeExpense, child: Text('هزینه یک‌باره')),
          DropdownMenuItem(value: ScenarioActionType.deferLiability, child: Text('تعویق یک تعهد')),
        ], onChanged: (v) => setState(() { type = v!; targetId = null; })),
        const SizedBox(height: 12),
        if (_needsTarget) DropdownButtonFormField<String>(value: targetId, decoration: InputDecoration(labelText: _targetLabel), items: _targetRecords(incomes, expenses, liabilities).map<DropdownMenuItem<String>>((x) => DropdownMenuItem<String>(value: x.id, child: Text(x.title))).toList(), onChanged: (v) => setState(() => targetId = v)),
        if (_needsTarget) const SizedBox(height: 12),
        if (_needsPercent) ...[
          Text('درصد تغییر: $percent٪', style: const TextStyle(fontWeight: FontWeight.w800)),
          Slider(value: percent.toDouble(), min: 5, max: 50, divisions: 9, label: '$percent٪', onChanged: (v) => setState(() => percent = v.round())),
        ],
        if (_needsAmount) TextFormField(initialValue: amountToman.toString(), keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: 'مبلغ (تومان)'), onChanged: (v) => amountToman = int.tryParse(v.replaceAll(',', '')) ?? amountToman),
        if (_needsAmount) const SizedBox(height: 12),
        if (_needsDate) OutlinedButton.icon(onPressed: () async { final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 3650))); if (d != null) setState(() => date = d); }, icon: const Icon(Icons.calendar_today_outlined), label: Text('تاریخ: ${JalaliDate.fromGregorian(date).display}')),
        const SizedBox(height: 12),
        DropdownButtonFormField<int>(value: horizonMonths, decoration: const InputDecoration(labelText: 'افق سناریو'), items: [2,4,6,12,24,60].map((m) => DropdownMenuItem(value: m, child: Text(_horizonLabel(m)))).toList(), onChanged: (v) => setState(() => horizonMonths = v!)),
      ])),
      const SizedBox(height: 14),
      if (comparison != null) _comparisonCard(comparison),
      if (comparison != null) ...[const SizedBox(height: 14), _decisionBanner(comparison)],
      const SizedBox(height: 14),
      const StatusBanner(icon: Icons.lock_outline, title: 'اطلاعات اصلی امن است', message: 'این صفحه هیچ رکورد درآمد، هزینه یا تعهد را ذخیره یا ویرایش نمی‌کند؛ نتیجه فقط یک شبیه‌سازی است.', tone: Colors.blue),
    ]));
  }

  bool get _needsTarget => type == ScenarioActionType.reduceExpensePercent || type == ScenarioActionType.increaseIncomePercent || type == ScenarioActionType.deferLiability;
  bool get _needsPercent => type == ScenarioActionType.reduceExpensePercent || type == ScenarioActionType.increaseIncomePercent;
  bool get _needsAmount => type == ScenarioActionType.addOneTimeIncome || type == ScenarioActionType.addOneTimeExpense;
  bool get _needsDate => _needsAmount;
  String get _targetLabel => type == ScenarioActionType.reduceExpensePercent ? 'هزینه مورد نظر' : type == ScenarioActionType.increaseIncomePercent ? 'درآمد مورد نظر' : 'تعهد مورد نظر';
  bool _canCompare(ScenarioAction a) => !_needsTarget || a.targetId != null;

  List<dynamic> _targetRecords(List<Income> i, List<Expense> e, List<Liability> l) => type == ScenarioActionType.reduceExpensePercent ? e.where((x) => x.frequency != 'یک‌بار').toList() : type == ScenarioActionType.increaseIncomePercent ? i.where((x) => x.frequency != 'یک‌بار').toList() : l;
  List<dynamic> _targets(List<Income> i, List<Expense> e, List<Liability> l) => [...i, ...e, ...l];

  Widget _comparisonCard(ScenarioComparison x) => FinaroCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const SectionHeader(title: 'نتیجه شبیه‌سازی', subtitle: 'مقایسه سناریو با پیش‌بینی پایه'),
    const SizedBox(height: 10),
    _row('کمترین موجودی', x.baseline.minimum, x.scenario.minimum, x.minimumDelta),
    _row('موجودی پایان افق', x.baseline.finalBalance, x.scenario.finalBalance, x.finalBalanceDelta),
    _row('روزهای منفی', x.baseline.negativeDays, x.scenario.negativeDays, x.negativeDaysDelta, money: false),
    _row('تاریخ کمترین موجودی', DateTime.parse(x.baseline.minimumDate).millisecondsSinceEpoch, DateTime.parse(x.scenario.minimumDate).millisecondsSinceEpoch, 0, date: true),
  ]));

  Widget _row(String title, int base, int scenario, int delta, {bool money = true, bool date = false}) {
    final baseText = date ? JalaliDate.fromGregorian(DateTime.fromMillisecondsSinceEpoch(base)).display : money ? MoneyFormatter.toman(base) : '$base روز';
    final scenarioText = date ? JalaliDate.fromGregorian(DateTime.fromMillisecondsSinceEpoch(scenario)).display : money ? MoneyFormatter.toman(scenario) : '$scenario روز';
    final deltaText = date ? '' : ' (${delta > 0 ? '+' : ''}${money ? MoneyFormatter.toman(delta) : '$delta روز'})';
    return ListTile(contentPadding: EdgeInsets.zero, title: Text(title), subtitle: Text('پایه: $baseText'), trailing: Text('سناریو: $scenarioText$deltaText', textAlign: TextAlign.end, style: const TextStyle(fontWeight: FontWeight.w800)));
  }

  Widget _decisionBanner(ScenarioComparison x) => x.improves && !x.worsens ? const StatusBanner(icon: Icons.check_circle_outline, title: 'سناریو بهبوددهنده است', message: 'این تغییر، دست‌کم یکی از شاخص‌های اصلی را بهتر کرده و شاخص دیگری را بدتر نکرده است.', tone: Colors.green) : x.worsens && !x.improves ? const StatusBanner(icon: Icons.warning_amber_rounded, title: 'سناریو وضعیت را بدتر می‌کند', message: 'این تصمیم در مقایسه با حالت پایه اثر منفی دارد.', tone: Colors.red) : const StatusBanner(icon: Icons.compare_arrows, title: 'اثر ترکیبی', message: 'سناریو بعضی شاخص‌ها را بهتر و بعضی را بدتر می‌کند؛ قبل از تصمیم، اثر هر شاخص را جداگانه بررسی کنید.', tone: Colors.orange);

  int _daysForMonths(int months) { final n = DateTime.now(); return DateTime(n.year, n.month + months, n.day).difference(DateTime(n.year, n.month, n.day)).inDays; }
  String _horizonLabel(int m) => m == 12 ? '۱ سال' : m == 24 ? '۲ سال' : m == 60 ? '۵ سال' : '$m ماه';
  String _iso(DateTime d) => '${d.year.toString().padLeft(4,'0')}-${d.month.toString().padLeft(2,'0')}-${d.day.toString().padLeft(2,'0')}';
}
