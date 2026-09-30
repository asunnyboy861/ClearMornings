import SwiftUI
import SwiftData

final class AppRouter: ObservableObject {
    @Published var showPaywall = false
    @Published var showSOS = false
    @Published var isLocked = false
}

@main
struct ClearMorningsApp: App {
    @StateObject private var router = AppRouter()
    @StateObject private var purchaseManager = PurchaseManager.shared
    // Plain lets, not @State: @State values assigned in App.init() are discarded when
    // SwiftUI re-creates the App struct, which blanked a successfully built container.
    let container: ModelContainer?
    let initError: String?

    init() {
        let schema = Schema([
            Journey.self, DayRecord.self, EditLog.self, WhyItem.self,
            SavingConfig.self, MilestoneState.self, SOSLog.self,
            JournalEntry.self, PhotoCheckIn.self, AIChatMessage.self
        ])
        // Explicit store URL inside the app sandbox. On iOS 18+ an app with an App Group
        // entitlement defaults its SwiftData store into the App Group container, which can
        // be unwritable on simulators; the widget reads snapshots, not SwiftData, so the
        // app-local store is the deterministic choice.
        let storeURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("ClearMornings.store")
        try? FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        var builtContainer: ModelContainer?
        var buildError: String?
        do {
            let cloudConfig = ModelConfiguration(schema: schema, url: storeURL, cloudKitDatabase: .private("iCloud.com.clearmornings.app"))
            builtContainer = try ModelContainer(for: schema, configurations: [cloudConfig])
        } catch {
            buildError = "cloud: \(error)"
            // Catastrophic first-launch failure: clear unusable store files, fall back to local-only.
            for suffix in ["", "-wal", "-shm"] {
                try? FileManager.default.removeItem(at: URL(fileURLWithPath: storeURL.path + suffix))
            }
            let localConfig = ModelConfiguration(schema: schema, url: storeURL)
            do {
                builtContainer = try ModelContainer(for: schema, configurations: [localConfig])
            } catch {
                buildError = "local: \(error)"
            }
        }
        container = builtContainer
        initError = buildError
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if let container {
                    RootView()
                        .modelContainer(container)
                        .environmentObject(router)
                        .environmentObject(purchaseManager)
                } else {
                    Theme.nightBase.ignoresSafeArea()
                        .overlay(
                            VStack(spacing: 12) {
                                Text("Storage is unavailable. Please reinstall Clear Mornings.").foregroundStyle(.white)
                                if let initError {
                                    Text(initError).font(.caption2).foregroundStyle(.white.opacity(0.6)).padding(.horizontal)
                                }
                            }
                        )
                }
            }
        }
    }
}
