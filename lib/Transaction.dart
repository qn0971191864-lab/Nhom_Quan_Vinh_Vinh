// Import file base_model vào
import 'base_model.dart'; 

// Thêm extends BaseModel<TransactionModel>
class TransactionModel extends BaseModel<TransactionModel> {
  int transactionId = 1;
  double amount = 500000;
  String paymentMethod = "Ví điện tử";
  String status = "Thành công";

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

  // BẮT BUỘC THÊM: Ghi đè hàm displayDetails từ BaseModel
  @override
  void displayDetails() {
    print(super.toString()); // Sẽ in ra: Đối tượng thuộc lớp: TransactionModel
    print("Mã giao dịch: $transactionId - Số tiền: $amount VNĐ - Phương thức: $paymentMethod - Trạng thái: $status");
  }
}