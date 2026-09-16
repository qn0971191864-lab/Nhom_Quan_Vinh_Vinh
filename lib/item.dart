class Item {
  String itemName = "Điện thoại thông minh";
  double startingPrice = 2000000;
  String description = "Sản phẩm mới chính hãng";
  // Phương thức thiết lập thông tin vật phẩm đấu giá
  void setItem(String itemName, double startingPrice, String description) {
    this.itemName = itemName;
    this.startingPrice = startingPrice;
    this.description = description;
  }
  // Phương thức lấy tên vật phẩm
  String getItemName() {
    return itemName;
  }
}