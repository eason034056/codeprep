import Foundation
import SwiftData

@Model
final class SDDailyChallenge {
    @Attribute(.unique) var challengeId: UUID
    var userId: String = ""
    var date: Date
    // ⚠️ CoreData 不認識 Swift 的 [Int]，改用 Data 儲存避免 console 警告
    private var problemIdsData: Data = Data()
    private var completedProblemIdsData: Data = Data()
    var lastModified: Date = Date()
    var syncStatus: String = "pendingUpload"

    // 💡 @Transient 表示這個屬性不會被 SwiftData 持久化，
    //    它只是一個方便存取的計算屬性，實際資料存在上面的 Data 裡
    @Transient var problemIds: [Int] {
        get { (try? JSONDecoder().decode([Int].self, from: problemIdsData)) ?? [] }
        set { problemIdsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    @Transient var completedProblemIds: [Int] {
        get { (try? JSONDecoder().decode([Int].self, from: completedProblemIdsData)) ?? [] }
        set { completedProblemIdsData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    init(challengeId: UUID, userId: String = "", date: Date, problemIds: [Int], completedProblemIds: [Int] = []) {
        self.challengeId = challengeId
        self.userId = userId
        self.date = date
        self.problemIdsData = (try? JSONEncoder().encode(problemIds)) ?? Data()
        self.completedProblemIdsData = (try? JSONEncoder().encode(completedProblemIds)) ?? Data()
    }
}
