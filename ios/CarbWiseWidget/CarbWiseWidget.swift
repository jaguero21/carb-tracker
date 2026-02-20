import WidgetKit
import SwiftUI

struct CarbWidgetData {
    let totalCarbs: Double
    let lastFoodName: String
    let lastFoodCarbs: Double

    static let placeholder = CarbWidgetData(
        totalCarbs: 42.5,
        lastFoodName: "Brown Rice",
        lastFoodCarbs: 45.0
    )

    static let empty = CarbWidgetData(
        totalCarbs: 0.0,
        lastFoodName: "",
        lastFoodCarbs: 0.0
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
        let tomorrow = Calendar.current.startOfDay(
            for: Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        )
        let timeline = Timeline(entries: [entry], policy: .after(tomorrow))
        completion(timeline)
    }

    private func loadData() -> CarbWidgetData {
        let defaults = UserDefaults(suiteName: "group.com.jamesaguero.mycarbtracker")
        return CarbWidgetData(
            totalCarbs: defaults?.double(forKey: "totalCarbs") ?? 0.0,
            lastFoodName: defaults?.string(forKey: "lastFoodName") ?? "",
            lastFoodCarbs: defaults?.double(forKey: "lastFoodCarbs") ?? 0.0
        )
    }
}

struct CarbWiseEntry: TimelineEntry {
    let date: Date
    let data: CarbWidgetData
}

struct CarbWiseWidgetEntryView: View {
    var entry: CarbWiseProvider.Entry

    private let sage = Color(red: 125/255, green: 155/255, blue: 118/255)

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: "leaf.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(sage)
                Text("CarpeCarb")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(sage)
                Spacer()
            }

            Spacer()

            Text(String(format: "%.1fg", entry.data.totalCarbs))
                .font(.system(size: 32, weight: .light, design: .rounded))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text("total carbs")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)

            Spacer()

            if !entry.data.lastFoodName.isEmpty {
                HStack {
                    Text(entry.data.lastFoodName)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer()
                    Text(String(format: "%.1fg", entry.data.lastFoodCarbs))
                        .font(.system(size: 11, weight: .light))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .glassEffect(.regular, in: .capsule)
            } else {
                Text("Tap to add food")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(14)
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
