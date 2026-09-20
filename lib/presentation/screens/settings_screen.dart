import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers.dart';
import '../../data/ai/ai_gateway.dart';
import '../widgets/app_shell.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});
  @override ConsumerState<SettingsScreen> createState()=>_SettingsState();
}

class _SettingsState extends ConsumerState<SettingsScreen> {
  final _url=TextEditingController(); final _key=TextEditingController(); final _model=TextEditingController();
  @override void dispose(){_url.dispose();_key.dispose();_model.dispose();super.dispose();}
  Future<void> _load() async { final s=ref.read(storageProvider); _url.text=await s.read(key:'finaro.ai.url')??''; _key.text=await s.read(key:'finaro.ai.key')??''; _model.text=await s.read(key:'finaro.ai.model')??''; if(mounted)setState((){}); }
  Future<void> _saveAi() async { final s=ref.read(storageProvider); await s.write(key:'finaro.ai.url',value:_url.text.trim()); await s.write(key:'finaro.ai.key',value:_key.text.trim()); await s.write(key:'finaro.ai.model',value:_model.text.trim()); ref.read(aiConfigProvider.notifier).state=AiGatewayConfig(baseUrl:_url.text.trim(),apiKey:_key.text.trim(),model:_model.text.trim()); if(mounted)ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content:Text('تنظیمات AI ذخیره شد.'))); }
  @override void initState(){super.initState();_load();}
  @override Widget build(BuildContext context) {
    return AppShell(
      title: 'پروفایل و تنظیمات',
      index: 3,
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        FinaroCard(child: Column(children: [
          const CircleAvatar(radius: 32, child: Icon(Icons.person_outline, size: 32)),
          const SizedBox(height: 10),
          const Text('حساب محلی Finaro', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 3),
          Text('داده‌های مالی شما در این دستگاه نگهداری می‌شوند.', style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant, fontSize: 12)),
        ])),
        const SizedBox(height: 14),
        FinaroCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('ابزارهای مهم', style: TextStyle(fontWeight: FontWeight.w900)),
          ListTile(leading: const Icon(Icons.auto_awesome), title: const Text('ثبت هوشمند'), subtitle: const Text('ثبت با زبان طبیعی و پیش‌نمایش قبل از ذخیره'), trailing: const Icon(Icons.chevron_left), onTap: () => context.go('/smart-input')),
          ListTile(leading: const Icon(Icons.backup_outlined), title: const Text('پشتیبان‌گیری'), subtitle: const Text('وضعیت نسخه پشتیبان رمزگذاری‌شده'), trailing: const Icon(Icons.chevron_left), onTap: () => context.go('/backup')),
          ListTile(leading: const Icon(Icons.workspace_premium_outlined), title: const Text('اشتراک Finaro'), subtitle: const Text('وضعیت دسترسی و امکانات'), trailing: const Icon(Icons.chevron_left), onTap: () => context.go('/subscription')),
        ])),
        const SizedBox(height: 14),
        FinaroCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('اتصال AI', style: TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 8),
          const Text('کلید و آدرس فقط در Secure Storage دستگاه نگهداری می‌شوند. AI محاسبه مالی انجام نمی‌دهد.', style: TextStyle(fontSize: 12)),
          const SizedBox(height: 10),
          TextField(controller:_url, decoration:const InputDecoration(labelText:'Base URL / API Gateway')),
          const SizedBox(height:8),
          TextField(controller:_model, decoration:const InputDecoration(labelText:'Model')),
          const SizedBox(height:8),
          TextField(controller:_key, obscureText:true, decoration:const InputDecoration(labelText:'API Key')),
          const SizedBox(height:10),
          FilledButton.icon(onPressed:_saveAi, icon:const Icon(Icons.save_outlined), label:const Text('ذخیره تنظیمات AI')),
        ])),
        const SizedBox(height: 14),
        FinaroCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('امنیت و تجربه', style: TextStyle(fontWeight: FontWeight.w900)),
          const ListTile(leading: Icon(Icons.lock_outline), title: Text('حریم خصوصی'), subtitle: Text('پایگاه داده محلی با SQLCipher رمزگذاری می‌شود.')),
          const ListTile(leading: Icon(Icons.cloud_off), title: Text('حالت آفلاین'), subtitle: Text('ثبت مالی اصلی بدون اینترنت در دسترس است.')),
          const ListTile(leading: Icon(Icons.palette_outlined), title: Text('ظاهر'), subtitle: Text('Material 3، RTL و طراحی مناسب موبایل')),
        ])),
        const SizedBox(height: 14),
        OutlinedButton.icon(onPressed: () async { await ref.read(sessionProvider).signOut(); if (context.mounted) context.go('/login'); }, icon: const Icon(Icons.logout), label: const Text('خروج از حساب')),
      ]),
    );
  }
}
