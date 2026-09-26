#!/usr/bin/env python3
"""Verify an unsigned StarFly IPA contains the app and its Live Activity extension."""

from pathlib import Path
import plistlib
import sys
import zipfile


if len(sys.argv) != 2:
    raise SystemExit("Usage: python3 scripts/test-ipa-structure.py <StarFly.ipa>")

ipa_path = Path(sys.argv[1])
app_info_path = "Payload/StarFly.app/Info.plist"
extension_root = "Payload/StarFly.app/PlugIns/StarFlyLiveActivity.appex"
extension_info_path = f"{extension_root}/Info.plist"

with zipfile.ZipFile(ipa_path) as archive:
    damaged_entry = archive.testzip()
    assert damaged_entry is None, f"Corrupt IPA entry: {damaged_entry}"
    entries = set(archive.namelist())
    assert not any(
        name.startswith("__MACOSX/") or "/._" in name
        for name in entries
    ), "IPA contains macOS resource-fork metadata"
    assert app_info_path in entries, "StarFly.app/Info.plist is missing from IPA"
    assert extension_info_path in entries, "Live Activity extension is missing from IPA"

    app_info = plistlib.loads(archive.read(app_info_path))
    extension_info = plistlib.loads(archive.read(extension_info_path))

    assert app_info.get("CFBundleIdentifier") == "com.starfly.app"
    assert app_info.get("NSSupportsLiveActivities") is True
    for removed_setting in (
        "StarFlyLicenseRequired",
        "StarFlyLicenseAPIURL",
        "StarFlyDiagnosticsAPIURL",
        "StarFlyTelemetryAppID",
        "StarFlySelfHostedTelemetryEndpoint",
    ):
        assert removed_setting not in app_info, f"Removed backend setting remains: {removed_setting}"
    assert extension_info.get("CFBundleIdentifier") == "com.starfly.app.liveactivity"
    extension_dictionary = extension_info.get("NSExtension")
    extension_point = (
        extension_dictionary.get("NSExtensionPointIdentifier")
        if isinstance(extension_dictionary, dict)
        else None
    )
    assert extension_point == "com.apple.widgetkit-extension", (
        "Invalid WidgetKit extension point: "
        f"expected 'com.apple.widgetkit-extension', got {extension_point!r}; "
        f"NSExtension={extension_dictionary!r}"
    )

    executable = extension_info.get("CFBundleExecutable")
    assert executable, "Live Activity extension has no executable in Info.plist"
    assert f"{extension_root}/{executable}" in entries, "Live Activity extension executable is missing"

print("IPA structure passed: StarFly app and Live Activity extension are present.")
