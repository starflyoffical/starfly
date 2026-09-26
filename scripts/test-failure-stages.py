#!/usr/bin/env python3
"""Compile local connection diagnostic labels; this data is never auto-uploaded."""
from pathlib import Path
import json, re, subprocess, tempfile
root = Path(__file__).resolve().parents[1]
enums = (root / 'RoamControl/Services/FailureDiagnostics.swift').read_text(encoding='utf-8')
native = (root / 'Native/RoamPairingFFI/src/lib.rs').read_text(encoding='utf-8')
location = native[native.index('async fn run_location_session('):native.index('fn current_coordinates(')]
messages = re.findall(r'"([^"\n]+)"\.to_string\(\)', location)
assert len(messages) >= 30
checks = [
 'precondition(FailureStage.classify("Roam Control could not confirm stopping location simulation.", fallback: .locationUnknown) == .locationRestore)',
 'precondition(SchedulerFailureReason.classify(NSError(domain: "BGTaskSchedulerErrorDomain", code: 1)) == .unavailable)',
 'precondition(SchedulerFailureReason.classify(NSError(domain: "BGTaskSchedulerErrorDomain", code: 2)) == .tooManyPendingRequests)',
 'precondition(SchedulerFailureReason.classify(NSError(domain: "BGTaskSchedulerErrorDomain", code: 3)) == .notPermitted)',
 'precondition(SchedulerFailureReason.classify(NSError(domain: "BGTaskSchedulerErrorDomain", code: 4)) == .immediateRunIneligible)',
 'precondition(SchedulerFailureReason.classify(NSError(domain: "BGTaskSchedulerErrorDomain", code: 99)) == .unknown)',
 'precondition(SchedulerFailureReason.classify(NSError(domain: "private network detail", code: 4, userInfo: [NSLocalizedDescriptionKey: "credential PIN device name"])) == .unknown)',

 'precondition(FailureDisposition.terminal.rawValue == "terminal")',
 'precondition(FailureDisposition.recoverable.rawValue == "recoverable")',
]
coordinator = (root / 'RoamControl/Services/Tunnel/LocalDeviceSessionCoordinator.swift').read_text(encoding='utf-8')
assert 'FailureDiagnosticSnapshot' not in coordinator
assert 'UsageAnalytics' not in coordinator
for message in messages:
    checks.append('precondition(FailureStage.classify(' + json.dumps(message) + ', fallback: .locationUnknown) != .locationUnknown)')
checks += [
 'precondition(FailureStage.classify("The iPhone rejected the saved pairing session.", fallback: .locationUnknown) == .pairVerification)',
 'precondition(FailureStage.classify("LocalDevVPN did not open the secure tunnel in time.", fallback: .locationUnknown) == .tunnelConnection)',
 'precondition(FailureStage.classify("The iPhone ended the active location session.", fallback: .locationUnknown) == .locationActiveWrite)',
 'precondition(FailureStage.classify("Roam Control could not securely store the new pairing.", fallback: .pairingUnknown) == .pairingStorage)',
 'precondition(FailureStage.classify("private device name PIN 123456 coordinates 51.5,-0.1", fallback: .locationUnknown) == .locationUnknown)',
 'precondition(FailureStage.classify("unknown credentials", fallback: .pairingUnknown) == .pairingUnknown)',
 'precondition(FailureStage.allCases.allSatisfy { $0.rawValue.allSatisfy { $0.isLetter } })',
]
with tempfile.TemporaryDirectory() as temp:
    source = Path(temp) / 'main.swift'
    source.write_text(enums + '\n' + '\n'.join(checks) + '\nprint("Failure-stage checks passed")\n')
    subprocess.run(['xcrun', 'swiftc', '-module-cache-path', str(Path(temp) / 'cache'), str(source), '-o', str(Path(temp) / 'check')], check=True)
    subprocess.run([str(Path(temp) / 'check')], check=True)
print(f'Covered {len(messages)} native location error messages; no network requests made.')
