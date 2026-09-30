import SwiftUI
import SwiftData
import PhotosUI
import UIKit

struct MirrorView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Query private var journeys: [Journey]
    @Query private var photos: [PhotoCheckIn]

    @State private var streak: StreakResult = StreakResult(current: 0, unknownGap: 0, totalSoberDays: 0, longestStreak: 0, restarts: 0)
    @State private var savedAmount: Double = 0
    @State private var currency: String = "USD"

    @State private var day1Image: UIImage?
    @State private var todayImage: UIImage?
    @State private var day1Item: PhotosPickerItem?
    @State private var todayItem: PhotosPickerItem?
    @State private var day1PickerShown = false
    @State private var todayPickerShown = false
    @State private var mirrorResult = ""
    @State private var mirrorLoading = false

    @State private var reportText = ""
    @State private var reportLoading = false
    @State private var shareImage: UIImage?
    @State private var showShareSheet = false

    private var journey: Journey? { journeys.first { !$0.isArchived } }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 18) {
                    statsHeader
                    recoveryTimeline
                    savingsWall
                    photoMirrorCard
                    reportCard
                    shareCard
                }
                .padding(20)
                .padding(.bottom, 96)
            }
            .background(Theme.nightBase)
            .navigationTitle("Mirror")
            .onAppear { recompute() }
            .sheet(isPresented: $showShareSheet) {
                if let shareImage {
                    ShareSheet(items: [shareImage])
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private var statsHeader: some View {
        HStack(spacing: 12) {
            statTile(value: "\(streak.current)", label: "Current streak")
            statTile(value: "\(streak.totalSoberDays)", label: "Total sober days")
            statTile(value: "\(streak.restarts)", label: "Brave restarts")
        }
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.bold))
                .foregroundStyle(Theme.dawnGradient)
            Text(label)
                .font(.caption2)
                .foregroundStyle(Theme.calmGray)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .background(Theme.nightCard, in: RoundedRectangle(cornerRadius: 14))
    }

    private var recoveryTimeline: some View {
        let achieved = Set(MilestoneEngine.achievedRecovery(days: streak.current).map(\.id))
        return VStack(alignment: .leading, spacing: 14) {
            Text("Recovery timeline")
                .font(.headline)
                .foregroundStyle(.white)
            ForEach(MilestoneEngine.recovery) { m in
                let done = achieved.contains(m.id)
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(done ? AnyShapeStyle(Theme.dawnGradient) : AnyShapeStyle(Color.white.opacity(0.08)))
                            .frame(width: 40, height: 40)
                        Image(systemName: m.icon)
                            .font(.subheadline)
                            .foregroundStyle(done ? .white : Theme.calmGray)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(m.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(done ? .white : Theme.calmGray)
                        Text(m.detail)
                            .font(.caption)
                            .foregroundStyle(done ? Theme.calmGray : Theme.calmGray.opacity(0.6))
                    }
                    Spacer()
                    if done {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Theme.amber)
                    }
                }
            }
        }
        .padding(18)
        .background(Theme.nightCard, in: RoundedRectangle(cornerRadius: 18))
    }

    private var savingsWall: some View {
        Group {
            if savedAmount > 0 {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Savings wall")
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(String(format: "You've saved %.2f %@ so far.", savedAmount, currency))
                        .font(.subheadline)
                        .foregroundStyle(Theme.dawnStart)
                    ForEach(conversions, id: \.label) { conv in
                        HStack(spacing: 12) {
                            Image(systemName: conv.icon)
                                .font(.title3)
                                .foregroundStyle(Theme.amber)
                                .frame(width: 34)
                            Text("\(conv.count)× \(conv.label)")
                                .font(.subheadline)
                                .foregroundStyle(.white)
                            Spacer()
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(18)
                .background(Theme.nightCard, in: RoundedRectangle(cornerRadius: 18))
            }
        }
    }

    private var conversions: [(label: String, icon: String, count: Int)] {
        guard let conv = SavingsEngine.conversion(for: savedAmount) else { return [] }
        return [(conv.label, conv.icon, conv.count)]
    }

    private var photoMirrorCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Image(systemName: "person.text.rectangle")
                    .foregroundStyle(Theme.dawnEnd)
                Text("Recovery Mirror")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
                Text("Optional")
                    .font(.caption2)
                    .foregroundStyle(Theme.calmGray)
            }
            Text("Compare your Day 1 photo with today. Watch your face clear up. Photos never leave your device unless you ask for an AI comparison.")
                .font(.caption)
                .foregroundStyle(Theme.calmGray)
            HStack(spacing: 12) {
                photoSlot(image: day1Image, label: "Day 1") { day1PickerShown = true }
                photoSlot(image: todayImage, label: "Today") { todayPickerShown = true }
            }
            if !mirrorResult.isEmpty {
                Text(mirrorResult)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            }
            Button {
                Task { compareMirror() }
            } label: {
                HStack {
                    if mirrorLoading { ProgressView().tint(.white) }
                    Image(systemName: "sparkles")
                    Text(mirrorLoading ? "Comparing..." : "AI compare")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.dawnGradient, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
            }
            .disabled(day1Image == nil || todayImage == nil || mirrorLoading)
            Text("AI compare is a Clear+ feature, or use your own GLM key.")
                .font(.caption2)
                .foregroundStyle(Theme.calmGray)
        }
        .padding(18)
        .background(Theme.nightCard, in: RoundedRectangle(cornerRadius: 18))
        .photosPicker(isPresented: $day1PickerShown, selection: $day1Item, matching: .images)
        .photosPicker(isPresented: $todayPickerShown, selection: $todayItem, matching: .images)
        .onChange(of: day1Item) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    day1Image = UIImage(data: data)
                }
            }
        }
        .onChange(of: todayItem) { _, item in
            guard let item else { return }
            Task {
                if let data = try? await item.loadTransferable(type: Data.self) {
                    todayImage = UIImage(data: data)
                }
            }
        }
    }

    private func photoSlot(image: UIImage?, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.06))
                    .frame(height: 120)
                if let image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(height: 120)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                } else {
                    VStack(spacing: 6) {
                        Image(systemName: "camera")
                            .font(.title3)
                        Text(label)
                            .font(.caption)
                    }
                    .foregroundStyle(Theme.calmGray)
                }
            }
        }
    }

    private var reportCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text.below.ecg")
                    .foregroundStyle(Theme.dawnStart)
                Text("Weekly report")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
            }
            if !reportText.isEmpty {
                Text(reportText)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            }
            Button {
                Task { generateReport() }
            } label: {
                HStack {
                    if reportLoading { ProgressView().tint(.white) }
                    Image(systemName: "sparkles")
                    Text(reportLoading ? "Writing..." : "Generate this week's report")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.dawnGradient, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
            }
            .disabled(reportLoading)
        }
        .padding(18)
        .background(Theme.nightCard, in: RoundedRectangle(cornerRadius: 18))
    }

    private var shareCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Share your milestone")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Day \(streak.current) · Clear Mornings ✨")
                .font(.caption)
                .foregroundStyle(Theme.calmGray)
            Button {
                renderShareCard()
            } label: {
                HStack {
                    Image(systemName: "square.and.arrow.up")
                    Text("Create share card")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
            }
        }
        .padding(18)
        .background(Theme.nightCard, in: RoundedRectangle(cornerRadius: 18))
    }

    private func recompute() {
        guard let journey else { return }
        let records = CheckInService.fetchRecords(context, journeyID: journey.id)
        var map: [String: DayStatus] = [:]
        for r in records { map[r.dayKey] = r.status }
        streak = StreakEngine.compute(statuses: map, startDayKey: journey.startDayKey, todayKey: StreakEngine.dayKey(.now))
        let spend = CheckInService.fetchSavingConfig(context, journeyID: journey.id)?.dailySpend ?? 0
        currency = CheckInService.fetchSavingConfig(context, journeyID: journey.id)?.currency ?? "USD"
        savedAmount = SavingsEngine.saved(soberDays: streak.totalSoberDays, dailySpend: spend)
    }

    private func compareMirror() {
        guard let day1 = day1Image, let today = todayImage else { return }
        mirrorLoading = true
        mirrorResult = ""
        Task {
            let routerAI = AIRouter.shared
            let allowed = purchaseManager.isPlus || KeychainStore.byoKey != nil
            guard allowed else {
                mirrorLoading = false
                mirrorResult = "AI Mirror compare needs Clear+ or your own GLM key (Settings → AI)."
                return
            }
            do {
                let result = try await routerAI.mirrorCompare(
                    day1JPEG: day1.jpegData(compressionQuality: 0.6) ?? Data(),
                    todayJPEG: today.jpegData(compressionQuality: 0.6) ?? Data(),
                    dayNumber: streak.current
                )
                mirrorResult = result
            } catch {
                mirrorResult = "AI compare unavailable right now. Your photos stay on-device either way."
            }
            mirrorLoading = false
            if let todayData = today.jpegData(compressionQuality: 0.5) {
                let fileName = "mirror-\(UUID().uuidString).jpg"
                let url = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0].appendingPathComponent(fileName)
                try? todayData.write(to: url)
                context.insert(PhotoCheckIn(dayKey: StreakEngine.dayKey(.now), localFileName: fileName))
                try? context.save()
            }
        }
    }

    private func generateReport() {
        guard let journey else { return }
        reportLoading = true
        Task {
            let allowed = purchaseManager.isPlus || AIRouter.shared.canUseReport || KeychainStore.byoKey != nil
            guard allowed else {
                reportText = "Weekly reports are free once a month — you've used this month's. Clear+ gives unlimited reports."
                reportLoading = false
                return
            }
            let records = CheckInService.fetchRecords(context, journeyID: journey.id)
            let last7 = (0..<7).compactMap { StreakEngine.shiftDay(StreakEngine.dayKey(.now), by: -$0) }
            let sober = records.filter { last7.contains($0.dayKey) && $0.status == .sober }.count
            let slips = records.filter { last7.contains($0.dayKey) && $0.status == .slip }.count
            let summary = "This week: \(sober)/7 sober days, \(slips) slip day(s). Total sober days: \(streak.totalSoberDays). Current streak: \(streak.current)."
            let contextAI = AIRouter.ChatContext(whyTop3: [], recentMoods: [])
            reportText = (try? await AIRouter.shared.weeklyReport(summary: summary, context: contextAI)) ?? RuleEngine.journalSummary(summary)
            reportLoading = false
        }
    }

    private func renderShareCard() {
        let view = ShareCardView(day: streak.current, longest: streak.longestStreak, totalSober: streak.totalSoberDays, saved: savedAmount, currency: currency)
        let renderer = ImageRenderer(content: view.frame(width: 390, height: 500))
        renderer.scale = 2
        if let image = renderer.uiImage {
            shareImage = image
            showShareSheet = true
        }
    }
}

