import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers.dart';
import '../../core/formatters/money.dart';
import '../../core/formatters/jalali.dart';
import '../../domain/financial_engine.dart';
import '../widgets/app_shell.dart';
import '../widgets/chart.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileProvider), incomes = ref.watch(incomesProvider), expenses = ref.watch(expensesProvider), liabilities = ref.watch(liabilitiesProvider);
    if ([profile, incomes, expenses, liabilities].any((x) => x.isLoading)) return const AppShell(title: 'خانه', index: 0, child: Center(child: CircularProgressIndicator()));
    if ([profile, incomes, expenses, liabilities].any((x) => x.hasError)) return AppShell(title: 'خانه', index: 0, child: StatusBanner(icon: Icons.error_outline, title: 'داده‌ها آماده نیستند', message: '${profile.error ?? incomes.error ?? expenses.error ?? liabilities.error}', tone: Colors.red));
    final snapshot = FinancialEngine.calculate(profile: profile.value!, incomes: incomes.value!, expenses: expenses.value!, liabilities: liabilities.value!, forecastDays: 90);
    final points = snapshot.points;
    final min = snapshot.minimumBalanceRials;
    final minPoint = snapshot.minimumPoint;
    final negativeDays = snapshot.negativeDays;
    final today = JalaliDate.fromGregorian(DateTime.now()).display;
    return AppShell(
      title: 'وضعیت مالی من', index: 0,
      actions: [IconButton(tooltip: 'ثبت سریع', onPressed: () => context.go('/smart-input'), icon: const Icon(Icons.auto_awesome))],
      floatingActionButton: FloatingActionButton.extended(onPressed: () => context.go('/smart-input'), icon: const Icon(Icons.auto_awesome), label: const Text('ثبت سریع')),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('امروز $today', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
        const SizedBox(height: 8),
        FinaroCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('موجودی فعلی', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 6),
          Text(MoneyFormatter.toman(snapshot.currentBalanceRials), style: const TextStyle(fontSize: 31, fontWeight: FontWeight.w900)),
          const SizedBox(height: 5),
          Text('نقطه شروع محاسبه آینده مالی شما', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
          const SizedBox(height: 14),
          FilledButton.icon(onPressed: () => context.go('/forecast'), icon: const Icon(Icons.insights_outlined), label: const Text('آینده مالی را ببین')),
        ])),
        const SizedBox(height: 14),
        Row(children: [
          Expanded(child: _Metric(label: 'کمترین موجودی', value: MoneyFormatter.toman(min), negative: min < 0)),
          const SizedBox(width: 10),
          Expanded(child: _Metric(label: 'روز کمینه', value: minPoint.date.replaceAll('-', '/'))),
        ]),
        const SizedBox(height: 10),
        _Metric(label: 'روزهای منفی در ۹۰ روز', value: '$negativeDays روز', negative: negativeDays > 0),
        const SizedBox(height: 14),
        if (negativeDays > 0) ...[
          StatusBanner(icon: Icons.warning_amber_rounded, title: 'ریسک نقدینگی', message: 'در مسیر فعلی بخشی از آینده با موجودی منفی روبه‌رو می‌شود. جزئیات را در پیش‌بینی بررسی کنید.', tone: Colors.red),
          const SizedBox(height: 14),
        ] else StatusBanner(icon: Icons.check_circle_outline, title: 'مسیر فعلی پایدار است', message: 'در ۹۰ روز آینده موجودی پیش‌بینی‌شده منفی نمی‌شود.', tone: Colors.green),
        const SizedBox(height: 14),
        FinaroCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [const SectionHeader(title: 'روند موجودی', subtitle: 'پیش‌بینی ۹۰ روز آینده بر اساس داده‌های ثبت‌شده'), BalanceChart(points: points)])),
        const SizedBox(height: 14),
        FinaroCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const SectionHeader(title: 'شروع سریع', subtitle: 'برای ثبت مالی لازم نیست فرم‌های طولانی را پر کنید.'),
          _QuickAction(icon: Icons.auto_awesome, title: 'با زبان طبیعی ثبت کن', text: 'مثلاً: «امروز ۸۰ هزار تومان تاکسی دادم»', onTap: () => context.go('/smart-input')),
          const Divider(height: 24),
          _QuickAction(icon: Icons.account_balance_wallet_outlined, title: 'اطلاعات مالی', text: '${incomes.value!.length} درآمد، ${expenses.value!.length} هزینه، ${liabilities.value!.length} تعهد', onTap: () => context.go('/financial')),
        ])),
      ]),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, this.negative = false});
  final String label, value; final bool negative;
  @override Widget build(BuildContext context) => FinaroCard(padding: const EdgeInsets.all(15), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(label, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)), const SizedBox(height: 6), Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: negative ? Theme.of(context).colorScheme.error : null))]));
}
class _QuickAction extends StatelessWidget { const _QuickAction({required this.icon, required this.title, required this.text, required this.onTap}); final IconData icon; final String title,text; final VoidCallback onTap; @override Widget build(BuildContext c)=>ListTile(onTap:onTap,contentPadding:EdgeInsets.zero,leading:CircleAvatar(child:Icon(icon)),title:Text(title,style:const TextStyle(fontWeight:FontWeight.w800)),subtitle:Text(text),trailing:const Icon(Icons.chevron_left)); }
