// ignore_for_file: constant_identifier_names
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cryptography/cryptography.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:http/http.dart' as http;
import 'package:url_launcher/url_launcher.dart';

const req_EncKey = 'A4476C2062FFA58980DC8F79EB6A799E';
const req_Salt = 'A4476C2062FFA58980DC8F79EB6A799E';
const res_DecKey = '75AEF0FA1B94B3C10D4F5B268F757F11';
const res_Salt = '75AEF0FA1B94B3C10D4F5B268F757F11';
const resHashKey = "KEYRESP123657234";
const merchId = "317157";
const merchPass = "Test@123";
const prodId = "NSE";
final authUrl = "https://paynetzuat.atomtech.in/ots/aipay/auth";

String? atomTokenId;
String currentTxnId = '';

bool isLoading = false;

final password = Uint8List.fromList(utf8.encode(req_EncKey));
final salt = Uint8List.fromList(utf8.encode(req_Salt));
final resPassword = Uint8List.fromList(utf8.encode(res_DecKey));
final resSalt = Uint8List.fromList(utf8.encode(res_Salt));
final iv =
    Uint8List.fromList([0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12, 13, 14, 15]);

//Encrypt Function
Future<String> encrypt(String text) async {
  debugPrint('Input text for encryption: $text');
  try {
    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha512(),
      iterations: 65536,
      bits: 256,
    );

    final derivedKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(password),
      nonce: salt,
    );

    final keyBytes = await derivedKey.extractBytes();
    debugPrint('Derived key bytes: $keyBytes');

    final aesCbc = AesCbc.with256bits(
      macAlgorithm: MacAlgorithm.empty,
      paddingAlgorithm: PaddingAlgorithm.pkcs7,
    );

    final secretBox = await aesCbc.encrypt(
      utf8.encode(text),
      secretKey: SecretKey(keyBytes),
      nonce: iv,
    );

    final hexOutput = secretBox.cipherText
        .map((b) => b.toRadixString(16).padLeft(2, '0'))
        .join();
    debugPrint('Encrypted hex output: $hexOutput');
    return hexOutput;
  } catch (e, stackTrace) {
    debugPrint('Encryption error: $e');
    debugPrint('Stack trace: $stackTrace');
    rethrow;
  }
}

// Decrypt Function
Future<String> decrypt(String hexCipherText) async {
  try {
    debugPrint('Input hex for decryption: $hexCipherText');

    // Convert hex string to bytes
    List<int> cipherText = [];
    for (int i = 0; i < hexCipherText.length; i += 2) {
      String hex = hexCipherText.substring(i, i + 2);
      cipherText.add(int.parse(hex, radix: 16));
    }
    debugPrint('Cipher text bytes: $cipherText');

    final pbkdf2 = Pbkdf2(
      macAlgorithm: Hmac.sha512(),
      iterations: 65536,
      bits: 256,
    );

    final derivedKey = await pbkdf2.deriveKey(
      secretKey: SecretKey(resPassword),
      nonce: resSalt, // Use the same salt as in encryption
    );

    final keyBytes = await derivedKey.extractBytes();

    final aesCbc = AesCbc.with256bits(
      macAlgorithm: MacAlgorithm.empty,
      paddingAlgorithm: PaddingAlgorithm.pkcs7,
    );

    final secretBox = SecretBox(
      cipherText,
      nonce: iv, // Use the same IV as in encryption
      mac: Mac.empty,
    );
    debugPrint('SecretBox: $secretBox');

    final decryptedBytes = await aesCbc.decrypt(
      secretBox,
      secretKey: SecretKey(keyBytes),
    );

    final decryptedText = utf8.decode(decryptedBytes);
    debugPrint('Decrypted text: $decryptedText');
    return decryptedText;
  } catch (e, stackTrace) {
    debugPrint('Decryption error: $e');
    debugPrint('Stack trace: $stackTrace');
    rethrow;
  }
}

