import SwiftUI
import SwiftData
import UserNotifications

struct OnboardingView: View {
    @Environment(\.modelContext) private var context
    @State private var step = 0
    @State private var journeyName = "Alcohol"
    @State private var startDate = Calendar.current.startOfDay(for: .now)
    @State private var goal = "quit"
    @State private var taperLimit = 7
    @State private var whyDraft = ""
    @State private var whys: [String] = []
    @State private var spendText = ""
    @State private var currency = "USD"
    @State private var notifStatus: UNAuthorizationStatus = .notDetermined
    @State private var finishing = false

    private let totalSteps = 7

    var body: some View {
        ZStack {
            Theme.nightBase.ignoresSafeArea()
            VStack(spacing: 0) {
                if step > 0 {
                    HStack {
                        Button { withAnimation { step -= 1 } } label: {
                            Image(systemName: "chevron.left")
                                .font(.headline)
                                .foregroundStyle(.white)
                                .frame(width: 40, height: 40)
                                .background(Theme.nightCard, in: Circle())
                        }
                        Spacer()
                        Text("Step \(step) of \(totalSteps - 1)")
                            .font(.footnote)
                            .foregroundStyle(Theme.calmGray)
                    }
                    .padding(.horizontal, 24)
                    .padding(.top, 8)
                }
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 28) {
                        switch step {
                        case 0: welcomeStep
                        case 1: journeyStep
                        case 2: goalStep
                        case 3: whyStep
                        case 4: savingsStep
                        case 5: notificationStep
                        default: finalStep
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.vertical, 32)
                }
                bottomBar
            }
        }
        .preferredColorScheme(.dark)
        .task { notifStatus = await NotificationService.authorizationStatus() }
    }

    private var welcomeStep: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 40)
            ZStack {
                Circle()
                    .fill(Theme.dawnGradient)
                    .frame(width: 120, height: 120)
                    .shadow(color: Theme.dawnEnd.opacity(0.5), radius: 30, y: 8)
                Image(systemName: "sun.max.fill")
                    .font(.system(size: 52))
                    .foregroundStyle(.white)
            }
            Text("Morning, Day 1.")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("The private quit-drinking tracker that never shames you. Fix any day, survive any craving, and watch yourself recover.")
                .font(.body)
                .foregroundStyle(Theme.calmGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 8)
            Spacer(minLength: 40)
        }
    }

    private var journeyStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeader(title: "When did your clear mornings begin?", subtitle: "Pick any past date — you can also fix this later.")
            VStack(alignment: .leading, spacing: 12) {
                Text("Journey name")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.calmGray)
                TextField("Alcohol", text: $journeyName)
                    .textFieldStyle(.roundedBorder)
            }
            VStack(alignment: .leading, spacing: 12) {
                Text("Sober since")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(Theme.calmGray)
                DatePicker("", selection: $startDate, in: ...Calendar.current.startOfDay(for: .now), displayedComponents: .date)
                    .datePickerStyle(.compact)
                    .labelsHidden()
            }
        }
    }

    private var goalStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeader(title: "What's your goal?", subtitle: "Quit completely, or cut back gently. Both count.")
            goalCard(id: "quit", icon: "flag.checkered", title: "Quit completely", detail: "Mark every alcohol-free day. Slip days are never the end.")
            goalCard(id: "taper", icon: "slider.horizontal.3", title: "Taper down", detail: "Set a weekly limit and gradually reduce.")
            if goal == "taper" {
                Stepper(value: $taperLimit, in: 1...28) {
                    Text("\(taperLimit) drinks per week")
                        .font(.headline)
                        .foregroundStyle(.white)
                }
                .tint(Theme.amber)
            }
        }
    }

    private var whyStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeader(title: "Why do you want this?", subtitle: "Your reasons become your wall of strength during cravings.")
            ForEach(whys.indices, id: \.self) { i in
                HStack {
                    Text(whys[i])
                        .font(.body)
                        .foregroundStyle(.white)
                        .lineLimit(2)
                    Spacer()
                    Button {
                        whys.remove(at: i)
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.calmGray)
                    }
                }
                .padding(14)
                .background(Theme.nightCard, in: RoundedRectangle(cornerRadius: 12))
            }
            HStack {
                TextField("I want to wake up clear...", text: $whyDraft)
                    .textFieldStyle(.roundedBorder)
                Button {
                    let text = whyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !text.isEmpty else { return }
                    whys.append(text)
                    whyDraft = ""
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title2)
                        .foregroundStyle(Theme.amber)
                }
            }
        }
    }

    private var savingsStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeader(title: "What did drinking cost you a day?", subtitle: "See your savings turn into real things. Skip if you prefer.")
            HStack {
                TextField("0.00", text: $spendText)
                    .keyboardType(.decimalPad)
                    .textFieldStyle(.roundedBorder)
                Picker("", selection: $currency) {
                    Text("USD").tag("USD")
                    Text("EUR").tag("EUR")
                    Text("GBP").tag("GBP")
                    Text("CNY").tag("CNY")
                    Text("JPY").tag("JPY")
                }
                .pickerStyle(.menu)
                .tint(Theme.amber)
            }
            if let spend = Double(spendText), spend > 0 {
                Text(String(format: "In 30 sober days you'd save $%.0f.", spend * 30))
                    .font(.subheadline)
                    .foregroundStyle(Theme.dawnStart)
            }
        }
    }

    private var notificationStep: some View {
        VStack(alignment: .leading, spacing: 20) {
            stepHeader(title: "Your morning ritual, delivered.", subtitle: "A gentle \"Morning, Day N.\" at 8:00 AM. Plus a fix-it nudge if you ever miss a day.")
            Button {
                Task {
                    notifStatus = await NotificationService.authorizationStatus()
                    if notifStatus == .notDetermined {
                        let granted = await NotificationService.requestAuthorization()
                        notifStatus = granted ? .authorized : .denied
                    }
                }
            } label: {
                HStack {
                    Image(systemName: notifStatus == .authorized ? "bell.badge.fill" : "bell.fill")
                    Text(notifStatus == .authorized ? "Notifications on" : "Enable notifications")
                }
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    notifStatus == .authorized ? AnyShapeStyle(Theme.nightCard) : AnyShapeStyle(Theme.dawnGradient),
                    in: RoundedRectangle(cornerRadius: 14)
                )
                .foregroundStyle(.white)
            }
            .disabled(notifStatus == .authorized)
            Text("You can change this anytime in Settings.")
                .font(.footnote)
                .foregroundStyle(Theme.calmGray)
        }
    }

    private var finalStep: some View {
        VStack(spacing: 20) {
            Spacer(minLength: 30)
            ZStack {
                Circle()
                    .stroke(Theme.dawnGradient, lineWidth: 3)
                    .frame(width: 110, height: 110)
                Image(systemName: "checkmark")
                    .font(.system(size: 44, weight: .bold))
                    .foregroundStyle(Theme.dawnGradient)
            }
            Text("You're set.")
                .font(.system(size: 34, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Your first clear morning starts now. One check-in a day — that's all it takes.")
                .font(.body)
                .foregroundStyle(Theme.calmGray)
                .multilineTextAlignment(.center)
            Spacer(minLength: 30)
        }
    }

    private var bottomBar: some View {
        Button {
            advance()
        } label: {
            Text(step == 0 ? "Get started" : step == totalSteps - 1 ? "Begin my journey" : "Continue")
                .font(.headline)
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Theme.dawnGradient, in: RoundedRectangle(cornerRadius: 16))
        }
        .disabled(finishing)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
    }

    private func stepHeader(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.subheadline)
                .foregroundStyle(Theme.calmGray)
        }
    }

    private func goalCard(id: String, icon: String, title: String, detail: String) -> some View {
        Button {
            goal = id
        } label: {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(Theme.amber)
                    .frame(width: 36)
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundStyle(.white)
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(Theme.calmGray)
                }
                Spacer()
                Image(systemName: goal == id ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(goal == id ? Theme.amber : Theme.calmGray)
            }
            .padding(16)
            .background(Theme.nightCard, in: RoundedRectangle(cornerRadius: 14))
        }
    }

    private func advance() {
        if step < totalSteps - 1 {
            withAnimation { step += 1 }
        } else {
            finish()
        }
    }

    private func finish() {
        finishing = true
        let name = journeyName.trimmingCharacters(in: .whitespacesAndNewlines)
        let journey = Journey(name: name.isEmpty ? "Alcohol" : name, goal: goal, taperWeeklyLimit: taperLimit, startDate: startDate)
        context.insert(journey)
        if let spend = Double(spendText), spend > 0 {
            context.insert(SavingConfig(journeyID: journey.id, dailySpend: spend, currency: currency))
        }
        for (i, why) in whys.enumerated() {
            context.insert(WhyItem(text: why, order: i))
        }
        try? context.save()
        let result = CheckInService.recalcAndPublish(context)
        NotificationService.rescheduleDailyRitual(streak: result?.current ?? 0)
        UserDefaults.standard.set(true, forKey: "cm.hasOnboarded")
        finishing = false
    }
}