struct ShareCardView: View {
    let day: Int
    let longest: Int
    let totalSober: Int
    let saved: Double
    let currency: String

    var body: some View {
        ZStack {
            Theme.nightBase
            VStack(spacing: 20) {
                Spacer()
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 56))
                    .foregroundStyle(Theme.dawnGradient)
                Text("Day \(day)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.dawnGradient)
                Text("clear mornings and counting")
                    .font(.subheadline)
                    .foregroundStyle(Theme.calmGray)
                Spacer()
                HStack(spacing: 24) {
                    VStack(spacing: 2) {
                        Text("\(longest)")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("longest")
                            .font(.caption2)
                            .foregroundStyle(Theme.calmGray)
                    }
                    VStack(spacing: 2) {
                        Text("\(totalSober)")
                            .font(.headline)
                            .foregroundStyle(.white)
                        Text("sober days")
                            .font(.caption2)
                            .foregroundStyle(Theme.calmGray)
                    }
                    if saved > 0 {
                        VStack(spacing: 2) {
                            Text(String(format: "%.0f", saved))
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("\(currency) saved")
                                .font(.caption2)
                                .foregroundStyle(Theme.calmGray)
                        }
                    }
                }
                Text("Clear Mornings ✨")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.amber)
                    .padding(.bottom, 24)
            }
        }
    }
}

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