Future<bool> validateSignature(
    Map<String, dynamic> data, String resHashKey) async {
  debugPrint("validateSignature called");

  String signatureString = data["payInstrument"]["merchDetails"]["merchId"]
          .toString() +
      data["payInstrument"]["payDetails"]["atomTxnId"].toString() +
      data['payInstrument']['merchDetails']['merchTxnId'].toString() +
      data['payInstrument']['payDetails']['totalAmount'].toStringAsFixed(2) +
      data['payInstrument']['responseDetails']['statusCode'].toString() +
      data['payInstrument']['payModeSpecificData']['subChannel'][0].toString() +
      data['payInstrument']['payModeSpecificData']['bankDetails']['bankTxnId']
          .toString();

  var bytes = utf8.encode(signatureString);
  var key = utf8.encode(resHashKey);

  final hmac = Hmac.sha512();
  final secretKey = SecretKey(key);
  final mac = await hmac.calculateMac(bytes, secretKey: secretKey);

  var genSig =
      mac.bytes.map((byte) => byte.toRadixString(16).padLeft(2, '0')).join();

  if (data['payInstrument']['payDetails']['signature'] == genSig) {
    print("ignaure matched");
    return true;
  } else {
    print("signaure does not matched");
    return false;
  }
}

class PayPage extends StatefulWidget {
  const PayPage({super.key});

  @override
  State<PayPage> createState() => _PayPageState();
}

class _PayPageState extends State<PayPage> {
  @override
  void initState() {
    super.initState();
    // Generate atom token when page loads
    initiatePayment();
  }

  // //Generate Signature
  // Future<String> generateSignature(Map<String, dynamic> respArray) async {
  //   print("Generating signature using response array.");

  //   final payDetails = respArray['payDetails'];
  //   final merchDetails = respArray['merchDetails'];
  //   final responseDetails = respArray['responseDetails'];
  //   final payModeSpecificData = respArray['payModeSpecificData'];

  //   // Construct the signature string
  //   final signatureString =
  //       '${merchDetails['merchId']}${payDetails['atomTxnId']}${merchDetails['merchTxnId']}${payDetails['totalAmount'].toStringAsFixed(2)}${responseDetails['statusCode']}${payModeSpecificData['subChannel'][0]}${payModeSpecificData['bankDetails']['bankTxnId']}';

  //   print("Constructed signature string: $signatureString");

  //   // Initialize HMAC with the key
  //   final hmac = Hmac.sha512();
  //   final secretKey = SecretKey(utf8.encode(resHashKey));
  //   final signatureBytes = await hmac.calculateMac(
  //     utf8.encode(signatureString),
  //     secretKey: secretKey,
  //   );

  //   print("HMAC updated with signature string.");

  //   // Generate the HMAC (signature)
  //   final genHmac = signatureBytes.bytes
  //       .map((b) => b.toRadixString(16).padLeft(2, '0'))
  //       .join();

  //   print("Generated HMAC (signature): $genHmac");

  //   return genHmac;
  // }

