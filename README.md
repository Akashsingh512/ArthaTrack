# ArthaTrack (अर्थTrack) 🇮🇳

A production-ready, privacy-first personal finance and wealth management mobile application for Android built with Flutter.

ArthaTrack operates with a **strict local-first architecture**: 100% of your financial accounts, balance sheets, debts, assets, and transactions remain solely on your device in SQLite. No user-data backend, no telemetry, and no financial data tracking.

---

## Key Features

1. **Native Android Notification Interceptor (Kotlin)**
   - `NotificationListenerService` subclass running in Kotlin.
   - Listens to incoming push notifications and SMS from Indian banking and UPI apps:
     - **UPI Apps**: Google Pay (`com.google.android.apps.nbu.paisa.user`), PhonePe (`com.phonepe.app`), Paytm (`net.one97.paytm`), CRED.
     - **Banks**: HDFC Bank (`net.hdfcbank.android`), SBI (`com.sbi.lotusintouch`, `com.sbi.upi`), ICICI (`com.csam.icici.bank.imobile`), Axis Bank (`com.axis.mobile`), Kotak 811.
     - **SMS Apps**: Google Messages, Samsung Messages.
   - Streams notifications in real time to Flutter via native `EventChannel`.
   - Native `MethodChannel` to check permission state and deep-link directly into Android's `ACTION_NOTIFICATION_LISTENER_DETAIL_SETTINGS`.

2. **Gmail Ingestion Engine (Google OAuth 2.0)**
   - Integrates Google Sign-In with minimal `gmail.readonly` scope.
   - Uses `googleapis` (Gmail API v1) to scan confirmation emails matching `debited OR credited OR spent OR "₹" OR "INR" OR "Rs."`.
   - MIME body decoding and automatic duplicate elimination.

3. **Dual-Engine Transaction Processing**
   - **Engine A (User AI Key - Primary BYOK)**:
     - Bring-Your-Own-Key support for free-tier **Google Gemini** (`gemini-1.5-flash`) and **Groq** (`llama-3.3-70b-versatile`).
     - Prompt enforces strict JSON schema output matching `{ amount, type, category, merchant, updated_balance, account_snippet, confidence }`.
     - User keys are securely stored in Android Keystore via `flutter_secure_storage`.
   - **Engine B (Offline Heuristic / Regex - Fallback)**:
     - Automatically active when no API key is provided, when the device is offline, or when the API call fails or times out.
     - Tailored regular expressions for Indian currency: `(?:Rs\.?|INR|₹)\s?([\d,]+(?:\.\d{1,2})?)`
     - Action triggers for `debited, spent, paid` vs `credited, received, added`.
     - Available balance extraction: `(?:Bal|Avl Bal|Balance)[:\s]+(?:Rs\.?|INR|₹)\s?([\d,]+(?:\.\d{1,2})?)`
     - Merchant/Category heuristics for top Indian apps (Swiggy, Zomato, Zepto, Blinkit, Uber, Ola, Amazon, Flipkart, Apollo, Netflix, etc.).

4. **Database & Schema (SQLite via `sqflite`)**
   - `accounts`: `id`, `name`, `type` (`SAVINGS`, `CREDIT_CARD`, `CASH`), `balance`, `updated_at`
   - `balance_sheet`: `id`, `name`, `type` (`ASSET` or `DEBT`), `amount`, `interest_rate`, `category`, `updated_at`
   - `transactions`: `id`, `account_id`, `amount`, `type`, `category`, `merchant`, `raw_text`, `date`, `source`, `engine`
   - Atomic transactions: recording an expense/income automatically adjusts the corresponding account balance.

5. **Indian Rupee (₹) Financial UI & Dashboard**
   - **Net Worth Overview**: `(Liquid Bank Balances + Total Assets) − Total Debts`
   - Native Indian numbering system formatting: `₹1,24,500.00` (Lakhs) and `₹1,24,50,000.00` (Crores).
   - **Category Expense Breakdown**: Monthly proportional progress bars and breakdown stats.
   - **Manual Management**:
     - Modal bottom sheet to log manual cash transactions.
     - Full CRUD modals for physical/liquid assets (Gold, Stocks, Mutual Funds, Real Estate, Fixed Deposits).
     - Full CRUD modals for liabilities and debts (Home Loans, Auto Loans, Personal Loans, Credit Card dues).
   - **Interactive SMS / Notification Sandbox**: Built-in test sandbox to test any SMS or push notification in real time.

