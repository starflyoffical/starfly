# Build and Release Guide

This guide covers StarFly development builds and IPA packaging.

## Current release identity

- Marketing version: `2.0.0`
- Current build: `61`
- Bundle identifier: `com.starfly.app`
- Minimum deployment target: iOS 26
- Supported device family: iPhone

The version and build are shown in **Settings** inside the app. The built date and time come from the timestamp embedded for that packaged build.

## Version and build rules

Roam Control uses two separate numbers:

- The **version** describes the public release. Increase it for each public beta or stable release.
- The **build** identifies one exact install. Increase it once for every build installed on a test iPhone or packaged as an IPA.

Ordinary compile checks do not consume a build number. Build numbers must never move backwards for a later install or upload.

Both values are stored in the target build settings:

- `MARKETING_VERSION`
- `CURRENT_PROJECT_VERSION`

Keep the Debug and Release configurations identical.

## Build in Xcode

1. Open `RoamControl.xcodeproj`.
2. Select the **RoamControl** scheme.
3. Select the connected iPhone.
4. Open **Signing & Capabilities** and confirm the development team.
5. Press **Run**.

The simulator can validate most interface states, but it cannot perform the real RPPairing handshake or start a location session.

## Native pairing engine

The prebuilt `Frameworks/RoamPairingFFI.xcframework` should be committed with both arm64 iPhone and arm64 Apple Silicon simulator slices.

Only rebuild it after changing `Native/RoamPairingFFI`. The rebuild requires Rust targets for:

- `aarch64-apple-ios`
- `aarch64-apple-ios-sim`

Run `scripts/build-pairing-engine.sh` from the project directory. Confirm the app still builds for both a physical iPhone and the simulator afterwards.

## Archive preparation

Before creating an archive:

1. Finish the regression checklist.
2. Increase `CURRENT_PROJECT_VERSION` for the archive.
3. Confirm the public version.
4. Use the Release configuration.
5. Confirm the app icon and display name.
6. Set and verify the build timestamp.
7. Confirm `RoamPairingFFI.xcframework` is embedded and signed.
8. Build once for a physical iPhone.

Then select **Any iOS Device (arm64)** and choose **Product → Archive**. Xcode opens Organizer after a successful archive.

## IPA and SideStore

StarFly's Actions workflow builds an unsigned Release archive and packages the app together with `StarFlyLiveActivity.appex`. The pairing engine is statically linked into the app binary. The Live Activity extension is a separate required app extension: keep it embedded and sign it along with the app if you want route status on the Lock Screen and Dynamic Island.

An unsigned IPA is a package, not an install-ready signed app. The sideloading/signing tool must re-sign both `com.starfly.app` and `com.starfly.app.liveactivity` with compatible provisioning profiles from the same team. A tool or certificate workflow that rejects or strips app extensions may install only an extension-free app, but Dynamic Island/Live Activity support will not work in that build. Do not remove the extension when producing the full StarFly build.

For personal SideStore installation:

1. Use the verified IPA from the Actions artifact or a matching GitHub Release.
2. Move the IPA to Files or another location SideStore can access.
3. Open SideStore, choose the IPA and allow it to sign/install the app and embedded extension with the configured Apple ID.
4. Keep Developer Mode enabled.
5. Complete Roam Control's pairing on the installed copy if its signing identity gives it a new Keychain container.

SideStore re-signing and Apple's free-account limits can affect expiry, app identifiers and available entitlements. The final IPA must therefore be tested as a SideStore install rather than assuming an Xcode-installed build is equivalent. With a free Apple Account, SideStore normally refreshes the signed installation within Apple's seven-day development period.

Do not treat an Xcode Debug `.app` folder renamed to `.ipa` as a release package. Use the verified Release archive/package workflow.

## App network behavior

StarFly does not call a StarFly backend, verify license codes, download administrator routes or transmit usage statistics and diagnostics. Apple MapKit and LocalDevVPN remain external platform services required for their respective map and local-pairing features. See [Privacy](Privacy.md) for details.

## Release records

For each distributed build, record:

- Version and build number.
- Date and time created.
- Xcode and iOS versions used.
- Signing method.
- Device used for testing.
- Regression checklist result.
- Known issues.

This makes a problem report traceable to the exact binary shown in Roam Control's Settings screen.
