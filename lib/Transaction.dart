import 'project_model.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

class TransactionModel extends ProjectModel<int> {
  int transactionId = 1;
  int amount = 500000;
  String paymentMethod = 'Ví điện tử';
  String status = 'Thành công';
  int? userId; // foreign key to users (nullable for seed convenience)
  String? userUid;
  DateTime? createdAt;

  TransactionModel({
    this.transactionId = 1,
    this.amount = 500000,
    this.paymentMethod = 'Ví điện tử',
    this.status = 'Thành công',
    this.userId,
    this.userUid,
    this.createdAt,
  });

  @override
  int get id => transactionId;

  void setTransaction(
    int transactionId,
    int amount,
    String paymentMethod,
    String status, [
    int? userId,
    String? userUid,
  ]) {
    this.transactionId = transactionId;
    this.amount = amount;
    this.paymentMethod = paymentMethod;
    this.status = status;
    this.userId = userId ?? this.userId;
    this.userUid = userUid ?? this.userUid;
  }

  int getAmount() {
    return amount;
  }

  Map<String, dynamic> toMap() {
    return {
      'transactionId': transactionId,
      'amount': amount,
      'paymentMethod': paymentMethod,
      'status': status,
      if (userUid != null) 'userUid': userUid,
      if (createdAt != null)
        'createdAt': Timestamp.fromDate(createdAt!.toUtc()),
    };
  }

  factory TransactionModel.fromMap(Map<String, dynamic> map, [String id = '']) {
    return TransactionModel(
      transactionId:
          (map['transactionId'] as num?)?.toInt() ?? (int.tryParse(id) ?? 0),
      amount: (map['amount'] as num?)?.toInt() ?? 0,
      paymentMethod: map['paymentMethod'] as String? ?? '',
      status: map['status'] as String? ?? '',
      userId: (map['userId'] as num?)?.toInt(),
      userUid: map['userUid'] as String?,
      createdAt: switch (map['createdAt']) {
        Timestamp value => value.toDate(),
        DateTime value => value,
        _ => null,
      },
    );
  }

  @override
  void displayDetails() {
    // ignore: avoid_print
    print(
      'Mã giao dịch: $transactionId - Số tiền: $amount VNĐ - Phương thức: $paymentMethod - Trạng thái: $status',
    );
  }
}
