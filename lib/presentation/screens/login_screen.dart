import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../app/providers.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override ConsumerState<LoginScreen> createState() => _LoginState();
}

class _LoginState extends ConsumerState<LoginScreen> {
  final phone = TextEditingController();
  final otp = TextEditingController();
  bool requested = false;
  bool loading = false;

  @override void dispose() { phone.dispose(); otp.dispose(); super.dispose(); }

  Future<void> submit() async {
    if (!requested) {
      if (phone.text.trim().length < 8) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('شماره موبایل را کامل وارد کنید.')));
        return;
      }
      setState(() => requested = true);
      return;
    }
    if (otp.text.trim() != '1111') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('کد آزمایشی صحیح: ۱۱۱۱')));
      return;
    }
    setState(() => loading = true);
    await ref.read(sessionProvider).signIn(phone.text.trim());
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(22),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 460),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(width: 68, height: 68, alignment: Alignment.center, decoration: BoxDecoration(color: scheme.primaryContainer, borderRadius: BorderRadius.circular(22)), child: Text('F', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: scheme.onPrimaryContainer))),
                    const SizedBox(height: 18),
                    const Text('فینارو', style: TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 5),
                    Text('قبل از اینکه تصمیم مالی بگیری، آینده‌اش را ببین.', style: TextStyle(fontSize: 14, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 24),
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                          Text(requested ? 'کد تأیید را وارد کنید' : 'شروع استفاده از فینارو', style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900)),
                          const SizedBox(height: 5),
                          Text(requested ? 'کد ارسال‌شده برای شماره واردشده را وارد کنید.' : 'شماره موبایل برای ساخت جلسه محلی آزمایشی استفاده می‌شود.', style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 12)),
                          const SizedBox(height: 18),
                          TextField(controller: phone, enabled: !requested && !loading, keyboardType: TextInputType.phone, decoration: const InputDecoration(labelText: 'شماره موبایل', prefixIcon: Icon(Icons.phone_outlined))),
                          if (requested) ...[
                            const SizedBox(height: 12),
                            TextField(controller: otp, enabled: !loading, keyboardType: TextInputType.number, maxLength: 4, textAlign: TextAlign.center, decoration: const InputDecoration(labelText: 'کد تأیید', prefixIcon: Icon(Icons.verified_outlined), counterText: '')),
                            const SizedBox(height: 4),
                            Text('در نسخه آزمایشی: ۱۱۱۱', textAlign: TextAlign.center, style: TextStyle(color: scheme.primary, fontSize: 12, fontWeight: FontWeight.w700)),
                          ],
                          const SizedBox(height: 16),
                          FilledButton.icon(onPressed: loading ? null : submit, icon: loading ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.arrow_forward), label: Text(requested ? 'ورود به فینارو' : 'دریافت کد تأیید')),
                          if (requested) ...[const SizedBox(height: 8), TextButton(onPressed: loading ? null : () => setState(() { requested = false; otp.clear(); }), child: const Text('تغییر شماره'))],
                        ]),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(mainAxisAlignment: MainAxisAlignment.center, children: [Icon(Icons.lock_outline, size: 16, color: scheme.onSurfaceVariant), const SizedBox(width: 6), Flexible(child: Text('اطلاعات مالی روی دستگاه رمزگذاری می‌شود', textAlign: TextAlign.center, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)))]),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
