import SwiftUI

struct ContactSupportView: View {
    @Environment(\.dismiss) private var dismiss

    private let subjects = [
        ("creditcard", "Billing & subscription"),
        ("ladybug", "Bug report"),
        ("lightbulb", "Feature request"),
        ("lock.shield", "Data & privacy"),
        ("heart.text.square", "Recovery content & safety"),
        ("star", "App Store review help"),
        ("envelope", "Other")
    ]

    @State private var subject = "Billing & subscription"
    @State private var email = ""
    @State private var deviceModel = ""
    @State private var osVersion = ""
    @State private var appVersion = ""
    @State private var messageText = ""
    @State private var sending = false
    @State private var resultMessage: String?
    @State private var success = false

    private var canSend: Bool {
        !email.isEmpty && !deviceModel.isEmpty && !osVersion.isEmpty && !appVersion.isEmpty && messageText.count >= 10
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("What's it about?") {
                    Picker("Subject", selection: $subject) {
                        ForEach(subjects, id: \.1) { item in
                            Label(item.1, systemImage: item.0).tag(item.1)
                        }
                    }
                    .pickerStyle(.menu)
                }
                Section("Required info") {
                    TextField("Your email", text: $email)
                        .keyboardType(.emailAddress)
                        .textInputAutocapitalization(.never)
                    TextField("Device model (e.g. iPhone 15 Pro)", text: $deviceModel)
                    TextField("iOS version (e.g. 18.4)", text: $osVersion)
                        .keyboardType(.decimalPad)
                    TextField("App version (e.g. 1.0)", text: $appVersion)
                }
                Section("Message") {
                    TextEditor(text: $messageText)
                        .frame(minHeight: 120)
                }
                if let resultMessage {
                    Section {
                        Label(resultMessage, systemImage: success ? "checkmark.circle.fill" : "xmark.octagon.fill")
                            .foregroundStyle(success ? Color.green : Color.red)
                    }
                }
                Section {
                    Button {
                        Task { await send() }
                    } label: {
                        HStack {
                            if sending { ProgressView() }
                            Text(sending ? "Sending..." : "Send to support")
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .disabled(!canSend || sending)
                } footer: {
                    Text("All fields are required so we can actually help you. We reply within 48 hours.")
                }
            }
            .navigationTitle("Contact support")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .onAppear {
                if deviceModel.isEmpty { deviceModel = UIDevice.current.model }
                if osVersion.isEmpty { osVersion = UIDevice.current.systemVersion }
                if appVersion.isEmpty {
                    appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
                }
            }
        }
        .preferredColorScheme(.dark)
    }

    private func send() async {
        sending = true
        resultMessage = nil
        var request = URLRequest(url: URL(string: "https://msg.calcs.top/feedback")!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = 15
        let body: [String: Any] = [
            "appId": "clearmornings",
            "subject": subject,
            "email": email,
            "deviceModel": deviceModel,
            "osVersion": osVersion,
            "appVersion": appVersion,
            "message": messageText
        ]
        do {
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            let (data, resp) = try await URLSession.shared.data(for: request)
            let status = (resp as? HTTPURLResponse)?.statusCode ?? 0
            guard status == 200 else {
                throw NSError(domain: "Support", code: status, userInfo: [NSLocalizedDescriptionKey: "Server returned \(status)"])
            }
            _ = data
            success = true
            resultMessage = "Sent. We'll reply to \(email) within 48 hours."
            messageText = ""
        } catch {
            success = false
            resultMessage = "Send failed: \(error.localizedDescription). Email us directly at asunnyboy168@icloud.com"
        }
        sending = false
    }
}
