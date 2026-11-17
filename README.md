# XO Meter — iPhone App, Native SwiftUI V0.2

An iPhone application starter implementation of XO Meter: household electricity scanning, historical-bill prediction, appliance tracking, and unofficial digital statements. Black and ultraviolet design with translucent panels and native animations.

## Included now

- SwiftUI five-tab app: Home, Scan, Saver, Bills, Settings
- Native iPhone camera capture **and** Photos library import for meter and bill photos
- Apple Vision OCR performed on-device; scanned numbers are **never silently saved**
- Meter reading review and reading history
- Previous bill OCR suggestions + editable verification form, with optional update of historical reference
- Reading validation (present - previous) and historical effective-rate estimator
- Appliance inventory: create, edit, remove; quantity, watts, daily hours, days monthly, or kWh/day energy label
- Energy-use bar chart, monthly estimate, monthly peso budget display
- Unofficial PDF statement; iOS share sheet supports Print where available
- Local on-device JSON records via UserDefaults (prototype storage)
- Animated tab changes, translucent cards, meter OCR scan beam
- XcodeGen configuration and GitHub Actions unsigned IPA workflow
- Standalone Swift billing unit tests (can run on macOS/Linux)

## IMPORTANT limitations

This is a **development build**, not a complete utility billing system. OCR extraction quality depends on photo quality and bill layout. Importing bill amounts requires user verification. Meter serial numbers, kW values, and cumulative kWh values can be confused. No official tariffs are fetched, no payment processing occurs, and no generated document is a utility bill or proof of payment. Camera only works on a real device. Readings do not update automatically without a connected meter. Do not use estimates as proof of debt or payment.

## Your example data

- October 2026 ZANECO: previous 9,668; present 9,851; usage 183 kWh; current bill ₱2,755.09.
- November 17 photographed meter: 9,991 kWh; 140 kWh since October's reading.
- October arrears confirmed paid; outstanding balance defaults to ₱0.
- Samsung RT22FARBDSA: energy label **0.74 kWh/day** under test conditions.
- Clip fan is an illustration (20 W / 8 h/day); desktop PC and television are placeholders awaiting wattage and hours.
- Current on-device calculated cost is based on **October's historical effective rate**, not guaranteed November tariffs.

## Windows + GitHub build steps

1. Create an empty GitHub repository (e.g., `XO-Meter`) and upload the **contents** of this ZIP to the repository root. Ensure `.github/workflows/build-ipa.yml` exists in the repo (Windows sometimes hides `.github`).
2. Open **Actions → Build XO Meter (Unsigned IPA) → Run workflow**, or push changes to `main`.
3. The hosted `macos-15` machine installs XcodeGen, generates `XOMeter.xcodeproj`, runs the billing tests, compiles the iOS app with signing disabled, and uploads `XO-Meter-unsigned-IPA` as a workflow artifact.
4. Download the ZIP artifact from the workflow summary and extract `XOMeter-unsigned.ipa`.
5. **An unsigned IPA cannot normally be installed directly.** To install on your own iPhone, the app needs Apple signing/provisioning through an appropriate Apple developer workflow or other authorized installation method. GitHub Actions does not bypass Apple signing requirements.

Note: The workflow is provided but **has not been executed on a macOS runner in this environment**. Local Swift syntax parsing and billing arithmetic tests passed; Xcode compilation still needs confirmation.

## Optional Mac build

Install Xcode and XcodeGen, run `xcodegen generate`, then open `XOMeter.xcodeproj`, choose an Apple development team, and run on a connected iPhone.

## Next engineering milestones

- End-to-end GitHub runner compile and fix any Xcode/SDK compatibility problems.
- Stronger ZANECO-specific OCR layout understanding; itemized charge parsing with confidence review.
- Durable document/photo storage in app sandbox or SwiftData; encrypted protection for sensitive identifiers.
- Monthly historical bill ledger, meter dates, user-defined reading reminders, cutoff projections.
- Receipt template sizing (58mm, 80mm, A4), QR verification linked to actual saved statements.
- App icon, launch screen and expanded accessibility, unit and UI tests.

## Important safety note

Do not recommend switching off refrigerators overnight to reduce electricity. Appliance estimates depend on actual operating hours and typical power, which can vary greatly from nameplate ratings. Food-safe refrigerator temperature must be verified independently.
