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

struct GoalRingView: View {
    let progress: Double
    let isOver: Bool

    private let sage = Color(red: 125/255, green: 155/255, blue: 118/255)
    private let terracotta = Color(red: 212/255, green: 113/255, blue: 78/255)

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

struct GlassEffectModifier: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOSApplicationExtension 26.0, *) {
            content.glassEffect(.regular, in: .capsule)
        } else {
            content
                .background(.ultraThinMaterial, in: Capsule())
        }
    }
}

struct CarbWiseWidgetEntryView: View {
    var entry: CarbWiseProvider.Entry

    private let sage = Color(red: 125/255, green: 155/255, blue: 118/255)
    private let terracotta = Color(red: 212/255, green: 113/255, blue: 78/255)

    private var hasGoal: Bool { entry.data.dailyGoal != nil }
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
                    .modifier(GlassEffectModifier())
                }
            }

            Spacer()
        }
        .padding(12)
        .widgetURL(URL(string: "carpecarb://open"))
    }
}

struct CarbWiseWidget: Widget {
    let kind: String = "CarbWiseWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: CarbWiseProvider()) { entry in
            CarbWiseWidgetEntryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("CarpeCarb")
        .description("Track your daily carb intake at a glance.")
        .supportedFamilies([.systemSmall])
    }
}

@main
struct CarbWiseWidgetBundle: WidgetBundle {
    var body: some Widget {
        CarbWiseWidget()
    }
}
