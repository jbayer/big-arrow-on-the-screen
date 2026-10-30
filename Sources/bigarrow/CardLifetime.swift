import AppKit
import BigArrowCore
import BigArrowOverlay
import Foundation

/// A card ends only when the human clicks its X or the agent closes it on purpose
/// (`stop --pid`, `stop --cards`: a signal). No time limit, no prompt hook, no agent exit. Its
/// arrow is different: it goes after its time limit or when the agent exits, as every arrow does.
/// SIGUSR1 means `card --update` left a new card to show.
extension CardSession {
    static let endSignals = [SIGTERM, SIGINT, SIGHUP]

    func installLifetime() {
        for number in Self.endSignals {
            listen(number) { [weak self] in self?.finish(.stopped, value: nil) }
        }
        listen(SIGUSR1) { [weak self] in self?.applyUpdate() }
        if let limit = arrowLimit, limit > 0 {
            DispatchQueue.main.asyncAfter(deadline: .now() + limit) { [weak self] in
                MainActor.assumeIsolated { self?.dropArrows() }
            }
        }
        watchOwner()
        if document.say == true { speech = Speech.say(document.title, voice: nil) }
    }

    /// The arrows go; the card stays.
    func dropArrows() {
        arrows.base = nil
        arrows.hide()
        controller?.view.markActive(nil)
    }

    func listen(_ number: Int32, handler: @escaping @MainActor () -> Void) {
        signal(number, SIG_IGN)
        let source = DispatchSource.makeSignalSource(signal: number, queue: .main)
        source.setEventHandler { MainActor.assumeIsolated { handler() } }
        source.resume()
        signalSources.append(source)
    }

    func watchOwner() {
        guard let pid = owner.pid else { return }
        guard PidRegistry.isProcessAlive(pid) else {
            DispatchQueue.main.async { MainActor.assumeIsolated { self.dropArrows() } }
            return
        }
        ownerWatch = OwnerWatch(pid: pid) { [weak self] in self?.dropArrows() }
    }

    /// The pid file is the "card is on screen" signal for the detaching parent.
    func announceWhenShown() {
        DispatchQueue.main.async {
            MainActor.assumeIsolated {
                do {
                    try self.writeRecord()
                } catch {
                    Output.fail(.badInput("cannot write the pid file: \(error.localizedDescription)"), json: true)
                }
            }
        }
    }

    func writeRecord() throws {
        guard let frame = controller?.frame else { return }
        let screens = ScreenReader.current()
        let display = (try? screens.display(containing: CGPoint(x: frame.midX, y: frame.midY)))?.index ?? 0
        let target = arrows.shown?.resolved.shape.anchor ?? CGPoint(x: frame.midX, y: frame.midY)
        var record = ArrowRecord(
            pid: getpid(), text: document.title, target: target, display: display + 1,
            sign: (frame, "card"), startedAt: startedAt
        )
        record.owner = owner.pid == nil && owner.session == nil ? nil : owner
        record.kind = "card"
        record.controls = controller?.view.controls().map { control in
            CardControl(name: control.name, rect: CGRect(
                x: frame.minX + control.rect[0], y: frame.minY + control.rect[1], width: control.rect[2], height: control.rect[3]
            ))
        }
        try PidRegistry().write(record)
    }

    /// Shows the card `card --update` left in the registry at the same place. What the human
    /// copied, ticked or typed so far stays in the reply.
    func applyUpdate() {
        let file = CardUpdate.file(for: getpid())
        defer { try? FileManager.default.removeItem(at: file) }
        guard let data = try? Data(contentsOf: file), let next = try? CardDocument.parse(data),
              let topLeft = controller?.frame?.origin, let display = try? placementDisplay() else { return }
        let previous = document
        document = next
        guard let view = try? makeView(display: display) else {
            document = previous
            return
        }
        controller?.close()
        let controller = CardController(view: view)
        controller.show(at: topLeft, theme: next.theme)
        self.controller = controller
        view.markActive(arrows.retarget(next))
        try? writeRecord()
    }

    /// Arrow and card fade out together; once both are gone the reply goes out and the process exits.
    func finish(_ outcome: CardOutcome, value: String?) {
        guard !finished else { return }
        finished = true
        speech?.terminate()
        ownerWatch?.stop()
        var pending = 2
        let done: @MainActor () -> Void = { [self] in
            pending -= 1
            if pending == 0 { exitWithReply(outcome, value: value) }
        }
        arrows.dismiss(completion: done)
        if let controller { controller.close(completion: done) } else { done() }
    }

    func exitWithReply(_ outcome: CardOutcome, value: String?) -> Never {
        PidRegistry().remove(pid: getpid())
        // Every question answered: the last answer is the result; otherwise how it ended
        // ("closed" for the X), with whatever was answered so far in `answers`.
        let (result, answer) = isComplete ? (self.answer ?? (outcome, value)) : (outcome, value)
        let reply = progress.reply(pid: getpid(), result: result, value: answer, startedAt: startedAt)
        if replyTarget == .stdout {
            Output.print(reply.line())
        } else if !replied {
            try? PidRegistry().writeReply(reply)
        }
        exit(reply.exitCode)
    }

    /// One question answered: that row dims, its pick lit. Once every question is answered the
    /// reply goes out (`wait` returns) and the card closes itself, or with `keep` stays until its X.
    func answered(_ row: CardRow, outcome: CardOutcome, value: String?) {
        guard let index = document.questions.first(where: { document.rows[$0] == row && answeredRows[$0] == nil }) else { return }
        answeredRows[index] = outcome
        answer = (outcome, value)
        progress.answers[row.id ?? "row \(index + 1)"] = value ?? outcome.rawValue
        controller?.markRowAnswered(index, chosen: row.items?.first { $0.id == value }?.label)
        guard isComplete else { return }
        if replyTarget == .file {
            let reply = progress.reply(pid: getpid(), result: outcome, value: value, startedAt: startedAt)
            replied = (try? PidRegistry().writeReply(reply)) != nil
        }
        dropArrows()
        guard document.keep == true else {
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.closeDelay) { [weak self] in
                MainActor.assumeIsolated { self?.finish(outcome, value: value) }
            }
            return
        }
        controller?.showSent("Sent. Close this card with the X.")
        // The card grew: frame and controls in the pid file follow.
        try? writeRecord()
    }

    /// Long enough to see the picked answer light up before the card goes.
    static let closeDelay: TimeInterval = 0.7

    var isComplete: Bool { !document.questions.isEmpty && answeredRows.count == document.questions.count }
}

/// Where `card --update` leaves the new card for a running one.
enum CardUpdate {
    static func file(for pid: Int32) -> URL {
        PidRegistry().directory.appendingPathComponent("\(pid).update")
    }
}

/// Speaks a sentence with macOS `say`, for when the human is not looking.
enum Speech {
    static func say(_ text: String, voice: String?) -> Process? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/say")
        process.arguments = (voice.map { ["-v", $0] } ?? []) + [text]
        process.standardOutput = FileHandle.nullDevice
        process.standardError = FileHandle.nullDevice
        do {
            try process.run()
            return process
        } catch {
            Output.printError("bigarrow: could not run /usr/bin/say: \(error.localizedDescription)")
            return nil
        }
    }
}
