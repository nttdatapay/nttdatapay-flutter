## Flutter AIPAY Integration Demo
 
## Introduction
This is a demo project built with Flutter to demonstrate the integration of NTT DATA Payment Gateway into a flutter application.
 
## Prerequisites
- Flutter (Tested up to Version 3.27.1)
- Dart (Tested up to Version 3.6.0)

# Project Structure
| File/Directory   | Description                                                                 |
|-------------------|-----------------------------------------------------------------------------|
| lib/main.dart     | Entry point of the application.                                            |
| lib/home.dart     | Handles API calls, encryption, decryption, navigation, and payment page view.  |
| pubspec.yaml      | Defines dependencies and metadata.                                         |
| README.md         | Project documentation.                                                    |
 
 
# How to Use
**Step 1**: Install all the project dependencies by running the following command:
	 
     flutter pub get
 
**Step 2**: Run the Application by using the following command:
	 
     flutter run
 
**Step 3**: Once the application is launched, the atom token id will be fetched, and you’ll see a sample merchant shop UI with Atom token ID, Transaction ID and Amount.
 
**Step 4**: Initiate Payment
Click the Pay Now button to initiate the payment process. 
The app will: 
- Encrypt your transaction data.
- Navigate to the payment page with the Atom Token ID.
 
**Step 5**: Complete the Payment
Make the payment on the payment page. The response will be processed, and a toast message will be displayed if the transaction was successful and you will be redirected to homepage.
 
# Customizations
- Change JSON Data: Modify the JSON payload in home.dart to include your specific fields like user's email, contact number, etc.
- AIPAY Environment: Update the CDN link in the payment script (inside the web view) to match your environment (UAT or Production).
 


