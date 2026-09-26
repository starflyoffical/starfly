#!/usr/bin/env python3
"""Ensure StarFly no longer contacts a backend or auto-uploads diagnostics."""
from pathlib import Path
import plistlib

root = Path(__file__).resolve().parents[1]
swift_root = root / "RoamControl"
swift_sources = list(swift_root.rglob("*.swift"))
swift_text = "\n".join(path.read_text(encoding="utf-8") for path in swift_sources)

for forbidden in (
    "URLSession",
    "https://starfly.us3-dcb.vproxy.cloud",
    "/api/v1/",
    "TelemetryDeck",
    "StarFlyLicenseManager",
    "FlowerRouteAPI",
    "UsageAnalyticsService",
    "uploadDiagnosticReport",
    "FailureDiagnosticSnapshot",
):
    assert forbidden not in swift_text, f"Unexpected server/reporting code: {forbidden}"

for removed in (
    "RoamControl/Services/StarFlyLicenseManager.swift",
    "RoamControl/Features/License/LicenseGateView.swift",
    "RoamControl/Features/Map/FlowerRoutePickerView.swift",
    "RoamControl/Services/UsageAnalyticsService.swift",
    "RoamControl/Features/Settings/UsageStatisticsPrivacyView.swift",
):
    assert not (root / removed).exists(), f"Removed feature still exists: {removed}"

app_info = plistlib.loads((root / "Configuration/RoamControl-Info.plist").read_bytes())
for key in (
    "StarFlyLicenseRequired",
    "StarFlyLicenseAPIURL",
    "StarFlyDiagnosticsAPIURL",
    "StarFlyTelemetryAppID",
    "StarFlySelfHostedTelemetryEndpoint",
    "StarFlySelfHostedTelemetryToken",
):
    assert key not in app_info, f"Backend setting remains in Info.plist: {key}"

home = (root / "RoamControl/Features/Home/HomeView.swift").read_text(encoding="utf-8")
header = (root / "RoamControl/Features/Home/StarFlyControlHeader.swift").read_text(encoding="utf-8")
assert "FlowerRoutePickerView" not in home and "flowerRoutes" not in home
assert "花路列表" not in header
assert "RouteImportView" in home, "Manual local route import should remain available"
assert "URLSession" not in (root / "RoamControl/Features/Settings/ConnectionHealthView.swift").read_text(encoding="utf-8")

print("No StarFly backend, license check, administrator route fetch or automatic telemetry remains.")
