import 'package:flutter_secure_storage/flutter_secure_storage.dart';

class Entitlement {
  const Entitlement({required this.productId, required this.status, this.endsAt, this.usageLimit, this.usageUsed = 0});
  final String productId;
  final String status;
  final DateTime? endsAt;
  final int? usageLimit;
  final int usageUsed;
  bool get active => status == 'active' && (endsAt == null || endsAt!.isAfter(DateTime.now()));
  bool get isPro => active && productId == 'pro';
  bool get aiAllowed => isPro || (usageLimit == null || usageUsed < usageLimit!);
}

class EntitlementService {
  const EntitlementService(this.storage);
  final FlutterSecureStorage storage;
  static const _product = 'finaro.entitlement.product';
  static const _status = 'finaro.entitlement.status';
  static const _ends = 'finaro.entitlement.ends';
  static const _limit = 'finaro.entitlement.limit';
  static const _used = 'finaro.entitlement.ai.used';

  Future<Entitlement> current() async {
    final product = await storage.read(key: _product) ?? 'free';
    final status = await storage.read(key: _status) ?? 'active';
    final endsRaw = await storage.read(key: _ends);
    final limitRaw = await storage.read(key: _limit);
    final used = int.tryParse(await storage.read(key: _used) ?? '0') ?? 0;
    return Entitlement(productId: product, status: status, endsAt: endsRaw == null ? null : DateTime.tryParse(endsRaw), usageLimit: limitRaw == null ? 3 : int.tryParse(limitRaw), usageUsed: used);
  }

  Future<void> consumeAi() async {
    final e = await current();
    if (!e.aiAllowed) throw StateError('سهم استفاده از AI در نسخه رایگان تمام شده است.');
    if (!e.isPro) await storage.write(key: _used, value: '${e.usageUsed + 1}');
  }

  Future<void> activate({required String productId, DateTime? endsAt, int? usageLimit}) async {
    await storage.write(key: _product, value: productId);
    await storage.write(key: _status, value: 'active');
    if (endsAt != null) await storage.write(key: _ends, value: endsAt.toIso8601String()); else await storage.delete(key: _ends);
    if (usageLimit != null) await storage.write(key: _limit, value: '$usageLimit'); else await storage.delete(key: _limit);
    if (productId == 'pro') await storage.delete(key: _used);
  }

  Future<void> setFree() => activate(productId: 'free', usageLimit: 3);
}