  //Initiate the payment (Send request to atom server)
  Future<void> initiatePayment() async {
    setState(() {
      isLoading = true;
      currentTxnId =
          'Invoice${DateTime.now().millisecondsSinceEpoch.toRadixString(36)}';
    });

    try {
      final String txnDate = DateTime.now().toString().split('.')[0];
      const String amount = "1";
      const String userEmailId = "test.user@atomtech.in";
      const String userContactNo = "8888888888";

      //Json data for sending to atom server
      String jsonData =
          '{"payInstrument":{"headDetails":{"version":"OTSv1.1","api":"AUTH","platform":"FLASH"},"merchDetails":{"merchId":"$merchId","userId":"","password":"$merchPass","merchTxnId":"$currentTxnId","merchTxnDate":"$txnDate"},"payDetails":{"amount":"$amount","product":"$prodId","custAccNo":"213232323","txnCurrency":"INR"},"custDetails":{"custEmail":"$userEmailId","custMobile":"$userContactNo"},  "extras": {"udf1":"udf1","udf2":"udf2","udf3":"udf3","udf4":"udf4","udf5":"udf5"}}}';

      final String encDataR = await encrypt(jsonData);
      final response = await http.post(
        Uri.parse(authUrl),
        headers: {
          'content-type': 'application/x-www-form-urlencoded',
        },
        body: {
          'encData': encDataR,
          'merchId': merchId,
        },
      );
      if (response.statusCode == 200) {
        debugPrint("Response received: Status code 200");

        final responseData = response.body.split('&');
        debugPrint("Response body split into array: $responseData");

        if (responseData.length > 1) {
          // Extract the encrypted data
          final encDataPart = responseData
              .firstWhere((element) => element.startsWith('encData'));
          final encryptedData = encDataPart.split('=')[1];
          final extractedData = ['encData', encryptedData];
          debugPrint("Extracted encrypted response data: $extractedData");

          try {
            // Decrypt the extracted data
            final decryptedData = await decrypt(extractedData[1]);
            debugPrint("Decrypted data: $decryptedData");

            final jsonResponse = json.decode(decryptedData);
            debugPrint("JSON response: $jsonResponse");

            if (jsonResponse['responseDetails']['txnStatusCode'] == 'OTS0000') {
              setState(() {
                atomTokenId = jsonResponse['atomTokenId'].toString();
                isLoading = false;
                // ignore: prefer_interpolation_to_compose_strings
                debugPrint("Transaction Status Code: " +
                    jsonResponse['responseDetails']['txnStatusCode']);
              });
            } else {
              debugPrint("Error: txnStatusCode is not 'OTS0000'");
              throw Exception('Payment initialization failed');
            }
          } catch (e) {
            debugPrint("Decryption failed: $e");
            throw Exception('Error during decryption: $e');
          }
        } else {
          debugPrint("Error: Invalid response data format");
          throw Exception('Invalid response data format');
        }
      } else {
        debugPrint(
            "Error: Failed to connect to the server. Status code: ${response.statusCode}");
        throw Exception('Failed to connect to the server');
      }
    } catch (e) {
      setState(() {
        isLoading = false;
      });
      showError('Payment initialization failed: $e');
    }
  }

