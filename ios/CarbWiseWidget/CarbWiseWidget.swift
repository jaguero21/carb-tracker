import WidgetKit
import SwiftUI

struct CarbWidgetData {
    let totalCarbs: Double
    let lastFoodName: String
    let lastFoodCarbs: Double
    let dailyGoal: Double?

    static let placeholder = CarbWidgetData(
        totalCarbs: 42.5,
        lastFoodName: "Brown Rice",
        lastFoodCarbs: 45.0,
        dailyGoal: 100.0
    )

    static let empty = CarbWidgetData(
        totalCarbs: 0.0,
        lastFoodName: "",
        lastFoodCarbs: 0.0,
        dailyGoal: nil
    )
}

struct CarbWiseProvider: TimelineProvider {
    func placeholder(in context: Context) -> CarbWiseEntry {
        CarbWiseEntry(date: Date(), data: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (CarbWiseEntry) -> Void) {
        completion(CarbWiseEntry(date: Date(), data: loadData()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<CarbWiseEntry>) -> Void) {
        let entry = CarbWiseEntry(date: Date(), data: loadData())
        let refreshDate = Calendar.current.date(byAdding: .minute, value: 15, to: Date())!
        let timeline = Timeline(entries: [entry], policy: .after(refreshDate))
        completion(timeline)
    }

    private func loadData() -> CarbWidgetData {
        let defaults = UserDefaults(suiteName: "group.com.jamesaguero.mycarbtracker")
        let goalValue = defaults?.double(forKey: "dailyCarbGoal") ?? 0.0
        return CarbWidgetData(
            totalCarbs: defaults?.double(forKey: "totalCarbs") ?? 0.0,
            lastFoodName: defaults?.string(forKey: "lastFoodName") ?? "",
            lastFoodCarbs: defaults?.double(forKey: "lastFoodCarbs") ?? 0.0,
            dailyGoal: goalValue > 0 ? goalValue : nil
        )
    }
}

struct CarbWiseEntry: TimelineEntry {
    let date: Date
    let data: CarbWidgetData
}

// MARK: - Shared Colors

private let sage = Color(red: 125/255, green: 155/255, blue: 118/255)
private let terracotta = Color(red: 212/255, green: 113/255, blue: 78/255)

// MARK: - Goal Ring

struct GoalRingView: View {
    let progress: Double
    let isOver: Bool

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.primary.opacity(0.08), lineWidth: 4)
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    isOver ? terracotta : sage,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
    }
}

// MARK: - Glass Modifiers

struct GlassCapsuleModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOSApplicationExtension 26.0, *) {
            content.glassEffect(.regular, in: .capsule)
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
        }
    }
}

struct GlassRoundedModifier: ViewModifier {
    var cornerRadius: CGFloat = 12

    func body(content: Content) -> some View {
        if #available(iOSApplicationExtension 26.0, *) {
            content.glassEffect(.regular, in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            content
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: cornerRadius))
        }
    }
}

// MARK: - Small Widget View

struct CarbWiseSmallView: View {
    var entry: CarbWiseProvider.Entry

    private var isOver: Bool {
        guard let goal = entry.data.dailyGoal else { return false }
        return entry.data.totalCarbs > goal
    }

    var body: some View {
        VStack(alignment: .center, spacing: 0) {
            Spacer()

            VStack(spacing: 8) {
                if let goal = entry.data.dailyGoal {
                    ZStack {
                        GoalRingView(
                            progress: entry.data.totalCarbs / goal,
                            isOver: isOver
                        )
                        .frame(width: 100, height: 100)

                        Text(String(format: "%.0fg", entry.data.totalCarbs))
                            .font(.system(size: 28, weight: .light, design: .rounded))
                            .foregroundStyle(.primary)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                    }

                    if isOver {
                        Text(String(format: "+%.0fg over", entry.data.totalCarbs - goal))
                            .font(.system(size: 14))
                            .foregroundStyle(terracotta)
                    } else {
                        Text(String(format: "%.0fg left", goal - entry.data.totalCarbs))
                            .font(.system(size: 14))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(String(format: "%.1fg", entry.data.totalCarbs))
                        .font(.system(size: 52, weight: .light, design: .rounded))
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)

                    Text("total carbs")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }

                if !entry.data.lastFoodName.isEmpty {
                    HStack {
                        Text(entry.data.lastFoodName)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Spacer()
                        Text(String(format: "%.1fg", entry.data.lastFoodCarbs))
                            .font(.system(size: 13, weight: .light))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .modifier(GlassCapsuleModifier())
                }
            }

            Spacer()
        }
        .padding(12)
    }
}

// MARK: - Medium Widget View

struct CarbWiseMediumView: View {
    var entry: CarbWiseProvider.Entry

    private var isOver: Bool {
        guard let goal = entry.data.dailyGoal else { return false }
        return entry.data.totalCarbs > goal
    }

    var body: some View {
        HStack(spacing: 12) {
            // Left: Goal ring or large number
            VStack(spacing: 4) {
                if let goal = entry.data.dailyGoal {
                    ZStack {
                        GoalRingView(
                            progress: entry.data.totalCarbs / goal,
                            isOver: isOver
                        )
                        .frame(width: 90, height: 90)

                        Text(String(format: "%.0fg", entry.data.totalCarbs))
                            .font(.system(size: 24, weight: .light, design: .rounded))
                            .foregroundStyle(.primary)
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                    }

                    if isOver {
                        Text(String(format: "+%.0fg over", entry.data.totalCarbs - goal))
                            .font(.system(size: 12))
                            .foregroundStyle(terracotta)
                    } else {
                        Text(String(format: "%.0fg left", goal - entry.data.totalCarbs))
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(String(format: "%.1fg", entry.data.totalCarbs))
                        .font(.system(size: 42, weight: .light, design: .rounded))
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)

                    Text("total carbs")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(maxWidth: .infinity)

            // Right: Last food + app name
            VStack(alignment: .leading, spacing: 8) {
                Text("CarpeCarb")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                if !entry.data.lastFoodName.isEmpty {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Last logged")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        Text(entry.data.lastFoodName)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        Text(String(format: "%.1fg carbs", entry.data.lastFoodCarbs))
                            .font(.system(size: 13, weight: .light))
                            .foregroundStyle(.secondary)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .modifier(GlassRoundedModifier())
                } else {
                    Text("No foods logged yet")
                        .font(.system(size: 14))
                        .foregroundStyle(.secondary)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .padding(12)
    }
}

// MARK: - Entry View Router

struct CarbWiseWidgetEntryView: View {
    @Environment(\.widgetFamily) var widgetFamily
    var entry: CarbWiseProvider.Entry

    var body: some View {
        switch widgetFamily {
        case .systemMedium:
            CarbWiseMediumView(entry: entry)
        default:
            CarbWiseSmallView(entry: entry)
        }
    }
}

// MARK: - Widget Configuration

struct CarbWiseWidget: Widget {
    let kind: String = "CarbWiseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CarbWiseProvider()) { entry in
            CarbWiseWidgetEntryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("CarpeCarb")
        .description("Track your daily carb intake at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct CarbWiseWidgetBundle: WidgetBundle {
    var body: some Widget {
        CarbWiseWidget()
    }
}
