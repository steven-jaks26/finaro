import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import '../../app/providers.dart';
import '../../data/backup/backup_service.dart';
import '../widgets/app_shell.dart';

class BackupScreen extends ConsumerStatefulWidget {
  const BackupScreen({super.key});
  @override
  ConsumerState<BackupScreen> createState() => _BackupScreenState();
}

class _BackupScreenState extends ConsumerState<BackupScreen> {
  final _password = TextEditingController();
  bool _busy = false;
  String? _message;
  bool _error = false;
  BackupInspection? _inspection;

  @override
  void dispose() { _password.dispose(); super.dispose(); }

  BackupService get _service => BackupService(ref.read(repoProvider));

  Future<void> _export() async {
    if (_password.text.length < 8) { _show('رمز عبور باید حداقل ۸ کاراکتر باشد.', true); return; }
    setState(() { _busy = true; _message = null; });
    try {
      final path = await _service.exportEncrypted(password: _password.text);
      if (path != null) _show('نسخه پشتیبان رمزنگاری‌شده ذخیره شد.', false);
    } on BackupException catch (e) { _show(e.message, true); }
    catch (_) { _show('ذخیره نسخه پشتیبان انجام نشد.', true); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _checkHealth() async {
    if (_password.text.length < 8) { _show('برای بررسی کامل سلامت، رمز عبور نسخه پشتیبان را وارد کنید.', true); return; }
    setState(() { _busy = true; _message = null; _inspection = null; });
    try {
      final inspection = await _service.inspectSelected(password: _password.text);
      if (inspection == null) { if (mounted) setState(() => _busy = false); return; }
      setState(() => _inspection = inspection);
      _show(inspection.healthy ? 'نسخه پشتیبان سالم است و محتوای آن با موفقیت بازیابی آزمایشی شد.' : (inspection.error ?? 'نسخه پشتیبان نیاز به بررسی دارد.'), !inspection.healthy);
    } on BackupException catch (e) { _show(e.message, true); }
    catch (_) { _show('بررسی سلامت نسخه پشتیبان انجام نشد.', true); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  Future<void> _restore() async {
    if (_password.text.length < 8) { _show('برای بازیابی، همان رمز عبور نسخه پشتیبان را وارد کنید.', true); return; }
    setState(() { _busy = true; _message = null; });
    try {
      final result = await FilePicker.platform.pickFiles(
        dialogTitle: 'انتخاب نسخه پشتیبان برای Recovery', type: FileType.custom,
        allowedExtensions: const ['finaro'], withData: true,
      );
      if (result == null || result.files.single.bytes == null) { if (mounted) setState(() => _busy = false); return; }
      final bytes = Uint8List.fromList(result.files.single.bytes!);
      final inspection = await _service.inspectBytes(bytes, password: _password.text);
      if (!inspection.healthy) {
        _show(inspection.error ?? 'این نسخه پشتیبان برای بازیابی معتبر نیست.', true);
        return;
      }
      if (!mounted) return;
      final confirm = await showDialog<bool>(context: context, builder: (c) => AlertDialog(
        title: const Text('Recovery ایمن'),
        content: Text('این فایل سالم است و ${inspection.recordCount} رکورد دارد. اطلاعات فعلی با اطلاعات آن جایگزین می‌شود. قبل از بازیابی، از اطلاعات فعلی نسخه پشتیبان بگیرید. ادامه می‌دهید؟'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('انصراف')),
          FilledButton(onPressed: () => Navigator.pop(c, true), child: const Text('تأیید بازیابی')),
        ],
      ));
      if (confirm != true) return;
      await _service.restoreBytes(bytes, password: _password.text);
      ref.invalidate(profileProvider); ref.invalidate(incomesProvider); ref.invalidate(expensesProvider); ref.invalidate(liabilitiesProvider); ref.invalidate(categoriesProvider);
      _show('Recovery با موفقیت انجام شد. اطلاعات بازیابی‌شده از نظر ساختاری معتبر بود.', false);
    } on BackupException catch (e) { _show(e.message, true); }
    catch (_) { _show('بازیابی نسخه پشتیبان انجام نشد؛ اطلاعات فعلی بدون تغییر باقی ماند.', true); }
    finally { if (mounted) setState(() => _busy = false); }
  }

  void _show(String text, bool error) { if (!mounted) return; setState(() { _message = text; _error = error; }); }

  @override
  Widget build(BuildContext context) => AppShell(
    title: 'پشتیبان‌گیری و بازیابی', index: 3,
    child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
      FinaroCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        const Icon(Icons.health_and_safety_outlined, size: 44),
        const SizedBox(height: 10),
        const Text('سلامت و Recovery', textAlign: TextAlign.center, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
        const SizedBox(height: 6),
        Text('قبل از بازیابی، فایل بررسی می‌شود: ساختار، checksum، رمزگشایی و ساختار داده. هیچ فایل نامعتبر وارد پایگاه داده نمی‌شود.', textAlign: TextAlign.center, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
        const SizedBox(height: 16),
        TextField(controller: _password, obscureText: true, decoration: const InputDecoration(labelText: 'رمز عبور نسخه پشتیبان', hintText: 'حداقل ۸ کاراکتر', prefixIcon: Icon(Icons.password_outlined))),
        const SizedBox(height: 12),
        Row(children: [
          Expanded(child: FilledButton.icon(onPressed: _busy ? null : _export, icon: const Icon(Icons.upload_file), label: const Text('ساخت بکاپ'))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : _checkHealth, icon: const Icon(Icons.fact_check_outlined), label: const Text('بررسی سلامت'))),
          const SizedBox(width: 8),
          Expanded(child: OutlinedButton.icon(onPressed: _busy ? null : _restore, icon: const Icon(Icons.restore), label: const Text('Recovery'))),
        ]),
        if (_busy) const Padding(padding: EdgeInsets.only(top: 14), child: LinearProgressIndicator()),
        if (_message != null) ...[const SizedBox(height: 12), StatusBanner(icon: Icons.info_outline, title: _error ? 'نیاز به بررسی' : 'تأیید شد', message: _message!, tone: Colors.blue)],
      ])),
      if (_inspection != null) ...[
        const SizedBox(height: 14),
        FinaroCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          const Text('گزارش سلامت فایل', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
          const SizedBox(height: 10),
          _row('ساختار فایل', _inspection!.validEnvelope ? 'معتبر' : 'نامعتبر'),
          _row('یکپارچگی checksum', _inspection!.checksumValid ? 'تأیید شد' : 'رد شد'),
          _row('رمزگشایی', _inspection!.decrypted ? 'موفق' : 'ناموفق'),
          _row('نسخه ساختار داده', _inspection!.schemaVersion?.toString() ?? '—'),
          _row('تعداد رکوردها', _inspection!.recordCount.toString()),
          _row('درآمد', _inspection!.incomeCount.toString()),
          _row('هزینه', _inspection!.expenseCount.toString()),
          _row('تعهد', _inspection!.liabilityCount.toString()),
          _row('دسته‌بندی', _inspection!.categoryCount.toString()),
          _row('حجم فایل', '${_inspection!.fileBytes} بایت'),
          if (_inspection!.createdAt != null) _row('تاریخ ایجاد', _inspection!.createdAt!),
        ])),
      ],
      const SizedBox(height: 14),
      const FinaroCard(child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('قواعد Recovery', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        SizedBox(height: 8),
        Text('۱. فایل ابتدا از نظر ساختار و checksum بررسی می‌شود.'),
        Text('۲. سپس رمزگشایی و اعتبارسنجی ساختار داده انجام می‌شود.'),
        Text('۳. فقط فایل سالم اجازه ورود به پایگاه داده را دارد.'),
        Text('۴. جایگزینی اطلاعات داخل تراکنش دیتابیس انجام می‌شود؛ خطای تراکنش باعث باقی‌ماندن اطلاعات قبلی می‌شود.'),
        SizedBox(height: 6),
        Text('برای جلوگیری از از دست رفتن آخرین تغییرات، قبل از Recovery از وضعیت فعلی یک بکاپ جدید بگیرید.'),
      ])),
    ]),
  );

  Widget _row(String label, String value) => Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Expanded(child: Text(label)), Text(value, style: const TextStyle(fontWeight: FontWeight.w700))]));
}
