import Foundation

enum CrisisGuard {
    enum Action {
        case hotline988
        case medicalFirst
        case proceed
    }

    static let crisisWords = [
        "kill myself", "suicide", "suicidal", "end it all", "end my life",
        "hurt myself", "self harm", "self-harm", "want to die", "better off dead",
        "no reason to live", "don't want to live", "dont want to live"
    ]

    static let withdrawalWords = [
        "shaking", "shaky", "withdrawal", "withdrawals", "hallucinating", "hallucination",
        "sweating badly", "seizure", "seizures", "delirium", "dt s", "the dts"
    ]

    static func screen(_ text: String) -> Action {
        let lowered = text.lowercased()
        if crisisWords.contains(where: { lowered.contains($0) }) { return .hotline988 }
        if withdrawalWords.contains(where: { lowered.contains($0) }) { return .medicalFirst }
        return .proceed
    }
}
