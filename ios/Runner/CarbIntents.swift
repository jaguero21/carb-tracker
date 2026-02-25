import AppIntents

// Shared logic (CarbDataStore, EnvReader, PerplexityClient, LogFoodIntent,
// CheckCarbsIntent) lives in CarbShared.swift which is compiled into both
// the Runner and Watch targets.

// MARK: - Open App Intent (iOS only)

struct OpenCarpeCarbIntent: AppIntent {
    static var title: LocalizedStringResource = "Open CarpeCarb"
    static var description = IntentDescription("Open the CarpeCarb app.")

    static var openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}
