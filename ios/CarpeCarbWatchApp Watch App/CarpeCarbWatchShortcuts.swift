import AppIntents

struct CarpeCarbWatchShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: LogFoodIntent(),
            phrases: [
                "Log food in \(.applicationName)",
                "Add food to \(.applicationName)",
                "Track food in \(.applicationName)",
                "Ask \(.applicationName)",
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
    }
}
