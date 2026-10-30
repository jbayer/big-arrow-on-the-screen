@testable import BigArrowCore
import CoreGraphics
import Foundation
import Testing

/// Secret sources against the real environment, files and login keychain; TOTP against the
/// RFC 6238 test vectors; card placement against display geometry.
@Suite("Card secrets, TOTP and placement")
struct CardSecretTests {
    @Test("Sources parse; anything else is rejected without echoing it")
    func parsing() throws {
        #expect(try SecretSource.parse("pass:hetzner/web") == .pass("hetzner/web"))
        #expect(try SecretSource.parse("keychain:my service/franz") == .keychain(service: "my service", account: "franz"))
        #expect(try SecretSource.parse("op:vault/item/password") == .onePassword("op://vault/item/password"))
        #expect(try SecretSource.parse("env:TOKEN") == .environment("TOKEN"))
        #expect(try SecretSource.parse("file:~/x") == .file("~/x"))
        for literal in ["hunter2", "pass:", "keychain:nouser", "ftp:x"] {
            do {
                _ = try SecretSource.parse(literal)
                Issue.record("\(literal) parsed")
            } catch let error as BigArrowError {
                #expect(error.code == .badInput)
                #expect(!error.message.contains("hunter2"))
            }
        }
    }

    @Test("env: and file: read the value, trimmed; an empty one exits 3")
    func environmentAndFile() throws {
        #expect(try SecretSource.environment("T").resolve(environment: ["T": " s3cret\n"]) == "s3cret")
        #expect(throws: BigArrowError.unresolvable("secret source env:T gave no value")) {
            try SecretSource.environment("T").resolve(environment: [:])
        }
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("bigarrow-secret-\(UUID().uuidString)")
        try "from file\n".write(to: file, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: file) }
        #expect(try SecretSource.file(file.path).resolve() == "from file")
    }

    @Test("keychain: reads a generic password from the real login keychain")
    func keychain() throws {
        let service = "bigarrow-test-\(UUID().uuidString)"
        let add = Process()
        add.executableURL = URL(fileURLWithPath: "/usr/bin/security")
        add.arguments = ["add-generic-password", "-s", service, "-a", "test", "-w", "kc-value"]
        try add.run()
        add.waitUntilExit()
        guard add.terminationStatus == 0 else {
            print("skipped: no writable login keychain here (security exited \(add.terminationStatus))")
            return
        }
        defer {
            let delete = Process()
            delete.executableURL = URL(fileURLWithPath: "/usr/bin/security")
            delete.arguments = ["delete-generic-password", "-s", service, "-a", "test"]
            try? delete.run()
            delete.waitUntilExit()
        }
        #expect(try SecretSource.keychain(service: service, account: "test").resolve() == "kc-value")
        #expect(throws: BigArrowError.self) { try SecretSource.keychain(service: service, account: "nobody").resolve() }
    }

    @Test("TOTP matches the RFC 6238 SHA-1 test vectors (8 digits) and authenticator seeds")
    func totpVectors() throws {
        let key = Data("12345678901234567890".utf8)
        let totp = TOTP(key: key, digits: 8)
        let vectors: [(Double, String)] = [
            (59, "94287082"), (1_111_111_109, "07081804"), (1_111_111_111, "14050471"),
            (1_234_567_890, "89005924"), (2_000_000_000, "69279037"), (20_000_000_000, "65353130")
        ]
        for (time, code) in vectors {
            #expect(totp.code(at: Date(timeIntervalSince1970: time)) == code, "t=\(time)")
        }
        #expect(Base32.decode("GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ") == key)
        let seed = try TOTP(seed: "gezd gnbv gy3t qojq gezd gnbv gy3t qojq")
        #expect(seed.code(at: Date(timeIntervalSince1970: 59)) == "287082")
        let uri = try TOTP(seed: "otpauth://totp/x?secret=GEZDGNBVGY3TQOJQGEZDGNBVGY3TQOJQ&digits=8")
        #expect(uri.code(at: Date(timeIntervalSince1970: 59)) == "94287082")
        #expect(seed.remaining(at: Date(timeIntervalSince1970: 59)) == 1)
        #expect(throws: BigArrowError.self) { try TOTP(seed: "not base32!") }
    }

    let display = Display(index: 0, id: 1, frame: CGRect(x: 0, y: 0, width: 1512, height: 982),
                          visibleFrame: CGRect(x: 0, y: 33, width: 1512, height: 949), scale: 2)
    let size = CGSize(width: 440, height: 400)

    @Test("A card goes beside its app's window, else to the other side, else into a corner")
    func besideWindow() {
        var placement = CardPlacement(size: size, display: display)
        placement.window = CGRect(x: 100, y: 100, width: 700, height: 600)
        #expect(placement.origin() == CGPoint(x: 816, y: 100))
        placement.window = CGRect(x: 700, y: 100, width: 700, height: 600)
        #expect(placement.origin() == CGPoint(x: 244, y: 100))
        placement.window = CGRect(x: 20, y: 60, width: 1470, height: 900)
        #expect(placement.origin().x == 20 + 1470 - CardPlacement.gap - size.width)
    }

    @Test("Without a window the card sits bottom right, clear of notifications, and moves off a rect it must keep clear")
    func corners() {
        var placement = CardPlacement(size: size, display: display)
        let area = display.visibleFrame.insetBy(dx: CardPlacement.margin, dy: CardPlacement.margin)
        #expect(placement.origin() == CGPoint(x: area.maxX - size.width, y: area.maxY - size.height))
        placement.avoid = [CGRect(x: 1300, y: 800, width: 40, height: 40)]
        #expect(placement.origin() == CGPoint(x: area.minX, y: area.maxY - size.height))
        let card = CGRect(origin: placement.origin(), size: size)
        #expect(display.visibleFrame.contains(card))
    }
}
