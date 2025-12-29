import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'crypto_service.dart';
import 'config.dart';
import 'prod_detail.dart';

class NdpsAuthService {
  static Future<String> generateToken({
    required NttdatapayConfig config,
    required String txnId,
    required String amount,
    required String email,
    required String mobile,
    required String prodId,
    required String txnCurrency,

    // OPTIONAL
    List<ProdDetail>? prodDetails,

    String? custAccNo,
    String? clientCode,

    // Optional UDFs
    String? udf1,
    String? udf2,
    String? udf3,
    String? udf4,
    String? udf5,
    String? udf6,
    String? udf7,
    String? udf8,
    String? udf9,
    String? udf10,
  }) async {
    final txnDate = DateTime.now().toString().split('.')[0];

    final Map<String, dynamic> payDetails = {
      "amount": amount,
      "product": prodId,
      "txnCurrency": txnCurrency,
    };

    // Optional fields
    if (custAccNo != null && custAccNo.isNotEmpty) {
      payDetails["custAccNo"] = custAccNo;
    }

    if (clientCode != null && clientCode.isNotEmpty) {
      payDetails["clientCode"] = clientCode;
    }

    // Add prodDetails ONLY if provided
    if (prodDetails != null && prodDetails.isNotEmpty) {
      payDetails["prodDetails"] = prodDetails.map((e) => e.toJson()).toList();
    }

    /// Build extras ONLY if UDFs exist
    final Map<String, String> extras = {};

    void addUdf(String key, String? value) {
      if (value != null && value.trim().isNotEmpty) {
        extras[key] = value;
      }
    }

    addUdf("udf1", udf1);
    addUdf("udf2", udf2);
    addUdf("udf3", udf3);
    addUdf("udf4", udf4);
    addUdf("udf5", udf5);
    addUdf("udf6", udf6);
    addUdf("udf7", udf7);
    addUdf("udf8", udf8);
    addUdf("udf9", udf9);
    addUdf("udf10", udf10);

    final Map<String, dynamic> payInstrument = {
      "headDetails": {"version": "OTSv1.1", "api": "AUTH", "platform": "FLASH"},
      "merchDetails": {
        "merchId": config.merchId,
        "password": config.txnPassword,
        "merchTxnId": txnId,
        "merchTxnDate": txnDate,
      },
      "payDetails": payDetails,
      "custDetails": {"custEmail": email, "custMobile": mobile},
    };

    /// ✅ Attach extras only if present
    if (extras.isNotEmpty) {
      payInstrument["extras"] = extras;
    }

    final jsonData = jsonEncode({"payInstrument": payInstrument});
    debugPrint(jsonData);

    final encData = await AtomCryptoService.encrypt(
      jsonData,
      Uint8List.fromList(utf8.encode(config.reqEncKey)),
      Uint8List.fromList(utf8.encode(config.reqSalt)),
    );

    final response = await http.post(
      Uri.parse(config.authUrl),
      headers: {'content-type': 'application/x-www-form-urlencoded'},
      body: {'encData': encData, 'merchId': config.merchId},
    );

    debugPrint("AUTH API response");
    debugPrint(response.body);

    final encrypted = response.body
        .split('&')
        .firstWhere((e) => e.startsWith('encData='));

    final decrypted = await AtomCryptoService.decrypt(
      encrypted.split('=')[1],
      Uint8List.fromList(utf8.encode(config.resDecKey)),
      Uint8List.fromList(utf8.encode(config.resSalt)),
    );

    debugPrint("Generating Nttdatapay token");
    debugPrint(jsonDecode(decrypted)['atomTokenId'].toString());

    final decoded = jsonDecode(decrypted);
    return decoded['atomTokenId'].toString();
  }
}
