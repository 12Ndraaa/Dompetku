import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/transaction.dart';
import '../viewmodels/finance_viewmodel.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  final NumberFormat _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp ',
    decimalDigits: 0,
  );

  String _searchQuery = '';
  String _typeFilter = 'ALL';
  String _accountFilter = 'ALL';

  static const List<String> _expenseCategories = [
    'Makanan',
    'Transport',
    'Belanja',
    'Kesehatan',
    'Hiburan',
    'Tagihan',
    'Pendidikan',
    'Umum',
  ];

  static const List<String> _incomeCategories = [
    'Gaji',
    'Bonus',
    'Investasi',
    'Hadiah',
    'Umum',
  ];

  @override
  Widget build(BuildContext context) {
    final vm = context.watch<FinanceViewModel>();

    final q = _searchQuery.trim().toLowerCase();
    final hasQuery = q.isNotEmpty;

    final filtered = vm.transactions.where((t) {
      final matchSearch =
          !hasQuery ||
          t.title.toLowerCase().contains(q) ||
          t.category.toLowerCase().contains(q) ||
          t.account.toLowerCase().contains(q);
      final matchType = _typeFilter == 'ALL' || t.type == _typeFilter;
      final matchAccount =
          _accountFilter == 'ALL' || t.account == _accountFilter;
      return matchSearch && matchType && matchAccount;
    }).toList();

    final showSyncSetup = !vm.isSheetsSyncConfigured;
    final headerCount = (showSyncSetup ? 2 : 0) + 4;
    final itemCount = headerCount + (filtered.isEmpty ? 1 : filtered.length);

    return Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        title: const Text('Dompetku'),
        actions: [
          IconButton(
            tooltip: 'Pengaturan Sync',
            onPressed: () => _showSyncSettingsSheet(context, vm),
            icon: const Icon(Icons.settings_rounded),
          ),
          IconButton(
            tooltip: 'Transfer Antar Akun',
            onPressed: () => _showTransferDialog(context, vm),
            icon: const Icon(Icons.swap_horiz_rounded),
          ),
          IconButton(
            tooltip: 'Sync Google Sheets',
            onPressed: vm.isSyncing ? null : () => _syncNow(context, vm),
            icon: vm.isSyncing
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.cloud_upload_rounded),
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          const Positioned.fill(child: _AmbientBackground()),
          RefreshIndicator(
            onRefresh: vm.fetchTransactions,
            child: ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              itemCount: itemCount,
              itemBuilder: (context, index) {
                var i = index;

                if (showSyncSetup) {
                  if (i == 0) return _buildSyncSetupCard(vm);
                  if (i == 1) return const SizedBox(height: 10);
                  i -= 2;
                }

                if (i == 0) return _buildSummaryCard(vm);
                if (i == 1) return const SizedBox(height: 12);
                if (i == 2) return _buildFilterCard();
                if (i == 3) return const SizedBox(height: 12);

                i -= 4;

                if (filtered.isEmpty) {
                  return _buildEmptyState(vm.transactions.isEmpty);
                }

                return _buildTransactionTile(filtered[i], vm);
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showAddTransactionSheet(context),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
    );
  }

  Widget _glassCard({
    required Widget child,
    EdgeInsetsGeometry margin = EdgeInsets.zero,
  }) {
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: const Color(0xFF0F172A).withValues(alpha: 0.82),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: child,
    );
  }

  Widget _buildSyncSetupCard(FinanceViewModel vm) {
    return _glassCard(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(Icons.info_outline_rounded, color: Colors.amber),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Sync belum diaktifkan',
                    style: TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 4),
                  const Text(
                    'Supaya pengguna lain bisa langsung pakai, isi webhook URL dari HP ini.',
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 8),
                  OutlinedButton.icon(
                    onPressed: () => _showSyncSettingsSheet(context, vm),
                    icon: const Icon(Icons.settings_rounded),
                    label: const Text('Setup Sync'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _syncNow(BuildContext context, FinanceViewModel vm) async {
    final messenger = ScaffoldMessenger.of(context);

    if (!vm.isSheetsSyncConfigured) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Sync belum aktif. Silakan setup dulu.')),
      );
      await _showSyncSettingsSheet(context, vm);
      return;
    }

    try {
      await vm.syncToGoogleSheets();
      messenger.showSnackBar(
        const SnackBar(content: Text('Data berhasil disinkronkan.')),
      );
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Sync gagal: $e')));
    }
  }

  Future<void> _showSyncSettingsSheet(
    BuildContext context,
    FinanceViewModel vm,
  ) async {
    bool enabled = vm.syncEnabled;
    final webhookCtrl = TextEditingController(text: vm.syncWebhookUrl);
    final secretCtrl = TextEditingController(text: vm.syncSecret);

    final messenger = ScaffoldMessenger.of(context);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setStateModal) {
            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Pengaturan Sync Google Sheets',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),
                  SwitchListTile(
                    value: enabled,
                    onChanged: (v) => setStateModal(() => enabled = v),
                    title: const Text('Aktifkan Sync'),
                    contentPadding: EdgeInsets.zero,
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: webhookCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Webhook URL Apps Script',
                      border: OutlineInputBorder(),
                      hintText: 'https://script.google.com/macros/s/.../exec',
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: secretCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Secret (opsional)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.save_rounded),
                      onPressed: () async {
                        final url = webhookCtrl.text.trim();
                        if (enabled &&
                            (url.isEmpty ||
                                (!url.startsWith('http://') &&
                                    !url.startsWith('https://')))) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text('Webhook URL tidak valid.'),
                            ),
                          );
                          return;
                        }

                        await vm.updateSyncSettings(
                          enabled: enabled,
                          webhookUrl: url,
                          secret: secretCtrl.text,
                        );

                        if (!mounted) return;
                        Navigator.pop(ctx);
                        messenger.showSnackBar(
                          const SnackBar(
                            content: Text('Pengaturan sync berhasil disimpan.'),
                          ),
                        );
                      },
                      label: const Text('Simpan Pengaturan'),
                    ),
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Widget _buildSummaryCard(FinanceViewModel vm) {
    final totalColor = vm.totalBalance >= 0
        ? Colors.greenAccent
        : Colors.redAccent;

    return _glassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Ringkasan Keuangan',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _currency.format(vm.totalBalance),
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: totalColor,
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: _miniInfo(
                    'Income',
                    _currency.format(vm.income),
                    Colors.greenAccent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _miniInfo(
                    'Expense',
                    _currency.format(vm.expense),
                    Colors.redAccent,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: _miniInfo(
                    FinanceViewModel.accountWallet,
                    _currency.format(vm.walletBalance),
                    Colors.orangeAccent,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _miniInfo(
                    FinanceViewModel.accountDigital,
                    _currency.format(vm.digitalBalance),
                    Colors.lightBlueAccent,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _miniInfo(String label, String value, Color color) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: color.withAlpha(30),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withAlpha(90)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: TextStyle(color: color, fontSize: 12)),
          const SizedBox(height: 3),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterCard() {
    return _glassCard(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            TextField(
              onChanged: (v) => setState(() => _searchQuery = v),
              decoration: InputDecoration(
                hintText: 'Cari transaksi...',
                prefixIcon: const Icon(Icons.search),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _typeChip('ALL'),
                  _typeChip('INCOME'),
                  _typeChip('EXPENSE'),
                ],
              ),
            ),
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                children: [
                  _accountChip('ALL'),
                  _accountChip(FinanceViewModel.accountWallet),
                  _accountChip(FinanceViewModel.accountDigital),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _typeChip(String type) {
    final active = _typeFilter == type;
    return ChoiceChip(
      label: Text(type),
      selected: active,
      onSelected: (_) => setState(() => _typeFilter = type),
    );
  }

  Widget _accountChip(String account) {
    final active = _accountFilter == account;
    return ChoiceChip(
      label: Text(account),
      selected: active,
      onSelected: (_) => setState(() => _accountFilter = account),
    );
  }

  Widget _buildEmptyState(bool noTransactionAtAll) {
    return _glassCard(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.inbox_rounded, size: 44, color: Colors.grey),
            const SizedBox(height: 8),
            Text(
              noTransactionAtAll
                  ? 'Belum ada transaksi. Tambah transaksi pertama kamu.'
                  : 'Tidak ada transaksi yang sesuai filter.',
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionTile(TransactionModel trx, FinanceViewModel vm) {
    final isIncome = trx.type == 'INCOME';

    return Dismissible(
      key: ValueKey('trx_${trx.id}'),
      direction: DismissDirection.endToStart,
      background: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: Colors.red.withAlpha(40),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.only(right: 18),
        child: const Icon(Icons.delete_outline, color: Colors.redAccent),
      ),
      onDismissed: (_) {
        if (trx.id != null) {
          vm.deleteTransaction(trx.id!);
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Transaksi dihapus')));
        }
      },
      child: _glassCard(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          title: Text(
            trx.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(fontWeight: FontWeight.w600),
          ),
          subtitle: Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                _metaBadge(trx.category),
                _metaBadge(trx.account),
                Text(
                  DateFormat('dd MMM yyyy, HH:mm').format(trx.date),
                  style: const TextStyle(fontSize: 12, color: Colors.white70),
                ),
              ],
            ),
          ),
          trailing: Text(
            '${isIncome ? '+' : '-'} ${_currency.format(trx.amount)}',
            style: TextStyle(
              color: isIncome ? Colors.greenAccent : Colors.redAccent,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }

  Widget _metaBadge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(30),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(label, style: const TextStyle(fontSize: 11)),
    );
  }

  Future<void> _showAddTransactionSheet(BuildContext context) async {
    final titleCtrl = TextEditingController();
    final amountCtrl = TextEditingController();

    bool isIncome = false;
    String selectedAccount = FinanceViewModel.accountWallet;
    String selectedCategory = 'Umum';

    final messenger = ScaffoldMessenger.of(context);

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setModalState) {
            final activeCats = isIncome
                ? _incomeCategories
                : _expenseCategories;
            if (!activeCats.contains(selectedCategory)) {
              selectedCategory = 'Umum';
            }

            return Padding(
              padding: EdgeInsets.only(
                left: 16,
                right: 16,
                top: 16,
                bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'Tambah Transaksi',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Deskripsi',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Nominal',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 8),
                  SegmentedButton<bool>(
                    segments: const [
                      ButtonSegment<bool>(
                        value: false,
                        label: Text('Expense'),
                        icon: Icon(Icons.arrow_upward_rounded),
                      ),
                      ButtonSegment<bool>(
                        value: true,
                        label: Text('Income'),
                        icon: Icon(Icons.arrow_downward_rounded),
                      ),
                    ],
                    selected: {isIncome},
                    onSelectionChanged: (set) {
                      setModalState(() => isIncome = set.first);
                    },
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedAccount,
                    decoration: const InputDecoration(
                      labelText: 'Akun',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(
                        value: FinanceViewModel.accountWallet,
                        child: Text(FinanceViewModel.accountWallet),
                      ),
                      DropdownMenuItem(
                        value: FinanceViewModel.accountDigital,
                        child: Text(FinanceViewModel.accountDigital),
                      ),
                    ],
                    onChanged: (v) => setModalState(() => selectedAccount = v!),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: selectedCategory,
                    decoration: const InputDecoration(
                      labelText: 'Kategori',
                      border: OutlineInputBorder(),
                    ),
                    items: activeCats
                        .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                        .toList(),
                    onChanged: (v) =>
                        setModalState(() => selectedCategory = v!),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () async {
                        final title = titleCtrl.text.trim();
                        final amount =
                            double.tryParse(amountCtrl.text.trim()) ?? 0;

                        if (title.isEmpty || amount <= 0) {
                          messenger.showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Isi deskripsi & nominal yang valid.',
                              ),
                            ),
                          );
                          return;
                        }

                        await context.read<FinanceViewModel>().addTransaction(
                          title,
                          amount,
                          isIncome,
                          selectedCategory,
                          selectedAccount,
                        );

                        if (!mounted) return;
                        Navigator.pop(ctx);
                      },
                      child: const Text('Simpan'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _showTransferDialog(
    BuildContext context,
    FinanceViewModel vm,
  ) async {
    String from = FinanceViewModel.accountWallet;
    String to = FinanceViewModel.accountDigital;
    final amountCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    final messenger = ScaffoldMessenger.of(context);

    await showDialog(
      context: context,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (ctx, setDialogState) => AlertDialog(
            title: const Text('Transfer Antar Akun'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  DropdownButtonFormField<String>(
                    initialValue: from,
                    decoration: const InputDecoration(labelText: 'Dari'),
                    items: const [
                      DropdownMenuItem(
                        value: FinanceViewModel.accountWallet,
                        child: Text(FinanceViewModel.accountWallet),
                      ),
                      DropdownMenuItem(
                        value: FinanceViewModel.accountDigital,
                        child: Text(FinanceViewModel.accountDigital),
                      ),
                    ],
                    onChanged: (v) => setDialogState(() => from = v!),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    initialValue: to,
                    decoration: const InputDecoration(labelText: 'Ke'),
                    items: const [
                      DropdownMenuItem(
                        value: FinanceViewModel.accountWallet,
                        child: Text(FinanceViewModel.accountWallet),
                      ),
                      DropdownMenuItem(
                        value: FinanceViewModel.accountDigital,
                        child: Text(FinanceViewModel.accountDigital),
                      ),
                    ],
                    onChanged: (v) => setDialogState(() => to = v!),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: amountCtrl,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Nominal'),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Catatan (opsional)',
                    ),
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text('Batal'),
              ),
              FilledButton(
                onPressed: () async {
                  final amount = double.tryParse(amountCtrl.text.trim()) ?? 0;

                  if (from == to) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Akun asal dan tujuan tidak boleh sama.'),
                      ),
                    );
                    return;
                  }

                  if (amount <= 0) {
                    messenger.showSnackBar(
                      const SnackBar(
                        content: Text('Nominal transfer tidak valid.'),
                      ),
                    );
                    return;
                  }

                  await vm.transferBetweenAccounts(
                    amount: amount,
                    fromAccount: from,
                    toAccount: to,
                    note: noteCtrl.text,
                  );

                  if (!mounted) return;
                  Navigator.pop(ctx);
                },
                child: const Text('Transfer'),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF020617), Color(0xFF0F172A)],
        ),
      ),
    );
  }
}
