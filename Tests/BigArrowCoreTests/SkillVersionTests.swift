import BigArrowCore
import Foundation
import Testing

/// The skill is linked from main and can run ahead of the installed binary; its
/// "Needs bigarrow X" line is the gate, so it must exist and name a version that ships.
@Suite("Skill version gate")
struct SkillVersionTests {
    @Test("SKILL.md names a minimum version that is not newer than this build")
    func minimumVersion() throws {
        let skill = URL(filePath: #filePath).deletingLastPathComponent()
            .appending(path: "../../skill/big-arrow/SKILL.md").standardized
        let text = try String(contentsOf: skill, encoding: .utf8)
        let match = try #require(text.firstMatch(of: /Needs bigarrow (\d+)\.(\d+)\.(\d+) or newer/))
        let needed = [Int(match.1), Int(match.2), Int(match.3)].compactMap { $0 }
        let current = BigArrowVersion.current.split(separator: ".").compactMap { Int($0) }
        #expect(needed.lexicographicallyPrecedes(current) || needed == current,
                "SKILL.md needs \(needed), this build is \(current): release first")
    }
}
