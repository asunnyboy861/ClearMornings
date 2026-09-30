import Foundation
import SwiftData

enum ExportService {
    static let backupVersion = 1

    struct Backup: Codable {
        var version: Int
        var exportedAt: Date
        var journeys: [JourneyDTO]
        var records: [RecordDTO]
        var editLogs: [EditLogDTO]
        var whys: [WhyDTO]
        var savingConfigs: [SavingDTO]
        var milestoneStates: [MilestoneDTO]
        var sosLogs: [SOSDTO]
        var journal: [JournalDTO]
        var photos: [PhotoDTO]
    }

    struct JourneyDTO: Codable {
        var id: UUID
        var name: String
        var goal: String
        var taperWeeklyLimit: Int
        var startDate: Date
        var timezoneID: String
        var colorHex: String
        var isArchived: Bool
        var createdAt: Date
    }

    struct RecordDTO: Codable {
        var journeyID: UUID
        var dayKey: String
        var status: String
        var mood: Int?
        var craving: Int?
        var note: String
        var updatedAt: Date
    }

    struct EditLogDTO: Codable {
        var dayKey: String
        var field: String
        var oldValue: String
        var newValue: String
        var editedAt: Date
    }

    struct WhyDTO: Codable {
        var text: String
        var order: Int
        var isPinned: Bool
        var createdAt: Date
    }

    struct SavingDTO: Codable {
        var journeyID: UUID
        var dailySpend: Double
        var currency: String
    }

    struct MilestoneDTO: Codable {
        var journeyID: UUID
        var milestoneID: String
        var achievedAt: Date
    }

    struct SOSDTO: Codable {
        var triggeredAt: Date
        var resolvedBy: String
        var cravingBefore: Int?
        var cravingAfter: Int?
    }

    struct JournalDTO: Codable {
        var dayKey: String
        var text: String
        var aiSummary: String
        var createdAt: Date
    }

    struct PhotoDTO: Codable {
        var dayKey: String
        var localFileName: String
        var mirrorResult: String
        var createdAt: Date
    }

    static func buildBackup(_ context: ModelContext) throws -> Backup {
        let journeys = try context.fetch(FetchDescriptor<Journey>())
        let records = try context.fetch(FetchDescriptor<DayRecord>())
        let editLogs = try context.fetch(FetchDescriptor<EditLog>())
        let whys = try context.fetch(FetchDescriptor<WhyItem>())
        let savings = try context.fetch(FetchDescriptor<SavingConfig>())
        let milestones = try context.fetch(FetchDescriptor<MilestoneState>())
        let sos = try context.fetch(FetchDescriptor<SOSLog>())
        let journal = try context.fetch(FetchDescriptor<JournalEntry>())
        let photos = try context.fetch(FetchDescriptor<PhotoCheckIn>())

        return Backup(
            version: backupVersion,
            exportedAt: .now,
            journeys: journeys.map { JourneyDTO(id: $0.id, name: $0.name, goal: $0.goal, taperWeeklyLimit: $0.taperWeeklyLimit, startDate: $0.startDate, timezoneID: $0.timezoneID, colorHex: $0.colorHex, isArchived: $0.isArchived, createdAt: $0.createdAt) },
            records: records.map { RecordDTO(journeyID: $0.journeyID, dayKey: $0.dayKey, status: $0.statusRaw, mood: $0.moodValue, craving: $0.cravingValue, note: $0.note, updatedAt: $0.updatedAt) },
            editLogs: editLogs.map { EditLogDTO(dayKey: $0.dayKey, field: $0.field, oldValue: $0.oldValue, newValue: $0.newValue, editedAt: $0.editedAt) },
            whys: whys.map { WhyDTO(text: $0.text, order: $0.order, isPinned: $0.isPinned, createdAt: $0.createdAt) },
            savingConfigs: savings.map { SavingDTO(journeyID: $0.journeyID, dailySpend: $0.dailySpend, currency: $0.currency) },
            milestoneStates: milestones.map { MilestoneDTO(journeyID: $0.journeyID, milestoneID: $0.milestoneID, achievedAt: $0.achievedAt) },
            sosLogs: sos.map { SOSDTO(triggeredAt: $0.triggeredAt, resolvedBy: $0.resolvedBy, cravingBefore: $0.cravingBefore < 0 ? nil : $0.cravingBefore, cravingAfter: $0.cravingAfter < 0 ? nil : $0.cravingAfter) },
            journal: journal.map { JournalDTO(dayKey: $0.dayKey, text: $0.text, aiSummary: $0.aiSummary, createdAt: $0.createdAt) },
            photos: photos.map { PhotoDTO(dayKey: $0.dayKey, localFileName: $0.localFileName, mirrorResult: $0.mirrorResult, createdAt: $0.createdAt) }
        )
    }

