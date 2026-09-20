class MoneyFormatter {
  const MoneyFormatter._();
  static String toman(int rials) { final n=rials~/10; final d=n.abs().toString().replaceAllMapped(RegExp(r'(?=(\d{3})+(?!\d))'),(_)=>','); return '${n<0?'-':''}$d تومان'; }
  static int tomanToRials(String raw) { final v=raw.replaceAllMapped(RegExp(r'[۰-۹]'),(m)=>'۰۱۲۳۴۵۶۷۸۹'.indexOf(m.group(0)!).toString()).replaceAll(RegExp(r'[,٬\s]|تومان'),''); final n=int.tryParse(v); if(n==null||n<0)throw const FormatException('INVALID_AMOUNT'); return n*10; }
}
