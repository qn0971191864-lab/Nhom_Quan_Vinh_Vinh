import 'project_model.dart';

class TransactionModel extends ProjectModel<int> {
  int transactionId = 1;
  double amount = 500000;
  String paymentMethod = 'Ví điện tử';
  String status = 'Thành công';
  int? userId; // foreign key to users (nullable for seed convenience)

  TransactionModel({
    this.transactionId = 1,
    this.amount = 500000,
    this.paymentMethod = 'Ví điện tử',
    this.status = 'Thành công',
    this.userId,
  });

  @override
  int get id => transactionId;

  void setTransaction(
    int transactionId,
    double amount,
    String paymentMethod,
    String status, [
    int? userId,
  ]) {
    this.transactionId = transactionId;
    this.amount = amount;
    this.paymentMethod = paymentMethod;
    this.status = status;
    this.userId = userId ?? this.userId;
  }

  double getAmount() {
    return amount;
  }

  Map<String, dynamic> toMap() {
    return {
      'transactionId': transactionId,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'status': status,
      if (userId != null) 'userId': userId,
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map, [String id = '']) {
    return TransactionModel(
      transactionId: (map['transactionId'] as num?)?.toInt() ?? (int.tryParse(id) ?? 0),
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      paymentMethod: map['paymentMethod'] as String? ?? '',
      status: map['status'] as String? ?? '',
      userId: (map['userId'] as num?)?.toInt(),
    );
  }

  @override
  void displayDetails() {
    // ignore: avoid_print
    print('Mã giao dịch: $transactionId - Số tiền: $amount VNĐ - Phương thức: $paymentMethod - Trạng thái: $status');
  }
}
