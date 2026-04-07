class TransactionModel {
  final int? id;
  final String title;
  final double amount;
  final String type; // 'INCOME' atau 'EXPENSE'
  final String category;
  final String account; // 'Dompet' atau 'ATM/E-Wallet'
  final DateTime date;

  TransactionModel({
    this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.account,
    required this.date,
  });

  Map<String, dynamic> toMap() => {
    'id': id,
    'title': title,
    'amount': amount,
    'type': type,
    'category': category,
    'account': account,
    'date': date.toIso8601String(),
  };

  factory TransactionModel.fromMap(Map<String, dynamic> map) =>
      TransactionModel(
        id: map['id'] as int?,
        title: (map['title'] ?? '') as String,
        amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
        type: (map['type'] ?? 'EXPENSE') as String,
        category: (map['category'] ?? 'Umum') as String,
        account: (map['account'] ?? 'Dompet') as String,
        date: DateTime.parse(map['date'] ?? DateTime.now().toIso8601String()),
      );
}
