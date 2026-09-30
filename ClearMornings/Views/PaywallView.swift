import SwiftUI
import StoreKit

struct PaywallView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var purchaseManager: PurchaseManager

    @State private var selectedProductID: String?
    @State private var purchasing = false
    @State private var errorMessage: String?

    private var monthly: Product? { purchaseManager.products.first { $0.id == "cm.plus.monthly" } }
    private var yearly: Product? { purchaseManager.products.first { $0.id == "cm.plus.yearly" } }
    private var lifetimeBYO: Product? { purchaseManager.products.first { $0.id == "cm.byo.lifetime" } }

    var body: some View {
        NavigationStack {
            ScrollView(showsIndicators: false) {
                VStack(spacing: 20) {
                    hero
                    benefitList
                    if purchaseManager.isPlus {
                        alreadyPlus
                    } else {
                        planCards
                        subscribeButton
                        legalLinks
                        autoRenewDisclosure
                        restoreButton
                    }
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.red)
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(20)
                .padding(.bottom, 24)
            }
            .background(Theme.nightBase)
            .navigationTitle("Clear+")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Theme.calmGray)
                    }
                }
            }
        }
        .preferredColorScheme(.dark)
        .task { await purchaseManager.loadProducts() }
    }

    private var hero: some View {
        VStack(spacing: 12) {
            Image(systemName: "crown.fill")
                .font(.system(size: 44))
                .foregroundStyle(Theme.dawnGradient)
            Text("Clear+")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
            Text("Everything unlocked. Unlimited AI. Zero shame, zero limits.")
                .font(.subheadline)
                .foregroundStyle(Theme.calmGray)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var benefitList: some View {
        VStack(alignment: .leading, spacing: 12) {
            benefit(icon: "sparkles", title: "Unlimited AI craving coach", detail: "Morn anytime — no weekly caps.")
            benefit(icon: "person.text.rectangle", title: "AI Recovery Mirror", detail: "Visual progress comparisons.")
            benefit(icon: "doc.text.below.ecg", title: "Unlimited weekly reports", detail: "AI-written gentle reviews.")
            benefit(icon: "square.stack.3d.up", title: "Multiple journeys", detail: "Track more than one habit.")
            benefit(icon: "faceid", title: "Face ID privacy lock", detail: "Keep your journey yours.")
            benefit(icon: "paintpalette", title: "Dawn themes", detail: "More morning palettes.")
        }
        .padding(18)
        .background(Theme.nightCard, in: RoundedRectangle(cornerRadius: 18))
    }

    private func benefit(icon: String, title: String, detail: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(Theme.amber)
                .frame(width: 28)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(Theme.calmGray)
            }
            Spacer()
        }
    }

    private var planCards: some View {
        VStack(spacing: 12) {
            if let yearly {
                planCard(yearly, badge: "7-day free trial", subtitle: "Best value — 50% off")
            }
            if let monthly {
                planCard(monthly, badge: nil, subtitle: "Cancel anytime")
            }
        }
    }

    private func planCard(_ product: Product, badge: String?, subtitle: String) -> some View {
        let selected = selectedProductID == product.id || (selectedProductID == nil && product.id == "cm.plus.yearly")
        return Button {
            selectedProductID = product.id
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 8) {
                        Text(product.displayName.isEmpty ? "Clear+" : product.displayName)
                            .font(.headline)
                            .foregroundStyle(.white)
                        if let badge {
                            Text(badge)
                                .font(.caption2.weight(.bold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Theme.dawnGradient, in: Capsule())
                                .foregroundStyle(.white)
                        }
                    }
                    Text(subtitle)
                        .font(.caption)
                        .foregroundStyle(Theme.calmGray)
                }
                Spacer()
                Text(product.displayPrice)
                    .font(.headline)
                    .foregroundStyle(.white)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(selected ? Theme.amber : Theme.calmGray)
            }
            .padding(16)
            .background(
                selected ? AnyShapeStyle(Theme.dawnGradient.opacity(0.2)) : AnyShapeStyle(Color.white.opacity(0.06)),
                in: RoundedRectangle(cornerRadius: 14)
            )
            .overlay {
                if selected {
                    RoundedRectangle(cornerRadius: 14).stroke(Theme.dawnGradient, lineWidth: 1.5)
                }
            }
        }
    }

    private var subscribeButton: some View {
        Button {
            Task { await purchase() }
        } label: {
            HStack {
                if purchasing { ProgressView().tint(.white) }
                Text(purchasing ? "Processing..." : (selectedProductID == "cm.byo.lifetime" ? "Buy once" : "Start free trial"))
            }
            .font(.headline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Theme.dawnGradient, in: RoundedRectangle(cornerRadius: 16))
            .foregroundStyle(.white)
        }
        .disabled(purchasing)
    }

    private var legalLinks: some View {
        HStack(spacing: 20) {
            Link("Privacy Policy", destination: URL(string: "https://asunnyboy861.github.io/ClearMornings/privacy.html")!)
            Link("Terms of Use", destination: URL(string: "https://asunnyboy861.github.io/ClearMornings/terms.html")!)
        }
        .font(.caption)
        .tint(Theme.seaBlue)
    }

    private var autoRenewDisclosure: some View {
        Text("Clear+ auto-renews monthly or yearly through your Apple ID. Cancel anytime at least 24 hours before the period ends in Settings → Apple ID → Subscriptions. The 7-day free trial applies to the yearly plan; if you subscribe before the trial ends, you are automatically charged the yearly price afterward.")
            .font(.caption2)
            .foregroundStyle(Theme.calmGray)
            .multilineTextAlignment(.center)
    }

    private var restoreButton: some View {
        Button {
            Task { await purchaseManager.restorePurchases() }
        } label: {
            Text("Restore purchases")
                .font(.footnote)
                .tint(Theme.seaBlue)
        }
    }

    private var alreadyPlus: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.largeTitle)
                .foregroundStyle(Theme.amber)
            Text("You're a Clear+ member")
                .font(.headline)
                .foregroundStyle(.white)
            Text("Everything is unlocked. Thank you for supporting Clear Mornings.")
                .font(.caption)
                .foregroundStyle(Theme.calmGray)
                .multilineTextAlignment(.center)
        }
        .padding(24)
    }

    private func purchase() async {
        guard let id = selectedProductID ?? yearly?.id ?? monthly?.id,
              let product = purchaseManager.products.first(where: { $0.id == id }) else {
            errorMessage = "Products not loaded yet. Check your connection and try again."
            return
        }
        purchasing = true
        errorMessage = nil
        let ok = await purchaseManager.purchase(product)
        purchasing = false
        if ok {
            dismiss()
        } else if let err = purchaseManager.loadError {
            errorMessage = err
        }
    }
}