  void showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }

  void showSuccess(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.green),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.white,
        toolbarHeight: 100,
        title: const Text(
          'Merchant Shop',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              margin: const EdgeInsets.symmetric(vertical: 20.0),
              child: Text(
                "Atom Token ID: $atomTokenId",
                style: const TextStyle(
                    fontSize: 16.0, fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              margin:
                  const EdgeInsets.symmetric(vertical: 10.0, horizontal: 30),
              child: Text(
                "Transaction ID: $currentTxnId",
                style: const TextStyle(
                    fontSize: 16.0, fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 20.0),
              child: const Text(
                "Pay Rs: 1.00",
                style: TextStyle(fontSize: 16.0, fontWeight: FontWeight.bold),
              ),
            ),
            Container(
              margin: const EdgeInsets.symmetric(vertical: 20.0),
              child: isLoading
                  ? const CircularProgressIndicator()
                  : ElevatedButton(
                      style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue),
                      onPressed: () {
                        Navigator.push(
                            context,
                            MaterialPageRoute(
                                builder: (context) => PaymentWebView(
                                      atomTokenId: atomTokenId.toString(),
                                      merchId: merchId,
                                      currentTxnId: currentTxnId,
                                    )));
                      },
                      child: const Text(
                        'Pay Now',
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class PaymentWebView extends StatefulWidget {
  final String atomTokenId;
  final String merchId;
  final String currentTxnId;

  const PaymentWebView({
    required this.atomTokenId,
    required this.merchId,
    required this.currentTxnId,
    super.key,
  });

  @override
  State createState() => _PaymentWebViewState();
}

class _PaymentWebViewState extends State<PaymentWebView> {
  double progress = 0;
  late InAppWebViewController webViewController;

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () => _handleBackButtonAction(context),
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Payment'),
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).pop(),
          ),
        ),
        body: Stack(
          children: [
            InAppWebView(
                initialData: InAppWebViewInitialData(
                  data: '''
                  <!DOCTYPE html>
                  <html>
                  <head>
                    <meta name="viewport" content="width=device-width, initial-scale=1.0">
                    <script src="https://pgtest.atomtech.in/staticdata/ots/js/atomcheckout.js"></script>
                  </head>
                  <body>
                  <script>
                      function initPayment() {
                        const options = {
                          "atomTokenId": "${widget.atomTokenId}",
                          "merchId": "${widget.merchId}",
                          "custEmail": "test.user@gmail.com",
                          "custMobile": "8888888888",
                          "returnUrl": "https://pgtest.atomtech.in/mobilesdk/param",
                          "userAgent": "mobile_webView"
                        };
                        new AtomPaynetz(options, 'uat');
                      }
      
                      window.onload = initPayment;
                      
                    </script>
                   
                  </body>
                  </html>
                ''',
                ),
                shouldOverrideUrlLoading: (controller, navigationAction) async {
                  debugPrint("shouldOverrideUrlLoading called");
                  var uri = navigationAction.request.url!;
                  debugPrint(uri.scheme);
                  if (["upi"].contains(uri.scheme)) {
                    debugPrint("UPI URL detected");
                    // Launch the App
                    await launchUrl(
                      uri,
                    );
                    // and cancel the request
                    return NavigationActionPolicy.CANCEL;
                  }
                  return NavigationActionPolicy.ALLOW;
                },
                initialSettings: InAppWebViewSettings(
                    javaScriptEnabled: true,
                    javaScriptCanOpenWindowsAutomatically: true),
                onLoadStop: (controller, url) async {
                  print("onLoadStop");
                  print(url);
                  setState(() {
                    progress = 1.0;
                  });

                  if (url != null &&
                      url.toString().contains("/mobilesdk/param")) {
                    print("/mobilesdk/param detected");

                    // New code to evaluate JavaScript and get the response
                    final String response = await controller.evaluateJavascript(
                        source:
                            "document.getElementsByTagName('h5')[0].innerHTML");
                    // You can now use the 'response' variable as needed
                    debugPrint("HTML response : $response");

                    final split = response.trim().split('|');
                    final Map<int, String> values = {
                      for (int i = 0; i < split.length; i++) i: split[i]
                    };

                    var transactionResult = "";

                    if (response.trim().contains("cancelTransaction")) {
                      transactionResult = "Transaction Cancelled!";
                    } else {
                      final splitTwo = values[1]!.split('=');
                      print("encData value");
                      debugPrint(splitTwo[1].toString());

                      final decryptedResponseData =
                          await decrypt(splitTwo[1].toString());
                      debugPrint(
                          'Decrypted response data: $decryptedResponseData');

                      Map<String, dynamic> jsonInput =
                          jsonDecode(decryptedResponseData);
                      debugPrint("Reading full response: $jsonInput");

                      var checkFinalTransaction =
                          await validateSignature(jsonInput, resHashKey);

                      debugPrint("Signature matched: $checkFinalTransaction");

                      if (checkFinalTransaction) {
                        print("Signature is valid");
                        if (jsonInput["payInstrument"]["responseDetails"]
                                ["statusCode"] ==
                            'OTS0000') {
                          debugPrint("Transaction success and close");
                          transactionResult = "Transaction Success";
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text("Transaction Successful!"),
                              duration: Duration(seconds: 3),
                              backgroundColor: Colors.green,
                            ),
                          );
                        } else {
                          debugPrint("Transaction failed");
                          transactionResult = "Transaction Failed";
                        }
                      } else {
                        debugPrint("Signature mismatched");
                        transactionResult = "Signature Failed";
                      }
                      _closeWebView(context, transactionResult);
                    }
                  }
                  ;
                }),
          ],
        ),
      ),
    );
  }

  void _closeWebView(BuildContext context, String transactionResult) {
    debugPrint("Closing web");
    debugPrint("result: $transactionResult");
    if (!mounted) return; // Ensure widget is still mounted

    Navigator.of(context).pop(); // Close current window
  }

  Future<bool> _handleBackButtonAction(BuildContext context) async {
    debugPrint("_handleBackButtonAction called");
    showDialog(
        context: context,
        builder: (context) => AlertDialog(
              title: const Text('Do you want to exit the payment ?'),
              actions: <Widget>[
                // ignore: deprecated_member_use
                ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  child: const Text('No'),
                ),
                // ignore: deprecated_member_use
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context).pop(); // Close current window
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text(
                            "Transaction Status = Transaction cancelled")));
                  },
                  child: const Text('Yes'),
                ),
              ],
            ));
    return Future.value(true);
  }
}
