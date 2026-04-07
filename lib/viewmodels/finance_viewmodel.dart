import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../config/google_sheets_sync_config.dart';
import '../database/db_helper.dart';
import '../models/transaction.dart';
import '../services/google_sheets_sync_service.dart';

class FinanceViewModel extends ChangeNotifier {
  static const String accountWallet = 'Dompet';
  static const String accountDigital = 'ATM/E-Wallet';
  static const String transferCategory = 'Transfer Internal';

  static const _kSyncEnabled = 'sync_enabled';
  static const _kSyncWebhookUrl = 'sync_webhook_url';
  static const _kSyncSecret = 'sync_secret';

  final GoogleSheetsSyncService _sheetsSyncService = GoogleSheetsSyncService();

  List<TransactionModel> _transactions = [];

  bool _isSyncing = false;
  DateTime? _lastSyncAt;
  String? _lastSyncError;

  bool _syncEnabled = GoogleSheetsSyncConfig.enabled;
  String _syncWebhookUrl = GoogleSheetsSyncConfig.webhookUrl;
  String _syncSecret = GoogleSheetsSyncConfig.secret;
  bool _syncSettingsLoaded = false;

  List<TransactionModel> get transactions => _transactions;

  bool get isSyncing => _isSyncing;
  DateTime? get lastSyncAt => _lastSyncAt;
  String? get lastSyncError => _lastSyncError;

  bool get syncEnabled => _syncEnabled;
  String get syncWebhookUrl => _syncWebhookUrl;
  String get syncSecret => _syncSecret;
  bool get syncSettingsLoaded => _syncSettingsLoaded;

  bool get isSheetsSyncConfigured => GoogleSheetsSyncService.isConfigured(
    enabled: _syncEnabled,
    webhookUrl: _syncWebhookUrl,
  );

  Future<void> initialize() async {
    await Future.wait([fetchTransactions(), loadSyncSettings()]);
  }

  bool _isTransfer(TransactionModel t) => t.category == transferCategory;

  double get income => _transactions
      .where((t) => t.type == 'INCOME' && !_isTransfer(t))
      .fold(0, (sum, item) => sum + item.amount);

  double get expense => _transactions
      .where((t) => t.type == 'EXPENSE' && !_isTransfer(t))
      .fold(0, (sum, item) => sum + item.amount);

  double get totalBalance =>
      _accountBalance(accountWallet) + _accountBalance(accountDigital);

  double get walletBalance => _accountBalance(accountWallet);
  double get digitalBalance => _accountBalance(accountDigital);

  double _accountBalance(String account) {
    double balance = 0;
    for (final t in _transactions.where((trx) => trx.account == account)) {
      if (t.type == 'INCOME') balance += t.amount;
      if (t.type == 'EXPENSE') balance -= t.amount;
    }
    return balance;
  }

  Future<void> loadSyncSettings() async {
    final prefs = await SharedPreferences.getInstance();

    _syncEnabled =
        prefs.getBool(_kSyncEnabled) ?? GoogleSheetsSyncConfig.enabled;
    _syncWebhookUrl =
        prefs.getString(_kSyncWebhookUrl) ?? GoogleSheetsSyncConfig.webhookUrl;
    _syncSecret =
        prefs.getString(_kSyncSecret) ?? GoogleSheetsSyncConfig.secret;
    _syncSettingsLoaded = true;
    notifyListeners();
  }

  Future<void> updateSyncSettings({
    required bool enabled,
    required String webhookUrl,
    required String secret,
  }) async {
    final cleanedUrl = webhookUrl.trim();

    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kSyncEnabled, enabled);
    await prefs.setString(_kSyncWebhookUrl, cleanedUrl);
    await prefs.setString(_kSyncSecret, secret.trim());

    _syncEnabled = enabled;
    _syncWebhookUrl = cleanedUrl;
    _syncSecret = secret.trim();
    notifyListeners();
  }

  Future<void> syncToGoogleSheets() async {
    if (!isSheetsSyncConfigured) {
      throw Exception('Sync belum aktif. Isi webhook URL dan aktifkan sync.');
    }

    if (_isSyncing) return;

    _isSyncing = true;
    _lastSyncError = null;
    notifyListeners();

    try {
      await _sheetsSyncService.syncAll(
        transactions: _transactions,
        totalBalance: totalBalance,
        walletBalance: walletBalance,
        digitalBalance: digitalBalance,
        income: income,
        expense: expense,
        enabled: _syncEnabled,
        webhookUrl: _syncWebhookUrl,
        secret: _syncSecret,
      );
      _lastSyncAt = DateTime.now();
    } catch (e) {
      _lastSyncError = e.toString();
      rethrow;
    } finally {
      _isSyncing = false;
      notifyListeners();
    }
  }

  Future<void> _autoSyncToSheets() async {
    if (!isSheetsSyncConfigured) return;

    try {
      await syncToGoogleSheets();
    } catch (_) {
      // best-effort
    }
  }

  Future<void> fetchTransactions() async {
    _transactions = await DbHelper.instance.getAll();
    notifyListeners();
  }

  Future<void> addTransaction(
    String title,
    double amount,
    bool isIncome,
    String category,
    String account,
  ) async {
    await DbHelper.instance.insert(
      TransactionModel(
        title: title,
        amount: amount,
        type: isIncome ? 'INCOME' : 'EXPENSE',
        category: category,
        account: account,
        date: DateTime.now(),
      ),
    );

    await fetchTransactions();
    unawaited(_autoSyncToSheets());
  }

  Future<void> transferBetweenAccounts({
    required double amount,
    required String fromAccount,
    required String toAccount,
    String? note,
  }) async {
    if (amount <= 0 || fromAccount == toAccount) return;

    final now = DateTime.now();
    final noteSuffix = (note != null && note.trim().isNotEmpty)
        ? ' (${note.trim()})'
        : '';

    await DbHelper.instance.insert(
      TransactionModel(
        title: 'Transfer ke $toAccount$noteSuffix',
        amount: amount,
        type: 'EXPENSE',
        category: transferCategory,
        account: fromAccount,
        date: now,
      ),
    );

    await DbHelper.instance.insert(
      TransactionModel(
        title: 'Transfer dari $fromAccount$noteSuffix',
        amount: amount,
        type: 'INCOME',
        category: transferCategory,
        account: toAccount,
        date: now,
      ),
    );

    await fetchTransactions();
    unawaited(_autoSyncToSheets());
  }

  Future<void> deleteTransaction(int id) async {
    await DbHelper.instance.delete(id);
    await fetchTransactions();
    unawaited(_autoSyncToSheets());
  }
}
