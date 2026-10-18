import 'project_model.dart';

class TransactionModel extends ProjectModel<int> {
  int transactionId = 1;
  double amount = 500000;
  String paymentMethod = "Ví điện tử";
  String status = "Thành công";

  @override
  int get id => transactionId;

  // Hàm Set để thiết lập thông tin giao dịch
  void setTransaction(int transactionId, double amount, String paymentMethod, String status) {
    this.transactionId = transactionId;
    this.amount = amount;
    this.paymentMethod = paymentMethod;
    this.status = status;
  }

  // Hàm Get để lấy số tiền giao dịch
  double getAmount() {
    return amount;
  }
}