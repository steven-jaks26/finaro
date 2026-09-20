import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../app/providers.dart';
import '../../data/billing/entitlement_service.dart';
import '../widgets/app_shell.dart';

class SubscriptionScreen extends ConsumerWidget {
  const SubscriptionScreen({super.key});
  @override Widget build(BuildContext context, WidgetRef ref) {
    final entitlement=ref.watch(entitlementProvider);
    return AppShell(title:'اشتراک Finaro',index:3,child:entitlement.when(
      loading:()=>const Center(child:CircularProgressIndicator()),
      error:(e,_)=>Text('خطا در خواندن وضعیت دسترسی: $e'),
      data:(e)=>Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
        FinaroCard(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[
          const Text('وضعیت دسترسی',style:TextStyle(fontSize:12)),const SizedBox(height:5),
          Text(e.isPro?'Finaro Pro':'Finaro Free',style:const TextStyle(fontSize:26,fontWeight:FontWeight.w900)),
          const SizedBox(height:6),Text(e.isPro?'دسترسی حرفه‌ای فعال است.':'نسخه رایگان فعال است؛ امکانات پایه بدون خرید قابل استفاده‌اند.',style:TextStyle(fontSize:13)),
          const SizedBox(height:14),StatusBanner(icon:e.isPro?Icons.workspace_premium:Icons.check_circle_outline,title:e.isPro?'Pro فعال':'رایگان فعال',message:e.isPro?'AI بدون سهم آزمایشی محدود قابل استفاده است.':'۳ استفاده آزمایشی AI در این دستگاه در نظر گرفته شده است.',tone:e.isPro?Colors.green:Colors.blue),
        ])),const SizedBox(height:14),
        FinaroCard(child:Column(crossAxisAlignment:CrossAxisAlignment.stretch,children:[const SectionHeader(title:'قابلیت‌ها'),...['Forecast و What-If','Backup و Recovery امن','Smart Input محلی','AI Gateway و Smart Input پیشرفته','گزارش‌ها و امکانات حرفه‌ای'].map((x)=>ListTile(contentPadding:EdgeInsets.zero,leading:Icon(Icons.check_circle_outline,color:x.contains('AI')&&!e.isPro?Theme.of(context).colorScheme.onSurfaceVariant:null),title:Text(x),subtitle:x.contains('AI')?Text(e.isPro?'فعال':'نسخه رایگان: ۳ بار آزمایشی'):null))])),
        const SizedBox(height:14),
        const StatusBanner(icon:Icons.info_outline,title:'پرداخت فروشگاهی',message:'اتصال واقعی به Google Play Billing / App Store هنوز انجام نشده است. این صفحه Entitlement را واقعی و بدون جعل تراکنش مدیریت می‌کند؛ فعال‌سازی فروشگاهی در مرحله انتشار متصل می‌شود.',tone:Colors.orange),
      ]),
    ));
  }
}
