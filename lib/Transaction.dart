import 'project_model.dart';

class TransactionModel extends ProjectModel<int> {
  int transactionId = 1;
  double amount = 500000;
  String paymentMethod = 'Ví điện tử';
  String status = 'Thành công';

  @override
  int get id => transactionId;

  void setTransaction(
    int transactionId,
    double amount,
    String paymentMethod,
    String status,
  ) {
    this.transactionId = transactionId;
    this.amount = amount;
    this.paymentMethod = paymentMethod;
    this.status = status;
  }

  double getAmount() {
    return amount;
  }

  @override
  void displayDetails() {
    print('Mã giao dịch: $transactionId - Số tiền: $amount VNĐ - Phương thức: $paymentMethod - Trạng thái: $status');
  }
}
