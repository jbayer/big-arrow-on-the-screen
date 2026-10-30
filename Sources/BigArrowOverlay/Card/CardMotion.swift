import AppKit
import BigArrowCore

/// Small Core Animation touches that confirm what the human did: a press, a pop, a flash, a
/// "Copied" toast, the card sliding in and fading out. Every one is short and never blocks input.
@MainActor
enum CardMotion {
    static let quick: CFTimeInterval = 0.14
    static let settle: CFTimeInterval = 0.32

    /// Scales the view around its centre: down on press, a bounce for a pop.
    static func scale(_ view: NSView, through values: [CGFloat], duration: CFTimeInterval) {
        view.wantsLayer = true
        guard let layer = view.layer else { return }
        let center = CGPoint(x: view.bounds.midX, y: view.bounds.midY)
        let animation = CAKeyframeAnimation(keyPath: "transform")
        animation.values = values.map { scale in
            NSValue(caTransform3D: CATransform3DConcat(
                CATransform3DConcat(CATransform3DMakeTranslation(-center.x, -center.y, 0), CATransform3DMakeScale(scale, scale, 1)),
                CATransform3DMakeTranslation(center.x, center.y, 0)
            ))
        }
        animation.duration = duration
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        layer.add(animation, forKey: "scale")
    }

    static func press(_ view: NSView) {
        scale(view, through: [1, 0.93, 1], duration: quick * 2)
    }

    static func pop(_ view: NSView) {
        scale(view, through: [1, 1.35, 0.92, 1], duration: settle)
    }

    /// A wash of the card colour over the view that fades out.
    static func flash(_ view: NSView, color: NSColor) {
        view.wantsLayer = true
        let animation = CABasicAnimation(keyPath: "backgroundColor")
        animation.fromValue = color.withAlphaComponent(0.22).cgColor
        animation.toValue = NSColor.clear.cgColor
        animation.duration = 0.7
        animation.timingFunction = CAMediaTimingFunction(name: .easeOut)
        view.layer?.add(animation, forKey: "flash")
    }

    /// A pill with the text above `anchor`, rising a little while it fades out.
    static func toast(_ text: String, above anchor: NSView, style: CardStyle) {
        guard let host = anchor.window?.contentView ?? anchor.superview else { return }
        let label = NSTextField(labelWithString: text)
        label.font = CardStyle.buttonFont
        label.textColor = style.onTint
        label.alignment = .center
        label.wantsLayer = true
        label.drawsBackground = false
        label.layer?.backgroundColor = style.tint.cgColor
        label.layer?.cornerRadius = 10
        let size = label.fittingSize
        let width = size.width + 24
        let anchorFrame = host.convert(anchor.bounds, from: anchor)
        let x = min(max(anchorFrame.midX - width / 2, 8), host.bounds.width - width - 8)
        label.frame = CGRect(x: x, y: anchorFrame.maxY + 2, width: width, height: size.height + 8)
        host.addSubview(label)
        rise(label)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) { label.removeFromSuperview() }
    }

    static func rise(_ view: NSView) {
        let fade = CAKeyframeAnimation(keyPath: "opacity")
        fade.values = [0, 1, 1, 0]
        fade.keyTimes = [0, 0.15, 0.7, 1]
        let move = CABasicAnimation(keyPath: "transform")
        move.fromValue = NSValue(caTransform3D: CATransform3DMakeTranslation(0, -6, 0))
        move.toValue = NSValue(caTransform3D: CATransform3DMakeTranslation(0, 10, 0))
        let group = CAAnimationGroup()
        group.animations = [fade, move]
        group.duration = 1.3
        group.isRemovedOnCompletion = false
        group.fillMode = .forwards
        view.layer?.add(group, forKey: "toast")
    }

    /// The card arriving: fades in while sliding up a few points.
    static func enter(_ view: NSView) {
        guard let layer = view.layer else { return }
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 0
        fade.toValue = 1
        let slide = CABasicAnimation(keyPath: "transform")
        slide.fromValue = NSValue(caTransform3D: CATransform3DMakeTranslation(0, -18, 0))
        slide.toValue = NSValue(caTransform3D: CATransform3DIdentity)
        let group = CAAnimationGroup()
        group.animations = [fade, slide]
        group.duration = settle
        group.timingFunction = CAMediaTimingFunction(controlPoints: 0.2, 0.9, 0.3, 1)
        layer.add(group, forKey: "enter")
    }

    /// The card leaving: fades out and settles a little, then `completion`.
    static func leave(_ view: NSView, completion: @escaping @MainActor () -> Void) {
        guard let layer = view.layer else { return completion() }
        CATransaction.begin()
        CATransaction.setCompletionBlock { MainActor.assumeIsolated { completion() } }
        let fade = CABasicAnimation(keyPath: "opacity")
        fade.fromValue = 1
        fade.toValue = 0
        fade.duration = 0.18
        fade.isRemovedOnCompletion = false
        fade.fillMode = .forwards
        layer.add(fade, forKey: "leave")
        CATransaction.commit()
    }
}
