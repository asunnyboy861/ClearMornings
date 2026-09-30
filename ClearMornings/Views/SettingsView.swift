import SwiftUI
import SwiftData
import StoreKit

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @EnvironmentObject private var router: AppRouter
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Query private var journeys: [Journey]

    @AppStorage("cm.faceIDLockEnabled") private var faceIDLockEnabled = false
    @AppStorage("cm.morningHour") private var morningHour = 8
    @State private var byoKeyDraft = ""
    @State private var pingResult = ""
    @State private var showImporter = false
    @State private var showShareExport = false
    @State private var exportURL: URL?
    @State private var message: String?
    @State private var showSupport = false

    private var journey: Journey? { journeys.first { !$0.isArchived } }

    var body: some View {
        NavigationStack {
            List {
                planSection
                journeySection
                notificationsSection
                securitySection
                aiSection
                dataSection
                legalSection
            }
            .scrollContentBackground(.hidden)
            .background(Theme.nightBase)
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        router.showPaywall = true
                    } label: {
                        Image(systemName: purchaseManager.isPlus ? "crown.fill" : "crown")
                            .foregroundStyle(Theme.dawnGradient)
                    }
                }
            }
            .sheet(isPresented: $showShareExport) {
                if let exportURL {
                    ShareSheet(items: [exportURL])
                }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                importBackup(result)
            }
            .sheet(isPresented: $showSupport) { ContactSupportView() }
            .alert("Done", isPresented: Binding(
                get: { message != nil },
                set: { if !$0 { message = nil } }
            )) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(message ?? "")
            }
            .onAppear { byoKeyDraft = KeychainStore.byoKey ?? "" }
        }
        .preferredColorScheme(.dark)
    }

    private var planSection: some View {
        Section {
            if purchaseManager.isPlus {
                Label("Clear+ active — everything unlocked", systemImage: "crown.fill")
                    .foregroundStyle(Theme.amber)
            } else if purchaseManager.hasBYO {
                Label("BYO Key active — AI unlocked", systemImage: "key.fill")
                    .foregroundStyle(Theme.amber)
            } else {
                Button {
                    router.showPaywall = true
                } label: {
                    Label("Upgrade to Clear+", systemImage: "crown")
                        .foregroundStyle(Theme.dawnGradient)
                }
            }
        } header: {
            Text("Plan")
        }
    }

    private var journeySection: some View {
        Section("Your journey") {
            if let journey {
                DatePicker(
                    "Sober since",
                    selection: Binding(
                        get: { journey.startDate },
                        set: { newDate in
                            journey.startDate = Calendar.current.startOfDay(for: newDate)
                            _ = CheckInService.recalcAndPublish(context)
                        }
                    ),
                    in: ...Calendar.current.startOfDay(for: .now),
                    displayedComponents: .date
                )
                LabeledContent("Goal", value: journey.isTaper ? "Taper (\(journey.taperWeeklyLimit)/week)" : "Quit completely")
            }
        }
    }

    private var notificationsSection: some View {
        Section {
            Toggle("Morning ritual notification", isOn: Binding(
                get: { morningHour > 0 },
                set: { on in
                    if on {
                        Task {
                            let granted = await NotificationService.requestAuthorization()
                            if granted {
                                let streak = CheckInService.recalcAndPublish(context)?.current ?? 0
                                NotificationService.rescheduleDailyRitual(streak: streak, hour: max(5, morningHour))
                                morningHour = max(5, morningHour)
                            } else {
                                morningHour = 0
                                message = "Notifications are disabled in system settings."
                            }
                        }
                    } else {
                        morningHour = 0
                        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()
                    }
                }
            ))
            if morningHour > 0 {
                Stepper(value: $morningHour, in: 5...11) {
                    LabeledContent("Remind at", value: "\(morningHour):00")
                }
                .onChange(of: morningHour) { _, hour in
                    let streak = CheckInService.recalcAndPublish(context)?.current ?? 0
                    NotificationService.rescheduleDailyRitual(streak: streak, hour: hour)
                }
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text("A gentle \"Morning, Day N.\" greeting plus a fix-it nudge when you miss a day.")
        }
    }

    private var securitySection: some View {
        Section {
            Toggle("Face ID lock", isOn: $faceIDLockEnabled)
        } header: {
            Text("Privacy")
        } footer: {
            Text("Lock the app whenever it goes to the background.")
        }
    }

    private var aiSection: some View {
        Section {
            SecureField("Your GLM API key (Z.ai)", text: $byoKeyDraft)
                .autocorrectionDisabled()
            HStack {
                Button("Save key") {
                    KeychainStore.byoKey = byoKeyDraft.trimmingCharacters(in: .whitespaces)
                    message = byoKeyDraft.isEmpty ? "Key removed." : "Your key is stored in the Keychain."
                }
                Spacer()
                Button("Test key") {
                    Task {
                        pingResult = "Testing..."
                        let key = byoKeyDraft.trimmingCharacters(in: .whitespaces)
                        let ok = await GLMClient.ping(key: key)
                        pingResult = ok ? "Key works." : "Key failed — check it on z.ai."
                    }
                }
            }
            if !pingResult.isEmpty {
                Text(pingResult)
                    .font(.caption)
                    .foregroundStyle(Theme.calmGray)
            }
        } header: {
            Text("AI engine")
        } footer: {
            Text("Optional: bring your own GLM key from z.ai. It's stored only in your Keychain and used directly from your device. Without a key, Clear Mornings uses its built-in cloud engine (Clear+) or free on-device Apple Intelligence.")
        }
    }

    private var dataSection: some View {
        Section {
            Button {
                export(kind: .json)
            } label: {
                Label("Export full backup (JSON)", systemImage: "square.and.arrow.up")
            }
            Button {
                export(kind: .csv)
            } label: {
                Label("Export history (CSV)", systemImage: "tablecells")
            }
            Button {
                showImporter = true
            } label: {
                Label("Import backup", systemImage: "square.and.arrow.down")
            }
        } header: {
            Text("Data")
        } footer: {
            Text("Your data syncs through your private iCloud (CloudKit) — only you can see it. Exports include the full edit audit trail.")
        }
    }

    private var legalSection: some View {
        Section {
            Link(destination: URL(string: "https://asunnyboy861.github.io/ClearMornings/privacy.html")!) {
                Label("Privacy Policy", systemImage: "hand.raised")
            }
            Link(destination: URL(string: "https://asunnyboy861.github.io/ClearMornings/terms.html")!) {
                Label("Terms of Use", systemImage: "doc.text")
            }
            Link(destination: URL(string: "https://asunnyboy861.github.io/ClearMornings/support.html")!) {
                Label("Support & FAQ", systemImage: "questionmark.circle")
            }
            Button {
                showSupport = true
            } label: {
                Label("Contact support", systemImage: "envelope")
            }
            Button {
                Task { await purchaseManager.restorePurchases() }
            } label: {
                Label("Restore purchases", systemImage: "arrow.clockwise")
            }
            LabeledContent("Version", value: appVersion)
        } header: {
            Text("About")
        } footer: {
            Text("Clear Mornings is a habit tracker, not a medical device. In crisis, call 988 (US). Copyright © 2026 he zhou")
        }
    }

    private var appVersion: String {
        let v = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let b = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(v) (\(b))"
    }

    private enum ExportKind { case json, csv }

    private func export(kind: ExportKind) {
        do {
            exportURL = switch kind {
            case .json: try ExportService.exportJSON(context)
            case .csv: try ExportService.exportCSV(context)
            }
            showShareExport = exportURL != nil
        } catch {
            message = "Export failed: \(error.localizedDescription)"
        }
    }

    private func importBackup(_ result: Result<URL, Error>) {
        switch result {
        case .success(let url):
            do {
                let secured = url.startAccessingSecurityScopedResource()
                defer { if secured { url.stopAccessingSecurityScopedResource() } }
                let merged = try ExportService.importJSON(from: url, into: context)
                _ = CheckInService.recalcAndPublish(context)
                message = "Imported \(merged) items."
            } catch {
                message = "Import failed: \(error.localizedDescription)"
            }
        case .failure(let error):
            message = "Import failed: \(error.localizedDescription)"
        }
    }
}
