#!/usr/bin/env python3
"""Check release identity, local-only data behavior and app invariants."""

from pathlib import Path
import hashlib
import json
import plistlib
import struct


ROOT = Path(__file__).resolve().parents[1]

project = (ROOT / "RoamControl.xcodeproj/project.pbxproj").read_text(encoding="utf-8")
assert project.count("CURRENT_PROJECT_VERSION = 61;") == 4
assert project.count("MARKETING_VERSION = 2.0.0;") == 4
assert project.count("PRODUCT_BUNDLE_IDENTIFIER = com.starfly.app;") == 2
assert project.count("PRODUCT_BUNDLE_IDENTIFIER = com.starfly.app.liveactivity;") == 2
assert "StarFlyLiveActivity.appex in Embed App Extensions" in project
assert project.count("C00000000000000000000004 /* Shared */") >= 3

logo_paths = (
    ROOT / "RoamControl/Resources/Assets.xcassets/StarFlyBrand.imageset/StarFly-AppIcon-v2.png",
    ROOT / "RoamControl/Resources/Assets.xcassets/AppIcon.appiconset/StarFly-AppIcon-v2.png",
    ROOT / "StarFlyLiveActivity/Assets.xcassets/StarFlyBrand.imageset/StarFlyBrand.png",
)
logo_hashes = set()
for logo_path in logo_paths:
    image = logo_path.read_bytes()
    assert image[:8] == b"\x89PNG\r\n\x1a\n"
    assert image[12:16] == b"IHDR"
    assert struct.unpack(">II", image[16:24]) == (1024, 1024)
    logo_hashes.add(hashlib.sha256(image).hexdigest())
assert len(logo_hashes) == 1

for catalog_path in (
    ROOT / "RoamControl/Resources/Assets.xcassets/StarFlyBrand.imageset/Contents.json",
    ROOT / "RoamControl/Resources/Assets.xcassets/AppIcon.appiconset/Contents.json",
    ROOT / "StarFlyLiveActivity/Assets.xcassets/Contents.json",
    ROOT / "StarFlyLiveActivity/Assets.xcassets/StarFlyBrand.imageset/Contents.json",
):
    json.loads(catalog_path.read_text(encoding="utf-8"))

activity_bundle = (ROOT / "StarFlyLiveActivity/StarFlyLiveActivityBundle.swift").read_text(encoding="utf-8")
activity_attributes = (ROOT / "Shared/StarFlyWalkingActivityAttributes.swift").read_text(encoding="utf-8")
waypoint_intents = (ROOT / "Shared/RouteWaypointIntents.swift").read_text(encoding="utf-8")
walking_simulation = (ROOT / "RoamControl/Features/Map/WalkingSimulationController.swift").read_text(encoding="utf-8")
health_step_writer = (ROOT / "RoamControl/Services/HealthStepWriter.swift").read_text(encoding="utf-8")
health_steps_view = (ROOT / "RoamControl/Features/Settings/HealthStepsView.swift").read_text(encoding="utf-8")
assert "ActivityConfiguration" in activity_bundle and "DynamicIsland" in activity_bundle
assert "PreviousRouteWaypointIntent" in activity_bundle and "NextRouteWaypointIntent" in activity_bundle
assert "DecreaseWalkingSpeedIntent" in activity_bundle and "IncreaseWalkingSpeedIntent" in activity_bundle
assert "ToggleWalkingPauseIntent" in activity_bundle
assert "DynamicIslandExpandedRegion(.bottom)" in activity_bundle
assert "supportsWaypointNavigation" in activity_attributes
assert "struct PreviousRouteWaypointIntent: LiveActivityIntent" in waypoint_intents
assert "struct NextRouteWaypointIntent: LiveActivityIntent" in waypoint_intents
assert "struct DecreaseWalkingSpeedIntent: LiveActivityIntent" in waypoint_intents
assert "struct IncreaseWalkingSpeedIntent: LiveActivityIntent" in waypoint_intents
assert "struct ToggleWalkingPauseIntent: LiveActivityIntent" in waypoint_intents
assert "starFlyLiveActivityWaypointNavigation" in walking_simulation
assert "starFlyLiveActivitySpeedAdjustment" in walking_simulation
assert "starFlyLiveActivityPauseToggle" in walking_simulation
assert "supportsWaypointNavigation: true" in (ROOT / "RoamControl/Features/Home/HomeView.swift").read_text(encoding="utf-8")
assert "struct StarFlyWalkingActivityAttributes: ActivityAttributes" in activity_attributes
assert project.count('INFOPLIST_FILE = "Configuration/StarFlyLiveActivity-Info.plist";') == 2
assert "automaticStartDate(for steps: Int" in health_step_writer
assert "requestAuthorization(toShare: [stepType], read: [])" in health_step_writer
assert "func addSteps(_ totalSteps: Int, sampleCount requestedSampleCount: Int? = nil)" in health_step_writer
assert "deleteStepSamples" not in health_step_writer
assert "fetchStepSamplesWrittenByStarFly" not in health_step_writer
assert "DatePicker(" not in health_steps_view
assert "HealthStepWriter.automaticStartDate(for:" in health_steps_view

