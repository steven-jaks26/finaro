import 'financial_engine.dart';
import 'models/models.dart';

/// Compatibility facade for Phase 5 widgets. Phase 6 calculations live in FinancialEngine.
class ForecastEngine {
  const ForecastEngine._();
  static List<ForecastPoint> build({required FinancialProfile profile, required List<Income> incomes, required List<Expense> expenses, required List<Liability> liabilities, int days = 180}) => FinancialEngine.calculate(profile: profile, incomes: incomes, expenses: expenses, liabilities: liabilities, forecastDays: days).points;
}
