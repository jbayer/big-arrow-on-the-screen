import CoreGraphics

/// Icons from Feather (https://feathericons.com, MIT, Copyright (c) 2013-2023 Cole Bemis; licence
/// in THIRD_PARTY_NOTICES.md). The inner SVG of `feather-icons@4.29.2` `dist/icons/<name>.svg`,
/// verbatim: a 24 x 24 viewBox, stroked 2 units wide with round caps and joins, never filled.
public enum FeatherIcon: String, CaseIterable, Sendable {
    case copy
    case check
    case eye
    case eyeOff = "eye-off"
    case externalLink = "external-link"
    case close = "x"
    case file
    case square
    case checkSquare = "check-square"

    public static let viewBox: CGFloat = 24
    public static let strokeWidth: CGFloat = 2

    public var svg: String {
        switch self {
        case .copy:
            #"<rect x="9" y="9" width="13" height="13" rx="2" ry="2"></rect>"#
                + #"<path d="M5 15H4a2 2 0 0 1-2-2V4a2 2 0 0 1 2-2h9a2 2 0 0 1 2 2v1"></path>"#
        case .check:
            #"<polyline points="20 6 9 17 4 12"></polyline>"#
        case .eye:
            #"<path d="M1 12s4-8 11-8 11 8 11 8-4 8-11 8-11-8-11-8z"></path>"#
                + #"<circle cx="12" cy="12" r="3"></circle>"#
        case .eyeOff:
            #"<path d="M17.94 17.94A10.07 10.07 0 0 1 12 20c-7 0-11-8-11-8a18.45 18.45 0 0 1 5.06-5.94"#
                + #"M9.9 4.24A9.12 9.12 0 0 1 12 4c7 0 11 8 11 8a18.5 18.5 0 0 1-2.16 3.19m-6.72-1.07a3 3 0 1 1-4.24-4.24"></path>"#
                + #"<line x1="1" y1="1" x2="23" y2="23"></line>"#
        case .externalLink:
            #"<path d="M18 13v6a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V8a2 2 0 0 1 2-2h6"></path><polyline points="15 3 21 3 21 9"></polyline>"#
                + #"<line x1="10" y1="14" x2="21" y2="3"></line>"#
        case .close:
            #"<line x1="18" y1="6" x2="6" y2="18"></line><line x1="6" y1="6" x2="18" y2="18"></line>"#
        case .file:
            #"<path d="M13 2H6a2 2 0 0 0-2 2v16a2 2 0 0 0 2 2h12a2 2 0 0 0 2-2V9z"></path><polyline points="13 2 13 9 20 9"></polyline>"#
        case .square:
            #"<rect x="3" y="3" width="18" height="18" rx="2" ry="2"></rect>"#
        case .checkSquare:
            #"<polyline points="9 11 12 14 22 4"></polyline><path d="M21 12v7a2 2 0 0 1-2 2H5a2 2 0 0 1-2-2V5a2 2 0 0 1 2-2h11"></path>"#
        }
    }

    /// The outline in viewBox units, y down as in SVG. The source is fixed, so a failure is a bug here.
    public var path: CGPath {
        do {
            return try SVGPath.icon(svg)
        } catch {
            preconditionFailure("Feather icon '\(rawValue)' does not parse: \(error)")
        }
    }
}