---

## Architecture Overview

```
lib/
├── core/
│   ├── constants/
│   │   ├── app_constants.dart
│   │   └── indian_banking_constants.dart
│   ├── theme/
│   │   ├── app_colors.dart
│   │   └── app_theme.dart
│   └── utils/
│       ├── currency_formatter.dart
│       └── date_formatter.dart
├── data/
│   ├── database/
│   │   ├── app_database.dart
│   │   └── tables/
│   │       ├── accounts_table.dart
│   │       ├── balance_sheet_table.dart
│   │       └── transactions_table.dart
│   ├── models/
│   │   ├── account_model.dart
│   │   ├── balance_sheet_item_model.dart
│   │   ├── parsed_transaction.dart
│   │   └── transaction_model.dart
│   ├── repositories/
│   │   ├── account_repository.dart
│   │   ├── balance_sheet_repository.dart
│   │   └── transaction_repository.dart
│   └── secure_storage/
│       └── secure_storage_service.dart
├── services/
│   ├── ingestion/
│   │   ├── notification_listener_channel.dart
│   │   └── gmail_reader_service.dart
│   ├── parsing/
│   │   ├── engine_a_ai_parser.dart
│   │   ├── engine_b_regex_parser.dart
│   │   └── transaction_parser_pipeline.dart
│   └── net_worth/
│       └── net_worth_calculator.dart
├── presentation/
│   ├── controllers/
│   │   ├── balance_sheet_controller.dart
│   │   ├── dashboard_controller.dart
│   │   ├── settings_controller.dart
│   │   └── transaction_controller.dart
│   ├── screens/
│   │   ├── balance_sheet/
│   │   ├── dashboard/
│   │   ├── settings/
│   │   ├── transactions/
│   │   └── main_shell_screen.dart
│   └── widgets/
│       ├── currency_text.dart
│       └── engine_badge.dart
└── main.dart
```

---

## Native Android Setup

In `android/app/src/main/AndroidManifest.xml`:
- `android.permission.BIND_NOTIFICATION_LISTENER_SERVICE` declared for `NotificationListener`.
- `android.permission.INTERNET` declared for BYOK LLM pings and Gmail OAuth API.

In `android/app/src/main/kotlin/com/arthatrack/app/`:
- `NotificationListener.kt`: Captures notification payloads from banking & UPI apps.
- `MainActivity.kt`: Exposes `com.arthatrack.app/notifications` EventChannel and `com.arthatrack.app/notification_control` MethodChannel.

---

## Verification & Testing

To run the verification test suite on the core engines:

```bash
dart run tool/verify_core.dart
```

### Test Coverage Highlights:
- **Currency Formatter**: Indian Lakhs (`₹1,24,500.00`) and Crores (`₹1,24,50,000.00`), compact formats (`₹1.25 L`, `₹2.50 Cr`), and string parsing.
- **Engine B Regex Parser**:
  - HDFC debit SMS (`Rs 460.00 debited from a/c **1234 to SWIGGY. Avl bal Rs 15,240.50`) -> Amount: ₹460, Type: EXPENSE, Merchant: Swiggy, Category: Food, Balance: ₹15,240.50.
  - SBI salary SMS (`credited by INR 75,000.00 on 01-09-26 by SALARY. Bal: INR 88,500.00`) -> Amount: ₹75,000, Type: INCOME, Category: Salary, Balance: ₹88,500.00.
  - ICICI debit (`INR 1,299.00 on 05-Sep-26 by Amazon. Bal: INR 4,320.00`) -> Amount: ₹1,299, Type: EXPENSE, Merchant: Amazon, Category: Shopping.
  - PhonePe Push (`Paid ₹350 to Starbucks on PhonePe`) -> Amount: ₹350, Type: EXPENSE, Merchant: Starbucks, Category: Food.
  - Google Pay Push (`You paid ₹820 to Zepto`) -> Amount: ₹820, Type: EXPENSE, Merchant: Zepto, Category: Groceries.
  - Axis Card SMS (`INR 320.00 spent on Card XX9900 at Uber India`) -> Amount: ₹320, Type: EXPENSE, Merchant: Uber, Category: Travel.
  - Non-transactional message rejection (Login OTPs correctly discarded).
- **Net Worth Calculator**: Positive net worth and deficit calculations according to `(Liquid + Assets) - Debts`.
