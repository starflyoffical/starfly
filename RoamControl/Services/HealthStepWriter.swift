import Foundation
import HealthKit

enum HealthStepWriteError: LocalizedError {
    case unavailable
    case authorizationNotGranted
    case invalidStepCount
    case paceTooHigh
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .unavailable:
            "此裝置目前無法使用 Apple 健康資料。"
        case .authorizationNotGranted:
            "尚未允許 StarFly 將步數寫入 Apple 健康。"
        case .invalidStepCount:
            "請輸入大於 0 的步數。"
        case .paceTooHigh:
            "平均步頻過高，請確認步數後再試。"
        case .saveFailed:
            "無法寫入 Apple 健康，請稍後再試。"
        }
    }

    func message(for language: String) -> String {
        guard language == "en" else { return errorDescription ?? "" }
        switch self {
        case .unavailable:
            return "Apple Health isn’t available on this device."
        case .authorizationNotGranted:
            return "StarFly hasn’t been allowed to write steps to Apple Health."
        case .invalidStepCount:
            return "Enter a step count greater than zero."
        case .paceTooHigh:
            return "The average cadence is too high. Check the step count and try again."
        case .saveFailed:
            return "Couldn’t write to Apple Health. Please try again later."
        }
    }
}

@MainActor
final class HealthStepWriter {
    private let healthStore = HKHealthStore()

    /// The entry always ends now; its start is chosen to keep the cadence plausible.
    static func automaticStartDate(for steps: Int, endingAt endDate: Date = .now) -> Date {
        let durationMinutes = max(1, Double(max(steps, 1)) / 90)
        return endDate.addingTimeInterval(-durationMinutes * 60)
    }

    static func estimatedSampleCount(
        for steps: Int,
        startingAt startDate: Date,
        endingAt endDate: Date = .now
    ) -> Int {
        let requestedCount = min(max((steps + 34) / 35, 1), 300)
        return min(
            requestedCount,
            maximumAllowedSampleCount(for: steps, startingAt: startDate, endingAt: endDate)
        )
    }

    static func maximumAllowedSampleCount(
        for steps: Int,
        startingAt startDate: Date,
        endingAt endDate: Date = .now
    ) -> Int {
        let duration = max(endDate.timeIntervalSince(startDate), 0)
        let maximumCountForInterval = max(Int(duration / 12), 1)
        return min(max(steps, 1), min(300, maximumCountForInterval))
    }

    func addSteps(_ totalSteps: Int, sampleCount requestedSampleCount: Int? = nil) async throws -> Int {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthStepWriteError.unavailable
        }
        guard totalSteps > 0 else {
            throw HealthStepWriteError.invalidStepCount
        }
        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount) else {
            throw HealthStepWriteError.unavailable
        }

        try await requestWriteAuthorization(for: stepType)
        guard healthStore.authorizationStatus(for: stepType) == .sharingAuthorized else {
            throw HealthStepWriteError.authorizationNotGranted
        }

        // Start when the user completes authorization; every sample ends at this snapshot.
        let endDate = Date.now
        let startDate = Self.automaticStartDate(for: totalSteps, endingAt: endDate)
        let interval = endDate.timeIntervalSince(startDate)
        guard interval > 0, Double(totalSteps) / interval * 60 <= 180 else {
            throw HealthStepWriteError.paceTooHigh
        }

        let defaultSampleCount = Self.estimatedSampleCount(
            for: totalSteps,
            startingAt: startDate,
            endingAt: endDate
        )
        let maximumSampleCount = Self.maximumAllowedSampleCount(
            for: totalSteps,
            startingAt: startDate,
            endingAt: endDate
        )
        let sampleCount = min(max(requestedSampleCount ?? defaultSampleCount, 1), maximumSampleCount)
        let baseSteps = totalSteps / sampleCount
        let remainder = totalSteps % sampleCount
        let spacing = interval / Double(sampleCount)

        let samples = (0..<sampleCount).map { index in
            let sampleStart = startDate.addingTimeInterval(Double(index) * spacing)
            let sampleEnd = min(sampleStart.addingTimeInterval(spacing), endDate)
            let stepCount = baseSteps + (index < remainder ? 1 : 0)
            let quantity = HKQuantity(unit: .count(), doubleValue: Double(stepCount))
            return HKQuantitySample(
                type: stepType,
                quantity: quantity,
                start: sampleStart,
                end: sampleEnd,
                metadata: [HKMetadataKeyWasUserEntered: true]
            )
        }

        try await save(samples)
        return sampleCount
    }

    private func requestWriteAuthorization(for stepType: HKQuantityType) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.requestAuthorization(toShare: [stepType], read: []) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthStepWriteError.authorizationNotGranted)
                }
            }
        }
    }

    private func save(_ samples: [HKQuantitySample]) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            healthStore.save(samples) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: HealthStepWriteError.saveFailed)
                }
            }
        }
    }
}