    static func exportJSON(_ context: ModelContext) throws -> URL {
        let backup = try buildBackup(context)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(backup)
        return try write(data, name: "ClearMornings-Backup-\(fileStamp()).json")
    }

    static func exportCSV(_ context: ModelContext) throws -> URL {
        let journeys = try context.fetch(FetchDescriptor<Journey>())
        let records = try context.fetch(FetchDescriptor<DayRecord>())
        let nameByID = Dictionary(journeys.map { ($0.id, $0.name) }, uniquingKeysWith: { a, _ in a })
        let sorted = records.sorted { $0.dayKey == $1.dayKey ? $0.journeyID.uuidString < $1.journeyID.uuidString : $0.dayKey < $1.dayKey }

        var csv = "day,journey,status,mood,craving,note\n"
        let formatter = NumberFormatter()
        formatter.maximumFractionDigits = 0
        for r in sorted {
            let name = (nameByID[r.journeyID] ?? "Journey").replacingOccurrences(of: ",", with: " ")
            let note = r.note.replacingOccurrences(of: "\"", with: "\"\"")
            let mood = r.moodValue.map(String.init) ?? ""
            let craving = r.cravingValue.map(String.init) ?? ""
            csv += "\(r.dayKey),\(name),\(r.statusRaw),\(mood),\(craving),\"\(note)\"\n"
        }
        guard let data = csv.data(using: .utf8) else {
            throw NSError(domain: "ExportService", code: 1, userInfo: [NSLocalizedDescriptionKey: "CSV encoding failed"])
        }
        return try write(data, name: "ClearMornings-History-\(fileStamp()).csv")
    }

