class NttdatapayConfig {
  final String merchId;
  final String txnPassword;
  final String reqEncKey;
  final String reqSalt;
  final String resDecKey;
  final String resSalt;
  final String resHashKey;
  final String reqHashKey;

  final NttdatapayEnvironment environment;

  const NttdatapayConfig({
    required this.merchId,
    required this.txnPassword,
    required this.reqEncKey,
    required this.reqSalt,
    required this.resDecKey,
    required this.resSalt,
    required this.resHashKey,
    required this.reqHashKey,
    this.environment = NttdatapayEnvironment.uat,
  });

  /// AUTH URL (UAT / PROD)
  String get authUrl {
    switch (environment) {
      case NttdatapayEnvironment.production:
        return "https://payment1.atomtech.in/ots/aipay/auth";
      case NttdatapayEnvironment.uat:
        return "https://paynetzuat.atomtech.in/ots/aipay/auth";
    }
  }

  /// RETURN URL
  String get returnUrl {
    switch (environment) {
      case NttdatapayEnvironment.production:
        return "https://payment.atomtech.in/mobilesdk/param";
      case NttdatapayEnvironment.uat:
        return "https://pgtest.atomtech.in/mobilesdk/param";
    }
  }

  /// CHECKOUT JS ENV
  String get checkoutEnv {
    return environment == NttdatapayEnvironment.production ? "prod" : "uat";
  }

  /// CHECKOUT JS URL
  String get checkoutJsUrl {
    return environment == NttdatapayEnvironment.production
        ? "https://psa.atomtech.in/staticdata/ots/js/atomcheckout.js"
        : "https://pgtest.atomtech.in/staticdata/ots/js/atomcheckout.js";
  }
}

enum NttdatapayEnvironment { uat, production }
