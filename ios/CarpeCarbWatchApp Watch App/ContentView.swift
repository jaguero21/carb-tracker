import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var totalCarbs: Double = 0.0
    @State private var lastFoodName: String = ""
    @State private var lastFoodCarbs: Double = 0.0
    @State private var dailyCarbGoal: Double? = nil

    private let sage = Color(red: 125/255, green: 155/255, blue: 118/255)
    private let terracotta = Color(red: 212/255, green: 113/255, blue: 78/255)

    private var isOverGoal: Bool {
        guard let goal = dailyCarbGoal else { return false }
        return totalCarbs > goal
    }

    private var progress: Double {
        guard let goal = dailyCarbGoal, goal > 0 else { return 0 }
        return min(totalCarbs / goal, 1.0)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                if let goal = dailyCarbGoal {
                    ZStack {
                        Circle()
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 5)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(isOverGoal ? terracotta : sage,
                                    style: StrokeStyle(lineWidth: 5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                        VStack(spacing: 1) {
                            Text(String(format: "%.1fg", totalCarbs))
                                .font(.system(size: 20, weight: .light, design: .rounded))
                                .minimumScaleFactor(0.7)
                                .lineLimit(1)
                            if isOverGoal {
                                Text(String(format: "+%.0fg", totalCarbs - goal))
                                    .font(.system(size: 10))
                                    .foregroundStyle(terracotta)
                            } else {
                                Text(String(format: "%.0fg left", goal - totalCarbs))
                                    .font(.system(size: 10))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .frame(width: 100, height: 100)
                    .padding(.top, 4)
                } else {
                    VStack(spacing: 2) {
                        Text("Total Carbs")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)
                            .kerning(0.8)
                        Text(String(format: "%.1fg", totalCarbs))
                            .font(.system(size: 36, weight: .light, design: .rounded))
                            .minimumScaleFactor(0.6)
                            .lineLimit(1)
                    }
                    .padding(.top, 8)
                }

                if !lastFoodName.isEmpty {
                    HStack {
                        Text(lastFoodName)
                            .font(.system(size: 13, weight: .medium))
                            .lineLimit(1)
                        Spacer()
                        Text(String(format: "%.1fg", lastFoodCarbs))
                            .font(.system(size: 13, weight: .light))
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(Capsule())
                }

                VStack(spacing: 2) {
                    Image(systemName: "waveform")
                        .font(.system(size: 14))
                        .foregroundStyle(sage)
                    Text("\"Log food in CarpeCarb\"")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 6)
            }
            .padding(.horizontal, 8)
        }
        .navigationTitle("CarpeCarb")
        .onAppear { loadData() }
        .onChange(of: scenePhase) { phase in
            if phase == .active { loadData() }
        }
    }

    private func loadData() {
        let defaults = UserDefaults(suiteName: "group.com.jamesaguero.mycarbtracker")
        totalCarbs = defaults?.double(forKey: "totalCarbs") ?? 0.0
        lastFoodName = defaults?.string(forKey: "lastFoodName") ?? ""
        lastFoodCarbs = defaults?.double(forKey: "lastFoodCarbs") ?? 0.0
        let goalValue = defaults?.double(forKey: "dailyCarbGoal") ?? 0.0
        dailyCarbGoal = goalValue > 0 ? goalValue : nil
    }
}
