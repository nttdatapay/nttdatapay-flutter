class ProdDetail {
  final String prodName;
  final String prodAmount;

  const ProdDetail({required this.prodName, required this.prodAmount});

  Map<String, dynamic> toJson() => {
    "prodName": prodName,
    "prodAmount": prodAmount,
  };
}
