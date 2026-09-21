import 'package:flutter_test/flutter_test.dart';
import 'package:finaro/domain/financial_engine.dart';
import 'package:finaro/domain/models/models.dart';

void main() {
  final today = DateTime(2026, 3, 15);

  test('rebuilds current balance through today, then starts forecast tomorrow', () {
    final snapshot = FinancialEngine.calculate(
      today: today,
      profile: const FinancialProfile(openingBalanceRials: 1_000),
      incomes: const [Income(id: 'i', title: 'حقوق', amountRials: 500, frequency: 'ماهانه', start: '2026-01-01', payDay: 1)],
      expenses: const [],
      liabilities: const [],
      forecastDays: 1,
    );
    expect(snapshot.currentBalanceRials, 2_500);
    expect(snapshot.points.single.balanceRials, 2_500);
  });

  test('monthly recurrence clamps day 31 into short months', () {
    final snapshot = FinancialEngine.calculate(
      today: DateTime(2026, 1, 31),
      profile: const FinancialProfile(openingBalanceRials: 10_000, openingBalanceDate: '2026-01-01'),
      incomes: const [Income(id: 'i', title: 'درآمد', amountRials: 100, frequency: 'ماهانه', start: '2026-01-01', payDay: 31)],
      expenses: const [], liabilities: const [], forecastDays: 28,
    );
    expect(snapshot.points.first.balanceRials, 10_100);
    expect(snapshot.points.last.balanceRials, 10_200);
  });

  test('expense startDate is authoritative over legacy date', () {
    final snapshot = FinancialEngine.calculate(
      today: DateTime(2026, 3, 10),
      profile: const FinancialProfile(openingBalanceRials: 10_000, openingBalanceDate: '2026-03-01'),
      incomes: const [],
      expenses: const [Expense(id: 'e', title: 'اجاره', amountRials: 2_000, frequency: 'ماهانه', category: 'مسکن', date: '2026-03-01', startDate: '2026-03-20', paymentDay: 20)],
      liabilities: const [], forecastDays: 10,
    );
    expect(snapshot.currentBalanceRials, 10_000);
    expect(snapshot.points.last.balanceRials, 8_000);
  });

  test('installment liability stops after remaining installment count', () {
    final snapshot = FinancialEngine.calculate(
      today: DateTime(2026, 1, 1),
      profile: const FinancialProfile(openingBalanceRials: 10_000, openingBalanceDate: '2026-01-01'),
      incomes: const [], expenses: const [],
      liabilities: const [Liability(id: 'l', title: 'قسط', type: 'قسط', totalRials: 3_000, installmentRials: 1_000, remainingInstallments: 2, frequency: 'ماهانه', paymentDate: '2026-01-01', paymentDay: 1)],
      forecastDays: 90,
    );
    expect(snapshot.currentBalanceRials, 9_000);
    expect(snapshot.points.last.balanceRials, 8_000);
  });
}
