# NTTDATAPAY Flutter

Flutter plugin for integrating **NTT DATA Payment Services India** in Android and iOS applications.

## Quick Navigation

- [Platform Support](#platform-support)
- [Features](#features)
- [Installation](#installation)
- [iOS Setup](#ios-setup)
- [Usage](#usage)
  - [Import the Package](#import-the-package)
  - [Initialize Merchant Configuration](#initialize-merchant-configuration)
  - [Generate Token](#generate-token-using-nttdatapay-auth-service)
  - [Optional UDF Parameters](#add-optional-udf-parameters)
  - [Multi-Product Payments](#add-multi-product-split-payment-support)
  - [Open Checkout](#open-checkout-webview-and-wait-for-the-final-payment-result)
- [Full Example](#full-example)

---

## Platform Support

✅ Android  
✅ iOS  

> ⚠️ **Mobile platforms only**  
> This SDK relies on mobile-specific features such as in-app WebView checkout
> and UPI intent handling.  
> Other platforms are **not supported**.
---

## Features

- Secure token generation  
- WebView-based checkout  
- UPI intent support (GPay, PhonePe, Paytm, Cred, etc.)  
- Android & iOS support  
- UAT & Production environments  

---

## Installation

Add the dependency to your `pubspec.yaml`:

```yaml
dependencies:
  nttdatapay_flutter: ^1.0.8
```

Or run:

```bash
flutter pub add nttdatapay_flutter
```

Then fetch dependencies:

```bash
flutter pub get
```

---

## iOS Setup

### iOS Configuration (Required for UPI Apps)

iOS blocks app-to-app URL scheme checks by default.  
Add the following entries to `ios/Runner/Info.plist`:

```xml
<key>LSApplicationQueriesSchemes</key>
<array>
  <string>upi</string>
  <string>phonepe</string>
  <string>paytmmp</string>
  <string>gpay</string>
  <string>tez</string>
  <string>credpay</string>
</array>
```

---

## Usage

### Import the Package

```dart
import 'package:nttdatapay_flutter/nttdatapay_flutter.dart';
```

---

### Initialize Merchant Configuration

> ⚠️ Do not hardcode production credentials.  
> Contact the NTT DATA Payment Services integration team:  
> https://in.nttdatapay.com/sign-up

```dart
final nttdatapayConfig = const NttdatapayConfig(
  merchId: "XXXXXXX",
  txnPassword: "XXXX@XXX",
  reqEncKey: "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
  reqSalt: "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
  resDecKey: "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
  resSalt: "XXXXXXXXXXXXXXXXXXXXXXXXXXXXXX",
  reqHashKey: "XXXXXXXXXXXXXX",
  resHashKey: "XXXXXXXXXXXXXXXXXXX",
  environment: NttdatapayEnvironment.uat,
);
```

To switch to production:

```dart
environment: NttdatapayEnvironment.production,
```

---

### Generate Token Using NTTDATAPAY AUTH Service

```dart
final ndpsTokenId = await NdpsAuthService.generateToken(
  config: nttdatapayConfig,
  txnId: txnId, // unique transaction Id
  amount: "1.00",
  email: "test.user@xyz.in",
  mobile: "8888888800",
  prodId: "XXX",
  txnCurrency: "INR",
);
```

---

### Add Optional UDF Parameters

```dart
udf1: "value1",
udf2: "value2",
udf3: "value3",
udf4: "value4",
udf5: "value5",
```

---

### Add Multi-Product (Split Payment) Support

```dart
prodId: "multi", // fix value
prodDetails: const [
  ProdDetail(prodName: "Item1", prodAmount: "1.00"),
  ProdDetail(prodName: "Item2", prodAmount: "1.00"),
],
```

---

### Open Checkout WebView and Wait for the Final Payment Result

```dart
final result = await Navigator.push(
  context,
  MaterialPageRoute(
    builder: (_) => NdpsPaymentWebView(
        ndpsTokenId: ndpsTokenId,
        merchId: nttdatapayConfig.merchId,
        returnUrl: nttdatapayConfig.returnUrl,
        config: nttdatapayConfig,
        email: "test.user@xyz.in",
        mobile: "8888888800",
        showAppBar: true,
        appBarTitle: "Complete Payment",
    ),
  ),
);
```

---

## Full Example

👉 https://pub.dev/packages/nttdatapay_flutter/example
