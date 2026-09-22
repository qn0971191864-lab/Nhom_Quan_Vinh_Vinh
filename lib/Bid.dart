class Bid {
  int bidId = 1;
  double bidAmount = 2500000;
  String bidTime = "10:30 26/04/2026";

  // Hàm Set để thiết lập hoặc cập nhật thông tin lượt đặt giá
  void setBid(int bidId, double bidAmount, String bidTime) {
    this.bidId = bidId;
    this.bidAmount = bidAmount;
    this.bidTime = bidTime;
  }

  // Hàm Get để lấy số tiền đặt giá hiển thị ra UI
  double getBidAmount() {
    return bidAmount;
  }
}