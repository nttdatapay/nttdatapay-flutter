import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:url_launcher/url_launcher.dart';

import 'crypto_service.dart';
import 'signature_service.dart';
import 'payment_result.dart';
import 'config.dart';

class NdpsPaymentWebView extends StatefulWidget {
  final String ndpsTokenId;
  final String merchId;
  final String returnUrl;
  final NttdatapayConfig config;
  final String email;
  final String mobile;

  /// AppBar controls
  final bool showAppBar;
  final String? appBarTitle;

  const NdpsPaymentWebView({
    super.key,
    required this.ndpsTokenId,
    required this.merchId,
    required this.returnUrl,
    required this.config,
    required this.email,
    required this.mobile,
    this.showAppBar = true,
    this.appBarTitle,
  });

  @override
  State<NdpsPaymentWebView> createState() => _AtomPaymentWebViewState();
}

class _AtomPaymentWebViewState extends State<NdpsPaymentWebView> {
  bool _isProcessing = false;

  /// Show cancel confirmation dialog
  Future<bool> _showCancelDialog() async {
    final bool? result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text("Cancel Payment?"),
        content: const Text("Are you sure you want to cancel this payment?"),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text("No"),
          ),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text("Yes"),
          ),
        ],
      ),
    );
    return result == true;
  }

  /// Handle back / close action
  Future<void> _handleExit() async {
    final BuildContext ctx = context; // ✅ capture early

    final shouldExit = await _showCancelDialog();

    if (!ctx.mounted) return;

    if (shouldExit) {
      Navigator.of(ctx).pop(
        NdpsPaymentResult(
          success: false,
          status: "CANCELLED",
          description: "Payment cancelled by user",
          rawResponse: {"reason": "User cancelled using back/close"},
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope<NdpsPaymentResult>(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        await _handleExit();
      },
      child: Scaffold(
        appBar: widget.showAppBar
            ? AppBar(
                title: Text(widget.appBarTitle ?? "Payment"),
                centerTitle: true,
                leading: IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: _handleExit,
                ),
              )
            : null,
        body: InAppWebView(
          initialSettings: InAppWebViewSettings(
            javaScriptEnabled: true,
            clearCache: true,
            cacheEnabled: false,
            useWideViewPort: true,
            loadWithOverviewMode: true,
            supportZoom: false,
            builtInZoomControls: false,
            displayZoomControls: false,
            mediaPlaybackRequiresUserGesture: false,
          ),
          initialData: InAppWebViewInitialData(data: _html()),

          /// HANDLE UPI INTENT
          shouldOverrideUrlLoading: (controller, navigationAction) async {
            final uri = navigationAction.request.url;
            if (uri == null) return NavigationActionPolicy.ALLOW;

            final scheme = uri.scheme.toLowerCase();
            const upiSchemes = [
              "upi",
              "phonepe",
              "paytmmp",
              "tez",
              "gpay",
              "credpay",
            ];

            if (upiSchemes.contains(scheme)) {
              if (Platform.isAndroid) {
                try {
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                } catch (_) {
                  if (!context.mounted) return NavigationActionPolicy.CANCEL;
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("App Not Installed")),
                  );
                }
              } else if (Platform.isIOS) {
                final canLaunch = await canLaunchUrl(uri);
                if (!context.mounted) return NavigationActionPolicy.CANCEL;

                if (!canLaunch) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("App Not Installed")),
                  );
                  return NavigationActionPolicy.CANCEL;
                }

                await launchUrl(uri, mode: LaunchMode.externalApplication);
              }

              return NavigationActionPolicy.CANCEL;
            }

            return NavigationActionPolicy.ALLOW;
          },

          /// CORE LOGIC – CLOSE WEBVIEW ON RETURN URL
          onLoadStop: (controller, url) async {
            if (url == null || _isProcessing) return;

            // 🔴 IMPORTANT: use contains instead of startsWith
            if (!url.toString().contains(widget.returnUrl)) return;

            // debugPrint("Return URL matched => ${url.toString()}");
            // debugPrint("Expected returnUrl => ${widget.returnUrl}");

            _isProcessing = true;

            // debugPrint("widget.returnUrl");
            // debugPrint(widget.returnUrl);
            try {
              // 🟡 Wait briefly to allow DOM to update (CRITICAL FIX)
              await Future.delayed(const Duration(milliseconds: 300));

              final pageText = await controller.evaluateJavascript(
                source: "document.body ? document.body.innerText : ''",
              );

              if (!context.mounted) return;

              final responseText = pageText?.toString() ?? "";

              debugPrint("FINAL responseText =>");
              debugPrint(responseText);

              /// CANCEL
              if (responseText.contains("encData=cancelTransaction")) {
                Navigator.of(context).pop(
                  NdpsPaymentResult(
                    success: false,
                    status: "CANCELLED",
                    description: "Payment has been cancelled by user",
                    rawResponse: {"raw": "Payment has been cancelled by user"},
                  ),
                );
                return;
              }

              /// TIMEOUT
              if (responseText.contains("encData=sessionTimeout")) {
                Navigator.of(context).pop(
                  NdpsPaymentResult(
                    success: false,
                    status: "TIMEOUT",
                    description: "Session Timeout",
                    rawResponse: {"raw": "Session Timeout"},
                  ),
                );
                return;
              }

              /// NORMAL FLOW
              final encDataMatch = RegExp(
                r'encData=([A-Fa-f0-9]+)',
              ).firstMatch(responseText);

              if (encDataMatch == null) {
                throw Exception("encData not found in return response");
              }

              final encData = encDataMatch.group(1)!;

              final decrypted = await AtomCryptoService.decrypt(
                encData,
                utf8.encode(widget.config.resDecKey),
                utf8.encode(widget.config.resSalt),
              );

              if (!context.mounted) return;

              final jsonResponse = jsonDecode(decrypted);

              final isValid = await AtomSignatureService.validate(
                jsonResponse,
                widget.config.resHashKey,
              );

              if (!context.mounted) return;

              final statusCode =
                  jsonResponse["payInstrument"]["responseDetails"]["statusCode"]
                      ?.toString();

              final description =
                  jsonResponse["payInstrument"]["responseDetails"]["description"];

              Navigator.of(context).pop(
                NdpsPaymentResult(
                  success: isValid && statusCode == "OTS0000",
                  status: statusCode ?? "FAILED",
                  description: description,
                  rawResponse: jsonResponse,
                ),
              );
            } catch (e) {
              if (!context.mounted) return;

              Navigator.of(context).pop(
                NdpsPaymentResult(
                  success: false,
                  status: "ERROR",
                  description: "Error has been occured",
                  rawResponse: {"error": e.toString()},
                ),
              );
            }
          },
        ),
      ),
    );
  }

  /// RESPONSIVE HTML
  String _html() {
    return '''
<!DOCTYPE html>
<html>
<head>
<meta name="viewport" content="width=device-width,initial-scale=1.0,maximum-scale=1.0,user-scalable=no"/>
<script src="${widget.config.checkoutJsUrl}"></script>
</head>
<body>
<script>
function initPayment(){
  const options={
    atomTokenId:"${widget.ndpsTokenId}",
    merchId:"${widget.config.merchId}",
    custEmail:"${widget.email}",
    custMobile:"${widget.mobile}",
    returnUrl:"${widget.returnUrl}",
    userAgent:"mobile_webView"
  };
  new AtomPaynetz(options,"${widget.config.checkoutEnv}");
}
window.onload=initPayment;
</script>
</body>
</html>
''';
  }
}
