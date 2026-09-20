import 'package:sqflite_sqlcipher/sqflite.dart';import '../../domain/models/models.dart';import '../local/local_database.dart';
class FinancialRepository{FinancialRepository(this.local);final LocalDatabase local;Future<Database> get db=>local.database;Future<FinancialProfile> profile()async{final r=(await db).query('profile');final x=r.first;return FinancialProfile(id:x['id'] as String,name:x['name'] as String,openingBalanceRials:x['opening_balance_rials'] as int,openingBalanceDate:x['opening_balance_date'] as String?);}Future<List<Income>> incomes()async=>(await db).query('income').then((r)=>r.map((x)=>Income(id:x['id'] as String,title:x['title'] as String,amountRials:x['amount_rials'] as int,frequency:x['frequency'] as String,start:x['start_date'] as String,payDay:x['pay_day'] as int?)).toList());Future<List<Expense>> expenses()async=>(await db).query('expense').then((r)=>r.map((x)=>Expense(id:x['id'] as String,title:x['title'] as String,amountRials:x['amount_rials'] as int,frequency:x['frequency'] as String,category:x['category'] as String,date:x['date'] as String,startDate:x['start_date'] as String? ?? '',paymentDay:x['payment_day'] as int?)).toList());Future<List<Liability>> liabilities()async=>(await db).query('liability').then((r)=>r.map((x)=>Liability(id:x['id'] as String,title:x['title'] as String,type:x['type'] as String,totalRials:x['total_rials'] as int,installmentRials:x['installment_rials'] as int,remainingInstallments:x['remaining_installments'] as int,frequency:x['frequency'] as String,paymentDate:x['payment_date'] as String,paymentDay:x['payment_day'] as int?)).toList());Future<List<Category>> categories()async=>(await db).query('category').then((r)=>r.map((x)=>Category(id:x['id'] as String,title:x['title'] as String)).toList());Future<void> updateOpeningBalance(int rials)async{final database=await db;final rows=await database.query('profile',columns:['opening_balance_date'],where:'id=?',whereArgs:['local-profile'],limit:1);final existing=rows.isEmpty?null:rows.first['opening_balance_date'] as String?;await database.update('profile',{'opening_balance_rials':rials,'opening_balance_date':existing??DateTime.now().toIso8601String().substring(0,10)},where:'id=?',whereArgs:['local-profile']);}Future<void> addCategory(Category x)async=>(await db).insert('category',{'id':x.id,'title':x.title},conflictAlgorithm:ConflictAlgorithm.ignore);Future<void> addIncome(Income x)async=>(await db).insert('income',{'id':x.id,'title':x.title,'amount_rials':x.amountRials,'frequency':x.frequency,'start_date':x.start,'pay_day':x.payDay});Future<void> addExpense(Expense x)async=>(await db).insert('expense',{'id':x.id,'title':x.title,'amount_rials':x.amountRials,'frequency':x.frequency,'category':x.category,'date':x.date,'start_date':x.startDate,'payment_day':x.paymentDay});Future<void> addLiability(Liability x)async=>(await db).insert('liability',{'id':x.id,'title':x.title,'type':x.type,'total_rials':x.totalRials,'installment_rials':x.installmentRials,'remaining_installments':x.remainingInstallments,'frequency':x.frequency,'payment_date':x.paymentDate,'payment_day':x.paymentDay});Future<void> delete(String table,String id)async=>(await db).delete(table,where:'id=?',whereArgs:[id]);
  Future<void> restoreBackup(Map<String, dynamic> payload) async {
    final database = await db;
    final profile = payload['profile'] as Map<String, dynamic>?;
    final incomes = (payload['incomes'] as List<dynamic>? ?? const []);
    final expenses = (payload['expenses'] as List<dynamic>? ?? const []);
    final liabilities = (payload['liabilities'] as List<dynamic>? ?? const []);
    final categories = (payload['categories'] as List<dynamic>? ?? const []);
    await database.transaction((txn) async {
      await txn.delete('income');
      await txn.delete('expense');
      await txn.delete('liability');
      await txn.delete('category');
      await txn.update('profile', {
        'name': profile?['name'] ?? '',
        'opening_balance_rials': (profile?['openingBalanceRials'] as num?)?.toInt() ?? 0,
        'opening_balance_date': profile?['openingBalanceDate'],
      }, where: 'id=?', whereArgs: ['local-profile']);
      for (final item in categories) {
        final x = Map<String, dynamic>.from(item as Map);
        await txn.insert('category', {'id': x['id'].toString(), 'title': x['title'].toString()});
      }
      for (final item in incomes) {
        final x = Map<String, dynamic>.from(item as Map);
        await txn.insert('income', {'id': x['id'], 'title': x['title'], 'amount_rials': (x['amountRials'] as num).toInt(), 'frequency': x['frequency'], 'start_date': x['start'], 'pay_day': x['payDay']});
      }
      for (final item in expenses) {
        final x = Map<String, dynamic>.from(item as Map);
        await txn.insert('expense', {'id': x['id'], 'title': x['title'], 'amount_rials': (x['amountRials'] as num).toInt(), 'frequency': x['frequency'], 'category': x['category'], 'date': x['date'], 'start_date': x['startDate'], 'payment_day': x['paymentDay']});
      }
      for (final item in liabilities) {
        final x = Map<String, dynamic>.from(item as Map);
        await txn.insert('liability', {'id': x['id'], 'title': x['title'], 'type': x['type'], 'total_rials': (x['totalRials'] as num).toInt(), 'installment_rials': (x['installmentRials'] as num).toInt(), 'remaining_installments': (x['remainingInstallments'] as num).toInt(), 'frequency': x['frequency'], 'payment_date': x['paymentDate'], 'payment_day': x['paymentDay']});
      }
    });
  }
}
