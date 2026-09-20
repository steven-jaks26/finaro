import 'dart:convert';
import 'package:http/http.dart' as http;

class AiGatewayConfig {
  const AiGatewayConfig({required this.baseUrl, this.apiKey = '', this.model = ''});
  final String baseUrl;
  final String apiKey;
  final String model;
  bool get configured => baseUrl.trim().isNotEmpty;
}

class AiGatewayException implements Exception {
  const AiGatewayException(this.message);
  final String message;
  @override String toString() => message;
}

class AiGateway {
  const AiGateway(this.config);
  final AiGatewayConfig config;

  Future<Map<String, dynamic>> smartInput(String text) => _post('/api/v1/ai/smart-input/parse', {'text': text, 'model': config.model});
  Future<Map<String, dynamic>> scenarioParse(String text) => _post('/api/v1/ai/scenario/parse', {'text': text, 'model': config.model});
  Future<Map<String, dynamic>> explain(Map<String, dynamic> payload) => _post('/api/v1/ai/explain', payload);

  Future<Map<String, dynamic>> _post(String path, Map<String, dynamic> body) async {
    if (!config.configured) throw const AiGatewayException('AI Gateway تنظیم نشده است.');
    final base = config.baseUrl.replaceFirst(RegExp(r'/$'), '');
    final uri = Uri.tryParse('$base$path');
    if (uri == null) throw const AiGatewayException('آدرس AI Gateway نامعتبر است.');
    final headers = <String, String>{'content-type': 'application/json'};
    if (config.apiKey.trim().isNotEmpty) headers['authorization'] = 'Bearer ${config.apiKey.trim()}';
    final response = await http.post(uri, headers: headers, body: jsonEncode(body)).timeout(const Duration(seconds: 20));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AiGatewayException('AI Gateway پاسخ ${response.statusCode} برگرداند.');
    }
    final decoded = jsonDecode(response.body);
    if (decoded is! Map) throw const AiGatewayException('پاسخ AI ساختار معتبری ندارد.');
    return Map<String, dynamic>.from(decoded as Map);
  }
}
