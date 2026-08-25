# Secure Dynamic QR Codes for iOS

An iOS reference app for OCPP 2.1 (Edition 2), use case C25 “Ad hoc payment via a QR code”.

The app covers both sides of the secure dynamic QR-code flow:

- Generate an HTTPS URL and QR code from an EVSE ID, shared secret and OCPP C25 TOTP.
- Display the current token and its remaining validity.
- Scan a QR code and verify its token against the previous, current and next time slot.
- Report URLs that do not match the configured template.

All token generation and camera processing happens on the device. The app has no analytics, advertising or backend dependency.

## Requirements

- macOS with Xcode 26 or newer
- iOS 17 or newer
- [Mint](https://github.com/yonaskolb/Mint) 0.18 or newer

Install Mint with Homebrew:

~~~sh
brew install mint
~~~

## Generate the Xcode project

XcodeGen is pinned to version 2.46.0 in Mintfile. Generated Xcode projects are intentionally not committed.

~~~sh
mint bootstrap
mint run xcodegen generate
open DynamicQRCodes.xcodeproj
~~~

## Build and test

~~~sh
mint run xcodegen generate
xcodebuild \
  -project DynamicQRCodes.xcodeproj \
  -scheme DynamicQRCodes \
  -destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
  test
~~~

The XCTest suite includes the shared OCPP TOTP conformance vectors, rejection cases, neighbouring-slot validation and URL-template tests.

Camera scanning must additionally be tested on a physical iPhone or iPad.

## Release checklist

- Configure the Apple Developer team and register cloud.charging.open.dynamicqrcodes.
- Build a Release archive with Xcode 26 and validate it in Organizer.
- Confirm export-compliance answers for the CryptoKit HMAC use.
- Publish the privacy policy and complete App Privacy answers in App Store Connect.
- Add localized App Store description, support URL, screenshots and review notes.
- Complete a physical-device and TestFlight pass.

## Privacy

See [PRIVACY.md](PRIVACY.md).

## License

Apache License 2.0. See [LICENSE](LICENSE).
