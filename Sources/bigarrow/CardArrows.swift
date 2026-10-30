import ArgumentParser
import BigArrowCore
import BigArrowOverlay
import BigArrowTargeting
import Foundation

/// The one arrow that goes with a card: the arrow of `point --card`, or the arrow of the row the
/// human is working on. A row's `point` is planned with exactly the code `bigarrow point` uses.
/// A click on its sign hides it; the card stays.
@MainActor
final class CardArrows {
    var document: CardDocument
    let color: String
    let overlay: OverlayController
    let raise: Bool
    private(set) var shown: PlannedArrow?
    /// The arrow of `point --card`, shown whenever no row's arrow is.
    var base: PlannedArrow?

    init(document: CardDocument, color: String, raise: Bool) throws {
        self.document = document
        self.color = color
        self.raise = raise
        let appearance = SignAppearance(color: try ArrowColor.parse(color), size: .medium, corners: .round)
        overlay = OverlayController(mode: AnimationMode.resolve(disabled: false), appearance: appearance)
        overlay.dismissOnClick { [weak self] in self?.hide() }
    }

    /// The arrow for a row or checklist item, resolved now (raising its app first).
    func plan(_ point: CardPoint, name: String) throws -> PlannedArrow {
        let config = try Self.config(point, name: name, document: document, color: color)
        if raise, let home = config.home {
            _ = try AppRaiser.raise(app: home.app, windowTitle: home.title, screens: ScreenReader.current())
        }
        let screens = ScreenReader.current()
        return try PointRunner(config: config).plan(config.target.resolve(screens: screens), screens: screens)
    }

    static func config(_ point: CardPoint, name: String, document: CardDocument, color: String) throws -> PointConfig {
        let text = point.text ?? "Paste \(name) here"
        do {
            return try PointConfig(
                target: TargetOptions.parse(point.targetArguments(defaultApp: document.app)),
                look: LookOptions.parse(["--text", text, "--color", color]),
                behaviour: BehaviourOptions.parse([]), mode: .foreground
            )
        } catch let error as BigArrowError {
            throw error
        } catch {
            throw BigArrowError.badInput("card point for \(name): \(TargetOptions.message(for: error))")
        }
    }

    func show(_ planned: PlannedArrow) throws {
        try overlay.show(planned.layout, sign: planned.sign, animated: shown == nil)
        shown = planned
    }

    /// Shows the row's arrow; a target that cannot be found now leaves the arrow as it is.
    @discardableResult
    func activate(_ point: CardPoint, name: String) -> Bool {
        guard let planned = try? plan(point, name: name) else { return false }
        return (try? show(planned)) != nil
    }

    /// After `card --update`: the new card's first point, else the base arrow, else no arrow.
    func retarget(_ next: CardDocument) -> String? {
        document = next
        if let (point, name) = CardSession.firstPoint(in: next), activate(point, name: name) { return name }
        if let base { try? show(base) } else { hide() }
        return nil
    }

    func hide() {
        overlay.hide()
        shown = nil
    }

    func dismiss(completion: @escaping @MainActor () -> Void) {
        guard shown != nil else { return completion() }
        overlay.dismiss(completion: completion)
    }

    /// Sign and target of the shown arrow in global points, for the card to keep clear of.
    var keepClear: [CGRect] {
        guard let shown else { return [] }
        let display = shown.layout.display.frame
        var rects = [shown.layout.signRect.offsetBy(dx: display.minX, dy: display.minY)]
        if let rect = shown.resolved.shape.rect { rects.append(rect) }
        let anchor = shown.resolved.shape.anchor
        rects.append(CGRect(x: anchor.x - 40, y: anchor.y - 40, width: 80, height: 80))
        return rects
    }
}
