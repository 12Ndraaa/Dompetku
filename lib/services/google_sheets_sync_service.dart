import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/transaction.dart';

class GoogleSheetsSyncService {
  static bool isConfigured({
    required bool enabled,
    required String webhookUrl,
  }) {
    return enabled && webhookUrl.trim().isNotEmpty;
  }

  Future<void> syncAll({
    required List<TransactionModel> transactions,
    required double totalBalance,
    required double walletBalance,
    required double digitalBalance,
    required double income,
    required double expense,
    required bool enabled,
    required String webhookUrl,
    required String secret,
  }) async {
    if (!isConfigured(enabled: enabled, webhookUrl: webhookUrl)) {
      throw Exception(
        'Sync belum dikonfigurasi. Isi webhook URL lalu aktifkan sync.',
      );
    }

    final uri = Uri.parse(webhookUrl.trim());

    final body = {
      'secret': secret,
      'generatedAt': DateTime.now().toIso8601String(),
      'summary': {
        'totalBalance': totalBalance,
        'walletBalance': walletBalance,
        'digitalBalance': digitalBalance,
        'income': income,
        'expense': expense,
      },
      'transactions': transactions
          .map(
            (t) => {
              'id': t.id,
              'title': t.title,
              'amount': t.amount,
              'type': t.type,
              'category': t.category,
              'account': t.account,
              'date': t.date.toIso8601String(),
            },
          )
          .toList(),
    };

    http.Response response = await http
        .post(
          uri,
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        )
        .timeout(const Duration(seconds: 25));

    // Apps Script bisa balas 302 ke googleusercontent
    if (response.statusCode >= 300 && response.statusCode < 400) {
      final location = response.headers['location'];
      if (location == null || location.isEmpty) {
        throw Exception(
          'Sync gagal [${response.statusCode}] tanpa header location.',
        );
      }

      final redirectedUri = uri.resolve(location);
      response = await http
          .get(redirectedUri, headers: {'Accept': 'application/json'})
          .timeout(const Duration(seconds: 25));
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw Exception('Sync gagal [${response.statusCode}] ${response.body}');
    }

    dynamic decoded;
    try {
      decoded = jsonDecode(response.body);
    } catch (_) {
      final preview = response.body.length > 180
          ? '${response.body.substring(0, 180)}...'
          : response.body;
      throw Exception('Webhook tidak mengembalikan JSON valid: $preview');
    }

    if (decoded is Map && decoded['ok'] == false) {
      throw Exception(
        'Sync ditolak webhook: ${decoded['message'] ?? 'unknown error'}',
      );
    }

    if (decoded is Map &&
        (decoded['message']?.toString().toLowerCase() == 'alive')) {
      throw Exception(
        'Webhook masih mode test (alive). Ganti doPost ke versi yang menulis spreadsheet.',
      );
    }
  }
}
