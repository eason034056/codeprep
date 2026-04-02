import Foundation

struct PlayerLevel {
    let level: Int
    let title: String
    let xpFloor: Int
    let xpCeiling: Int
}

enum LevelSystem {
    private static let levels: [PlayerLevel] = [
        PlayerLevel(level: 1, title: "Beginner", xpFloor: 0, xpCeiling: 100),
        PlayerLevel(level: 2, title: "Apprentice", xpFloor: 100, xpCeiling: 300),
        PlayerLevel(level: 3, title: "Problem Solver", xpFloor: 300, xpCeiling: 600),
        PlayerLevel(level: 4, title: "Algorithm Pro", xpFloor: 600, xpCeiling: 1000),
        PlayerLevel(level: 5, title: "Code Master", xpFloor: 1000, xpCeiling: 1500),
        PlayerLevel(level: 6, title: "Elite Coder", xpFloor: 1500, xpCeiling: 2000),
        PlayerLevel(level: 7, title: "CodePrep Legend", xpFloor: 2000, xpCeiling: Int.max),
    ]

    static func level(for xp: Int) -> PlayerLevel {
        levels.last(where: { xp >= $0.xpFloor }) ?? levels[0]
    }

    static func progressToNextLevel(xp: Int) -> Double {
        let current = level(for: xp)
        guard current.xpCeiling != Int.max else { return 1.0 }
        let range = current.xpCeiling - current.xpFloor
        let progress = xp - current.xpFloor
        return min(1.0, Double(progress) / Double(range))
    }

    static func xpToNextLevel(xp: Int) -> Int {
        let current = level(for: xp)
        guard current.xpCeiling != Int.max else { return 0 }
        return current.xpCeiling - xp
    }
}
