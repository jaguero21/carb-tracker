import AppIntents

struct CarpeCarbShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogFoodIntent(),
            phrases: [
                "Log food in \(.applicationName)",
                "Ask \(.applicationName)",
                "Add food to \(.applicationName)",
                "Track food in \(.applicationName)",
            ],
            shortTitle: "Log Food",
            systemImageName: "plus.circle.fill"
        )

        AppShortcut(
            intent: CheckCarbsIntent(),
            phrases: [
                "How many carbs today in \(.applicationName)",
                "Check my carbs in \(.applicationName)",
                "\(.applicationName) carb count",
            ],
            shortTitle: "Check Carbs",
            systemImageName: "leaf.fill"
        )

        AppShortcut(
            intent: OpenCarpeCarbIntent(),
            phrases: [
                "Open \(.applicationName)",
            ],
            shortTitle: "Open CarpeCarb",
            systemImageName: "arrow.up.forward.app.fill"
        )
    }
}