with (ROOT / "Configuration/StarFlyLiveActivity-Info.plist").open("rb") as stream:
    extension_build_info = plistlib.load(stream)
assert extension_build_info["NSExtension"]["NSExtensionPointIdentifier"] == "com.apple.widgetkit-extension"

with (ROOT / "Configuration/RoamControl-Info.plist").open("rb") as stream:
    app_info = plistlib.load(stream)
assert app_info["NSSupportsLiveActivities"] is True
for removed_setting in (
    "StarFlySelfHostedTelemetryEndpoint",
    "StarFlySelfHostedTelemetryToken",
    "StarFlyTelemetryAppID",
    "StarFlyLicenseRequired",
    "StarFlyLicenseAPIURL",
    "StarFlyDiagnosticsAPIURL",
):
    assert removed_setting not in app_info

app_sources = list((ROOT / "RoamControl").rglob("*.swift"))
app_text = "\n".join(path.read_text(encoding="utf-8") for path in app_sources)
for removed_service in (
    "URLSession",
    "https://starfly.us3-dcb.vproxy.cloud",
    "/api/v1/",
    "TelemetryDeck",
    "StarFlyLicenseManager",
    "FlowerRouteAPI",
    "UsageAnalyticsService",
    "uploadDiagnosticReport",
):
    assert removed_service not in app_text, f"Server integration remains: {removed_service}"

for removed_path in (
    "RoamControl/Services/StarFlyLicenseManager.swift",
    "RoamControl/Features/License/LicenseGateView.swift",
    "RoamControl/Features/Map/FlowerRoutePickerView.swift",
    "RoamControl/Services/UsageAnalyticsService.swift",
    "RoamControl/Features/Settings/UsageStatisticsPrivacyView.swift",
):
    assert not (ROOT / removed_path).exists()

entry = (ROOT / "RoamControl/App/RoamControlApp.swift").read_text(encoding="utf-8")
app_model = (ROOT / "RoamControl/App/AppModel.swift").read_text(encoding="utf-8")
home = (ROOT / "RoamControl/Features/Home/HomeView.swift").read_text(encoding="utf-8")
header = (ROOT / "RoamControl/Features/Home/StarFlyControlHeader.swift").read_text(encoding="utf-8")
assert "LicenseGateView" not in entry and "StarFlyLicenseManager" not in entry
assert "UsageAnalytics" not in app_model and "sharesAnonymousUsageStatistics" not in app_model
assert "FlowerRoutePickerView" not in home and "flowerRoutes" not in home
assert "花路列表" not in header
assert "RouteImportView" in home, "Manual route import should remain available"
assert 'case .routeImport:' in home

session = (ROOT / "RoamControl/Services/Tunnel/LocalDeviceSessionCoordinator.swift").read_text(encoding="utf-8")
pairing = (ROOT / "RoamControl/Services/Pairing/OnDevicePairingCoordinator.swift").read_text(encoding="utf-8")
health = (ROOT / "RoamControl/Features/Settings/ConnectionHealthView.swift").read_text(encoding="utf-8")
assert "guard taskConfigurationStatus == .permitted," in session
assert "runNativeLocationSession()" in session
assert "taskConfigurationStatus = BackgroundTaskIdentifier.configurationStatus(for: \"pairing\")" in pairing
assert "runNativePairing()" in pairing[pairing.index("func start("):pairing.index("func cancel(")]
assert "Location task configuration:" in health
assert "Pairing task configuration:" in health
assert "複製診斷資料" in health

privacy_manifest = plistlib.loads((ROOT / "RoamControl/Resources/PrivacyInfo.xcprivacy").read_bytes())
assert privacy_manifest["NSPrivacyCollectedDataTypes"] == []
assert "NSPrivacyAccessedAPITypes" in privacy_manifest

private_example = (ROOT / "Configuration/Local.private.xcconfig.example").read_text(encoding="utf-8")
assert "DEVELOPMENT_TEAM" in private_example
assert "TELEMETRY" not in private_example and "INGESTION" not in private_example

print("Release identity, Live Activity, local pairing and no-StarFly-server invariants passed.")
