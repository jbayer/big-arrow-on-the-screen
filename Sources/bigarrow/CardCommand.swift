import ArgumentParser
import BigArrowCore
import BigArrowOverlay
import Foundation

struct CardCommand: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "card",
        abstract: "Show a cue card: a floating window with values to copy, secrets, links, buttons and questions.",
        discussion: """
        The card floats above every window, never takes the focus, and stays until the human
        clicks its X or the agent closes it ('stop --pid <pid>', 'stop --cards'); no time limit.
        It returns at once and prints its pid; 'bigarrow wait <pid>' (or --wait) prints what the
        human did as JSON as soon as they answer:
        {"result":"button","value":"done","copied":["User","Password"],...}. Exit 0 for an
        answer, 1 when the card was closed without one. An answered card stays up, showing
        what was sent, until its X.

        Secrets never go on the command line: --secret 'Password=pass:hetzner/web', or a JSON
        card on stdin. A row's "point" makes the arrow point at where its value goes.

          bigarrow card --title "Franz, log in to Hetzner" --field "User=franz@example.com" \\
            --secret "Password=keychain:hetzner/franz" --link https://console.hetzner.cloud --button "done=I'm in"
          bigarrow card --title "Franz, which design?" --choice "a=Dark header" --choice "b=Light header" --wait
          bigarrow card - < card.json        (rows: text, field, code, link, totp, qr, image, file,
                                              choice, input, checklist, progress, actions)
          bigarrow start --element "Pay" --app Safari --text "Franz, click Pay" --card card.json
        """
    )

    @OptionGroup var content: CardContentOptions
    @OptionGroup var options: CardRunOptions

    struct Started: Codable {
        var ok = true
        let pid: Int32
        /// The card's frame in global top-left points: x, y, width, height.
        let card: [Double]
        /// Its buttons and fields in global top-left points.
        var controls: [CardControl]?
    }

    struct Rendered: Codable {
        var ok = true
        let image: String
        let size: [Double]
        /// Its buttons and fields in the card's top-left points.
        let controls: [CardControl]
    }

    func run() throws {
        try MainActor.assumeIsolated {
            let document = try CardFlags.document(content)
            if options.dryRun {
                Output.print(JSONOutput.encode(document.redacted))
                return
            }
            let resolved = try document.resolvingSecrets()
            if let pid = options.update { return try update(pid, with: resolved) }
            if let png = options.png { return try render(resolved, to: png) }
            if options.child { try show(resolved) }
            let pid = try detach(resolved)
            if options.wait { try WaitCommand.reply(of: pid, timeout: 0) }
        }
    }

    @MainActor
    func show(_ document: CardDocument) throws -> Never {
        OverlayApplication.prepare()
        let session = try CardSession(document: document, base: nil, replyTarget: .file, raise: true)
        try session.start()
        OverlayApplication.runWithoutActivating()
    }

    @discardableResult
    func detach(_ document: CardDocument) throws -> Int32 {
        guard let executable = Bundle.main.executablePath else {
            throw BigArrowError.badInput("cannot find the bigarrow executable to detach")
        }
        let pid = try ChildProcess.spawn(executable, [executable, "card", "--child", "-"], stdin: document.encoded())
        try ChildProcess.waitUntilShown(pid)
        let record = PidRegistry().read(pid: pid)
        if !options.wait { Output.json(Started(pid: pid, card: record?.signFrame ?? [], controls: record?.controls)) }
        return pid
    }

    @MainActor
    func render(_ document: CardDocument, to path: String) throws {
        OverlayApplication.prepare()
        let view = try CardView(document: document, color: try ArrowColor.parse(document.color ?? "red"),
                                events: CardEvents(), maxHeight: .greatestFiniteMagnitude)
        try CardPNG.write(view, theme: document.theme, scale: 2, to: URL(fileURLWithPath: path))
        let size = view.fittingSize
        Output.json(Rendered(image: path, size: [Double(size.width), Double(size.height)], controls: view.controls()))
    }

    /// Leaves the new card next to the running one's pid file and tells it to show it.
    func update(_ pid: Int32, with document: CardDocument) throws {
        guard let record = PidRegistry().live().first(where: { $0.pid == pid }), record.kind == "card" else {
            throw BigArrowError.unresolvable("no live card with pid \(pid)")
        }
        let file = CardUpdate.file(for: pid)
        try Data().write(to: file)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file.path)
        try document.encoded().write(to: file)
        kill(pid, SIGUSR1)
        Output.json(Started(pid: pid, card: record.signFrame))
    }
}
