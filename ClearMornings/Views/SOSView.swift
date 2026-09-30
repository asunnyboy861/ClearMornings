import SwiftUI
import SwiftData

struct SOSView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context
    @Query private var whys: [WhyItem]
    @EnvironmentObject private var purchaseManager: PurchaseManager

    @State private var breathing = false
    @State private var breathScale: CGFloat = 1.0
    @State private var breathLabel = "Breathe in"
    @State private var breathTask: Task<Void, Never>?

    @State private var waveRunning = false
    @State private var waveRemaining: TimeInterval = 0
    @State private var waveTask: Task<Void, Never>?

    @State private var cravingBefore: Double = 5
    @State private var cravingAfter: Double = 3
    @State private var showAIChat = false
    @State private var aiReply = ""
    @State private var aiLoading = false
    @State private var resolved = false

    private var sortedWhys: [WhyItem] {
        whys.sorted { ($0.isPinned == $1.isPinned) ? $0.order < $1.order : $0.isPinned && !$1.isPinned }
    }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    breathingCard
                    waveCard
                    whyWall
                    hotlineCard
                    aiCard
                    if resolved {
                        resolveCard
                    }
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .background(Theme.nightBase)
            .navigationTitle("SOS Rescue")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") { finish() }
                }
            }
            .onAppear { startBreathing() }
            .onDisappear {
                breathTask?.cancel()
                waveTask?.cancel()
            }
        }
        .preferredColorScheme(.dark)
    }

    private var breathingCard: some View {
        VStack(spacing: 14) {
            Text("4-7-8 Breathing")
                .font(.headline)
                .foregroundStyle(.white)
            ZStack {
                Circle()
                    .fill(Theme.dawnGradient.opacity(0.25))
                    .frame(width: 170, height: 170)
                Circle()
                    .fill(Theme.dawnGradient)
                    .frame(width: 130, height: 130)
                    .scaleEffect(breathScale)
                    .animation(.easeInOut(duration: 4), value: breathScale)
                Text(breathLabel)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
            }
            Button {
                if breathing { stopBreathing() } else { startBreathing() }
            } label: {
                Text(breathing ? "Pause" : "Start breathing")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 22)
                    .padding(.vertical, 10)
                    .background(Color.white.opacity(0.1), in: Capsule())
                    .foregroundStyle(.white)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Theme.nightCard, in: RoundedRectangle(cornerRadius: 20))
    }

    private var waveCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "water.waves")
                    .foregroundStyle(Theme.seaBlue)
                Text("Ride the wave")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
            }
            Text("Cravings peak and pass in about 10 minutes. Hold out with the timer.")
                .font(.caption)
                .foregroundStyle(Theme.calmGray)
                .frame(maxWidth: .infinity, alignment: .leading)
            if waveRunning {
                Text(timeString(waveRemaining))
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Theme.dawnGradient)
                    .frame(maxWidth: .infinity)
            }
            HStack(spacing: 12) {
                Button {
                    startWave(minutes: 10)
                } label: {
                    Text("10 min")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.seaBlue.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
                Button {
                    startWave(minutes: 20)
                } label: {
                    Text("20 min")
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                        .background(Theme.seaBlue.opacity(0.3), in: RoundedRectangle(cornerRadius: 12))
                        .foregroundStyle(.white)
                }
            }
            .disabled(waveRunning)
        }
        .padding(20)
        .background(Theme.nightCard, in: RoundedRectangle(cornerRadius: 20))
    }

    private var whyWall: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "wall.pattern")
                    .foregroundStyle(Theme.amber)
                Text("Your why-wall")
                    .font(.headline)
                    .foregroundStyle(.white)
            }
            if sortedWhys.isEmpty {
                Text("No reasons yet — add yours in onboarding or from the journal.")
                    .font(.caption)
                    .foregroundStyle(Theme.calmGray)
            } else {
                ForEach(sortedWhys.prefix(5)) { why in
                    HStack(spacing: 10) {
                        if why.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption)
                                .foregroundStyle(Theme.amber)
                        }
                        Text(why.text)
                            .font(.subheadline)
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(20)
        .background(Theme.nightCard, in: RoundedRectangle(cornerRadius: 20))
    }

    private var hotlineCard: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: "phone.fill")
                    .foregroundStyle(Theme.dawnStart)
                Text("Real humans, always free")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
            }
            Link(destination: URL(string: "tel:988")!) {
                HStack {
                    Image(systemName: "phone.circle.fill")
                        .font(.title2)
                    VStack(alignment: .leading) {
                        Text("988 Suicide & Crisis Lifeline")
                            .font(.subheadline.weight(.semibold))
                        Text("Call or text 988 — 24/7")
                            .font(.caption)
                    }
                    .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Theme.calmGray)
                }
                .padding(12)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            }
            Link(destination: URL(string: "tel:18006624357")!) {
                HStack {
                    Image(systemName: "phone.circle")
                        .font(.title2)
                    VStack(alignment: .leading) {
                        Text("SAMHSA National Helpline")
                            .font(.subheadline.weight(.semibold))
                        Text("1-800-662-4357 — treatment referral, 24/7")
                            .font(.caption)
                    }
                    .foregroundStyle(.white)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(Theme.calmGray)
                }
                .padding(12)
                .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(20)
        .background(Theme.nightCard, in: RoundedRectangle(cornerRadius: 20))
    }

    private var aiCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .foregroundStyle(Theme.dawnEnd)
                Text("AI craving coach")
                    .font(.headline)
                    .foregroundStyle(.white)
                Spacer()
            }
            VStack(alignment: .leading, spacing: 6) {
                Text("How strong is the craving right now?")
                    .font(.caption)
                    .foregroundStyle(Theme.calmGray)
                Slider(value: $cravingBefore, in: 0...10, step: 1)
                    .tint(Theme.seaBlue)
                Text("\(Int(cravingBefore))/10")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
            }
            if !aiReply.isEmpty {
                Text(aiReply)
                    .font(.subheadline)
                    .foregroundStyle(.white)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
            }
            Button {
                Task { askAI() }
            } label: {
                HStack {
                    if aiLoading {
                        ProgressView().tint(.white)
                    } else {
                        Image(systemName: "sparkles")
                    }
                    Text(aiLoading ? "Morn is typing..." : "Get me through this")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(Theme.dawnGradient, in: RoundedRectangle(cornerRadius: 12))
                .foregroundStyle(.white)
            }
            .disabled(aiLoading)
        }
        .padding(20)
        .background(Theme.nightCard, in: RoundedRectangle(cornerRadius: 20))
    }

    private var resolveCard: some View {
        VStack(spacing: 12) {
            Image(systemName: "checkmark.seal.fill")
                .font(.largeTitle)
                .foregroundStyle(Theme.amber)
            Text("You made it through.")
                .font(.headline)
                .foregroundStyle(.white)
            VStack(alignment: .leading, spacing: 6) {
                Text("How strong is the craving now?")
                    .font(.caption)
                    .foregroundStyle(Theme.calmGray)
                Slider(value: $cravingAfter, in: 0...10, step: 1)
                    .tint(Theme.amber)
                Text("\(Int(cravingAfter))/10")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white)
            }
            Button {
                finish()
            } label: {
                Text("Log & close")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))
                    .foregroundStyle(.white)
            }
        }
        .padding(20)
        .background(Theme.nightCard, in: RoundedRectangle(cornerRadius: 20))
    }

    private func startBreathing() {
        breathing = true
        breathTask?.cancel()
        breathTask = Task {
            while !Task.isCancelled {
                await MainActor.run {
                    breathLabel = "Breathe in"
                    breathScale = 1.25
                }
                try? await Task.sleep(nanoseconds: 4_000_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    breathLabel = "Hold"
                }
                try? await Task.sleep(nanoseconds: 7_000_000_000)
                guard !Task.isCancelled else { return }
                await MainActor.run {
                    breathLabel = "Breathe out"
                    breathScale = 1.0
                }
                try? await Task.sleep(nanoseconds: 8_000_000_000)
            }
        }
    }

    private func stopBreathing() {
        breathing = false
        breathTask?.cancel()
        breathScale = 1.0
        breathLabel = "Breathe in"
    }

    private func startWave(minutes: Int) {
        waveRemaining = TimeInterval(minutes * 60)
        waveRunning = true
        waveTask?.cancel()
        waveTask = Task {
            while waveRemaining > 0 && !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run { waveRemaining -= 1 }
            }
            await MainActor.run {
                waveRunning = false
                resolved = true
            }
        }
    }

    private func askAI() {
        aiLoading = true
        aiReply = ""
        Task {
            let steps = await AppleFMService.shared.sosSteps(cravingLevel: Int(cravingBefore))
            aiReply = steps
            aiLoading = false
            resolved = true
        }
    }

    private func finish() {
        context.insert(SOSLog(
            resolvedBy: aiReply.isEmpty ? (waveRunning ? "wave" : "breathing") : "ai",
            cravingBefore: Int(cravingBefore),
            cravingAfter: Int(cravingAfter)
        ))
        try? context.save()
        dismiss()
    }

    private func timeString(_ t: TimeInterval) -> String {
        String(format: "%02d:%02d", Int(t) / 60, Int(t) % 60)
    }
}
