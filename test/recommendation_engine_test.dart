import 'package:flutter_test/flutter_test.dart';
import 'package:finaro/domain/models/models.dart';
import 'package:finaro/domain/recommendation_engine.dart';

void main() {
  test('returns only objectively improving recurring expense recommendations', () {
    final result = RecommendationEngine.build(
      today: DateTime(2026, 1, 1),
      profile: const FinancialProfile(openingBalanceRials: 10_000, openingBalanceDate: '2026-01-01'),
      incomes: const [],
      expenses: const [Expense(id: 'rent', title: 'اجاره', amountRials: 2_000, frequency: 'ماهانه', category: 'مسکن', date: '2026-01-01', startDate: '2026-01-01', paymentDay: 1)],
      liabilities: const [],
      forecastDays: 60,
    );
    expect(result, isNotEmpty);
    expect(result.every((x) => x.type == RecommendationType.reduceRecurringExpense), isTrue);
    expect(result.every((x) => x.impact.minimumBalanceDeltaRials > 0 || x.impact.finalBalanceDeltaRials > 0), isTrue);
  });

  test('selection is calculation-only and excludes unchecked records from recommendations', () {
    final result = RecommendationEngine.build(
      today: DateTime(2026, 1, 1),
      profile: const FinancialProfile(openingBalanceRials: 10_000, openingBalanceDate: '2026-01-01'),
      incomes: const [Income(id: 'salary', title: 'حقوق', amountRials: 5_000, frequency: 'ماهانه', start: '2026-01-01', payDay: 1)],
      expenses: const [Expense(id: 'food', title: 'خوراک', amountRials: 2_000, frequency: 'ماهانه', category: 'خوراک', date: '2026-01-01', startDate: '2026-01-01', paymentDay: 1)],
      liabilities: const [],
      selection: const {'salary': true, 'food': false},
      forecastDays: 60,
    );
    expect(result.every((x) => x.targetId != 'food'), isTrue);
  });
}
