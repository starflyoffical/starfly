# Installation

StarFly is not distributed through the App Store or TestFlight. Test builds are supplied as unsigned IPA files for users to sign with their own Apple account.

## Requirements

- An iPhone running iOS 26 or newer.
- Developer Mode enabled under **Settings → Privacy & Security**.
- [LocalDevVPN](https://apps.apple.com/app/localdevvpn/id6755608044) installed on the iPhone.
- SideStore, or Xcode on a Mac with an Apple development team.

## Install with SideStore

1. Download the IPA attached to the matching GitHub Release. Do not download an IPA from an untrusted mirror.
2. In SideStore, tap **+** and choose the downloaded IPA.
3. Allow SideStore to sign and install StarFly with your Apple account.
4. Open StarFly and complete its introduction and device-pairing flow.
5. Open LocalDevVPN and enable its local tunnel before starting a location.

Free Apple accounts normally require sideloaded apps to be refreshed within seven days and limit the number of simultaneously active apps/App IDs. These are Apple signing limits, not Roam Control subscriptions.

When updating, install the newer IPA over the existing copy. Deleting the app first also deletes its local settings and may require pairing again.

## Build with Xcode

1. Clone the repository and open `RoamControl.xcodeproj`.
2. Select the StarFly app target and choose your own team under **Signing & Capabilities**.
3. Select a connected iPhone and press **Run**.

The tracked build configuration has no Apple team. Xcode may save your selected team locally. Do not commit signing material or `Configuration/Local.private.xcconfig`. The Live Activity extension must also be signed with the same team; sideloading tools that remove app extensions cannot provide Dynamic Island support.

The simulator can test the interface but cannot complete the physical iPhone pairing handshake or start a real location session.

## Verify a release

Each Actions package includes a SHA-256 checksum. On a Mac, calculate the checksum of the IPA you downloaded:

```sh
shasum -a 256 StarFly-unsigned.ipa
```

Compare the result with the SHA-256 value shown on the matching GitHub Release before installing it.

See the [user guide](UserGuide.md) for pairing and everyday operation.
