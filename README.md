# Folio

A private document vault for iPhone: IDs, passports, driver's licenses and more, organised in 3D folders per person.
It is built in native SwiftUI with Apple's iOS 26 Liquid Glass.

- **Requires iOS 26 or later.**
- **Fully on device.** Scans are encrypted with AES-GCM 256, the key is kept in the Keychain (this device only), and the app is locked with Face ID.
- **Fast entry.** The VisionKit document scanner captures each side, and on-device OCR suggests the document number and dates.
- **Expiry reminders** 90, 30 and 7 days before a document expires, plus a Key Dates timeline.

## Build

GitHub Actions (`.github/workflows/build-ipa.yml`) builds everything on a `macos-26` runner:

1. `xcodegen generate` creates `Folio.xcodeproj` from `project.yml`.
2. An unsigned Release archive is packaged as `Folio.ipa` and uploaded as the **Folio-ipa** artifact. Pushing a `v*` tag also attaches it to a GitHub Release.
3. Unit tests run on the iOS Simulator. Screenshots of the demo data are uploaded as the **screenshots** artifact.

## Install on your iPhone

The IPA is unsigned. Install it with [Sideloadly](https://sideloadly.io) or AltStore using your Apple ID. With a free Apple ID, the app has to be re-signed every 7 days.

## Local development (Mac)

```bash
brew install xcodegen
xcodegen generate
open Folio.xcodeproj
```

Launch arguments `-demoData YES -screen home|fan|person|document|flipped|expiring|add` load sample data, skip the lock, and open a specific screen.