    @discardableResult
    static func importJSON(from url: URL, into context: ModelContext) throws -> Int {
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(Backup.self, from: data)

        var merged = 0

        let localJourneys = try context.fetch(FetchDescriptor<Journey>())
        var journeyByID = Dictionary(localJourneys.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for dto in backup.journeys {
            guard journeyByID[dto.id] == nil else { continue }
            let j = Journey(name: dto.name, goal: dto.goal, taperWeeklyLimit: dto.taperWeeklyLimit, startDate: dto.startDate, colorHex: dto.colorHex)
            j.id = dto.id
            j.timezoneID = dto.timezoneID
            j.isArchived = dto.isArchived
            j.createdAt = dto.createdAt
            context.insert(j)
            journeyByID[dto.id] = j
            merged += 1
        }

        let localRecords = try context.fetch(FetchDescriptor<DayRecord>())
        var recordByKey = Dictionary(localRecords.map { ("\($0.journeyID.uuidString)|\($0.dayKey)", $0) }, uniquingKeysWith: { a, _ in a })
        for dto in backup.records {
            let key = "\(dto.journeyID.uuidString)|\(dto.dayKey)"
            if let local = recordByKey[key] {
                if dto.updatedAt > local.updatedAt {
                    local.statusRaw = dto.status
                    local.mood = dto.mood ?? 0
                    local.craving = dto.craving ?? -1
                    local.note = dto.note
                    local.updatedAt = dto.updatedAt
                    merged += 1
                }
            } else {
                let r = DayRecord(dayKey: dto.dayKey, journeyID: dto.journeyID, status: DayStatus(rawValue: dto.status) ?? .unknown, mood: dto.mood, craving: dto.craving, note: dto.note)
                r.updatedAt = dto.updatedAt
                context.insert(r)
                recordByKey[key] = r
                merged += 1
            }
        }

        let localEditLogs = try context.fetch(FetchDescriptor<EditLog>())
        var editSig = Set(localEditLogs.map { "\($0.dayKey)|\($0.field)|\($0.editedAt.timeIntervalSince1970)" })
        for dto in backup.editLogs {
            let sig = "\(dto.dayKey)|\(dto.field)|\(dto.editedAt.timeIntervalSince1970)"
            guard !editSig.contains(sig) else { continue }
            context.insert(EditLog(dayKey: dto.dayKey, field: dto.field, oldValue: dto.oldValue, newValue: dto.newValue))
            editSig.insert(sig)
            merged += 1
        }

        let localWhys = try context.fetch(FetchDescriptor<WhyItem>())
        var whyTexts = Set(localWhys.map(\.text))
        for dto in backup.whys {
            guard !whyTexts.contains(dto.text) else { continue }
            context.insert(WhyItem(text: dto.text, order: dto.order, isPinned: dto.isPinned))
            whyTexts.insert(dto.text)
            merged += 1
        }

        let localSavings = try context.fetch(FetchDescriptor<SavingConfig>())
        for dto in backup.savingConfigs {
            if let local = localSavings.first(where: { $0.journeyID == dto.journeyID }) {
                if dto.dailySpend > 0 {
                    local.dailySpend = dto.dailySpend
                    local.currency = dto.currency
                    merged += 1
                }
            } else {
                context.insert(SavingConfig(journeyID: dto.journeyID, dailySpend: dto.dailySpend, currency: dto.currency))
                merged += 1
            }
        }

        let localMilestones = try context.fetch(FetchDescriptor<MilestoneState>())
        for dto in backup.milestoneStates {
            if let local = localMilestones.first(where: { $0.journeyID == dto.journeyID && $0.milestoneID == dto.milestoneID }) {
                if dto.achievedAt < local.achievedAt {
                    local.achievedAt = dto.achievedAt
                    merged += 1
                }
            } else {
                context.insert(MilestoneState(journeyID: dto.journeyID, milestoneID: dto.milestoneID, achievedAt: dto.achievedAt))
                merged += 1
            }
        }

        let localSOS = try context.fetch(FetchDescriptor<SOSLog>())
        var sosSig = Set(localSOS.map { "\($0.triggeredAt.timeIntervalSince1970)|\($0.resolvedBy)" })
        for dto in backup.sosLogs {
            let sig = "\(dto.triggeredAt.timeIntervalSince1970)|\(dto.resolvedBy)"
            guard !sosSig.contains(sig) else { continue }
            context.insert(SOSLog(resolvedBy: dto.resolvedBy, cravingBefore: dto.cravingBefore, cravingAfter: dto.cravingAfter))
            sosSig.insert(sig)
            merged += 1
        }

        let localJournal = try context.fetch(FetchDescriptor<JournalEntry>())
        var journalSig = Set(localJournal.map { "\($0.dayKey)|\($0.createdAt.timeIntervalSince1970)" })
        for dto in backup.journal {
            let sig = "\(dto.dayKey)|\(dto.createdAt.timeIntervalSince1970)"
            guard !journalSig.contains(sig) else { continue }
            let j = JournalEntry(dayKey: dto.dayKey, text: dto.text)
            j.aiSummary = dto.aiSummary
            j.createdAt = dto.createdAt
            context.insert(j)
            journalSig.insert(sig)
            merged += 1
        }

        let localPhotos = try context.fetch(FetchDescriptor<PhotoCheckIn>())
        var photoSig = Set(localPhotos.map(\.localFileName))
        for dto in backup.photos {
            guard !photoSig.contains(dto.localFileName) else { continue }
            let p = PhotoCheckIn(dayKey: dto.dayKey, localFileName: dto.localFileName)
            p.mirrorResult = dto.mirrorResult
            p.createdAt = dto.createdAt
            context.insert(p)
            photoSig.insert(dto.localFileName)
            merged += 1
        }

        try context.save()
        return merged
    }

    static func documentsURL() -> URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    private static func write(_ data: Data, name: String) throws -> URL {
        let url = documentsURL().appendingPathComponent(name)
        try data.write(to: url, options: .atomic)
        return url
    }

    private static func fileStamp() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmm"
        return f.string(from: .now)
    }
}
