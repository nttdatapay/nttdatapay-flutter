import 'dart:convert';
import 'package:cryptography/cryptography.dart';

class AtomSignatureService {
  static Future<bool> validate(
    Map<String, dynamic> data,
    String resHashKey,
  ) async {
    final pi = data['payInstrument'];

    final signatureString =
        pi['merchDetails']['merchId'].toString() +
        pi['payDetails']['atomTxnId'].toString() +
        pi['merchDetails']['merchTxnId'].toString() +
        pi['payDetails']['totalAmount'].toStringAsFixed(2) +
        pi['responseDetails']['statusCode'].toString() +
        pi['payModeSpecificData']['subChannel'][0].toString() +
        pi['payModeSpecificData']['bankDetails']['bankTxnId'].toString();

    final hmac = Hmac.sha512();
    final mac = await hmac.calculateMac(
      utf8.encode(signatureString),
      secretKey: SecretKey(utf8.encode(resHashKey)),
    );

    final genSig = mac.bytes
        .map((e) => e.toRadixString(16).padLeft(2, '0'))
        .join();

    return genSig == pi['payDetails']['signature'];
  }
}
