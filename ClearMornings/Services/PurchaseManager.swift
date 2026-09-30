import Foundation
import StoreKit
import Combine

enum Plan: String {
    case free
    case plus
    case byo
}

@MainActor
final class PurchaseManager: ObservableObject {
    static let shared = PurchaseManager()

    static let monthlyID = "cm.plus.monthly"
    static let yearlyID = "cm.plus.yearly"
    static let byoID = "cm.byo.lifetime"
    static let allIDs = [monthlyID, yearlyID, byoID]

    @Published var isPlus: Bool = false
    @Published var hasBYO: Bool = false
    @Published var products: [Product] = []
    @Published var isLoading: Bool = false
    @Published var loadError: String?

    private var transactionListener: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()

    var isPro: Bool { isPlus || hasBYO }
    var plan: Plan {
        if isPlus { return .plus }
        if hasBYO { return .byo }
        return .free
    }

    private init() {
        transactionListener = listenForTransactions()
        Task { await loadProducts() }
        Task { await refreshEntitlements() }
    }

    var monthlyProduct: Product? { products.first { $0.id == Self.monthlyID } }
    var yearlyProduct: Product? { products.first { $0.id == Self.yearlyID } }
    var byoProduct: Product? { products.first { $0.id == Self.byoID } }

    func loadProducts() async {
        isLoading = true
        do {
            products = try await Product.products(for: Self.allIDs)
            loadError = nil
        } catch {
            loadError = "Unable to load purchase options."
        }
        isLoading = false
    }

    func purchase(_ product: Product) async -> Bool {
        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                if case .verified(let transaction) = verification {
                    await transaction.finish()
                }
                await refreshEntitlements()
                return isPro
            case .userCancelled, .pending:
                return false
            @unknown default:
                return false
            }
        } catch {
            loadError = "Purchase failed: \(error.localizedDescription)"
            return false
        }
    }

    func restorePurchases() async {
        do {
            try await AppStore.sync()
            await refreshEntitlements()
        } catch {
            loadError = "Restore failed: \(error.localizedDescription)"
        }
    }

    func refreshEntitlements() async {
        var plus = false
        var byo = false
        for id in [Self.monthlyID, Self.yearlyID] {
            if let result = await Transaction.currentEntitlement(for: id),
               case .verified(let transaction) = result,
               transaction.revocationDate == nil {
                plus = true
            }
        }
        if let result = await Transaction.currentEntitlement(for: Self.byoID),
           case .verified(let transaction) = result,
           transaction.revocationDate == nil {
            byo = true
        }
        isPlus = plus
        hasBYO = byo
    }

    private func listenForTransactions() -> Task<Void, Never> {
        Task.detached { [weak self] in
            for await result in Transaction.updates {
                if case .verified(let transaction) = result {
                    await transaction.finish()
                    Task { @MainActor [weak self] in
                        await self?.refreshEntitlements()
                    }
                }
            }
        }
    }

    deinit {
        transactionListener?.cancel()
    }
}
