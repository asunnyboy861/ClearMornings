import SwiftUI
import SwiftData
import LocalAuthentication
import WidgetKit

struct RootView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @EnvironmentObject private var router: AppRouter
    @Query private var journeys: [Journey]

    @AppStorage("cm.hasOnboarded") private var hasOnboarded = false
    @AppStorage("cm.faceIDLockEnabled") private var faceIDLockEnabled = false

    var body: some View {
        Group {
            if !hasOnboarded || journeys.isEmpty {
                OnboardingView()
            } else {
                mainTabs
                    .overlay(alignment: .bottomTrailing) { sosFab }
                    .sheet(isPresented: $router.showSOS) { SOSView() }
            }
        }
        .background(Theme.nightBase.ignoresSafeArea())
        .preferredColorScheme(.dark)
        .overlay { if router.isLocked { LockScreenView() } }
        .task { refresh() }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                refresh()
                if faceIDLockEnabled { router.isLocked = true }
            } else if phase == .background, faceIDLockEnabled {
                router.isLocked = true
            }
        }
    }

    private var mainTabs: some View {
        TabView {
            TodayView()
                .tabItem { Label("Today", systemImage: "sun.max.fill") }
            FixAnythingView()
                .tabItem { Label("History", systemImage: "calendar") }
            MirrorView()
                .tabItem { Label("Mirror", systemImage: "person.text.rectangle") }
            SettingsView()
                .tabItem { Label("Settings", systemImage: "gearshape.fill") }
        }
        .tint(Theme.amber)
        .sheet(isPresented: $router.showPaywall) { PaywallView() }
    }

    private var sosFab: some View {
        Button {
            router.showSOS = true
        } label: {
            ZStack {
                Circle()
                    .fill(Theme.dawnGradient)
                    .frame(width: 64, height: 64)
                    .shadow(color: Theme.dawnEnd.opacity(0.4), radius: 12, y: 4)
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 26, weight: .bold))
                    .foregroundStyle(.white)
            }
        }
        .padding(.trailing, 20)
        .padding(.bottom, 72)
        .accessibilityLabel("SOS craving rescue")
    }

    private func refresh() {
        guard hasOnboarded, !journeys.isEmpty else { return }
        Task { @MainActor in
            CheckInService.ensureYesterdayPlaceholder(context)
            CheckInService.syncPendingFromWidget(context)
            if let result = CheckInService.recalcAndPublish(context) {
                NotificationService.rescheduleDailyRitual(streak: result.current)
                let todayKey = StreakEngine.dayKey(.now)
                let yesterdayKey = StreakEngine.previousDay(todayKey)
                let snap = AppGroupStore.loadSnapshot()
                if snap.statuses[yesterdayKey] == nil || snap.statuses[yesterdayKey] == .unknown {
                    NotificationService.scheduleFixYesterdayReminder(yesterdayKey: yesterdayKey)
                }
                if let journey = journeys.first,
                   let next = MilestoneEngine.nextRecoveryMilestone(after: result.current),
                   let achievedDate = StreakEngine.date(fromKey: StreakEngine.shiftDay(journey.startDayKey, by: next.days)) {
                    NotificationService.scheduleMilestoneHeadsUp(next, achievedOn: achievedDate)
                }
            }
        }
    }
}

struct LockScreenView: View {
    @EnvironmentObject private var router: AppRouter
    @State private var failed = false

    var body: some View {
        ZStack {
            Theme.nightBase.ignoresSafeArea()
            VStack(spacing: 24) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 44))
                    .foregroundStyle(Theme.dawnGradient)
                Text("Clear Mornings is locked")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.white)
                if failed {
                    Text("Face ID didn't recognize you.")
                        .font(.footnote)
                        .foregroundStyle(Theme.calmGray)
                }
                Button {
                    authenticate()
                } label: {
                    Label("Unlock with Face ID", systemImage: "faceid")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                        .background(Theme.dawnGradient, in: Capsule())
                        .foregroundStyle(.white)
                }
            }
            .padding(32)
        }
        .onAppear { authenticate() }
    }

    private func authenticate() {
        let laContext = LAContext()
        var error: NSError?
        guard laContext.canEvaluatePolicy(.deviceOwnerAuthentication, error: &error) else {
            router.isLocked = false
            return
        }
        laContext.evaluatePolicy(.deviceOwnerAuthentication, localizedReason: "Unlock your private journey") { success, _ in
            DispatchQueue.main.async {
                if success {
                    router.isLocked = false
                    failed = false
                } else {
                    failed = true
                }
            }
        }
    }
}
