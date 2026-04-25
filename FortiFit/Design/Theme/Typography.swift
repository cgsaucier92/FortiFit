import SwiftUI

enum FortiFitTypography {
    // MARK: - Brand
    static let brand = Font.system(size: 24, weight: .bold)
    static let brandKerning: CGFloat = 4

    // MARK: - Screen Headings
    static let screenHeading = Font.system(size: 24, weight: .bold)
    static let screenHeadingKerning: CGFloat = 2

    // MARK: - Widget Headers
    static let widgetHeader = Font.system(size: 20, weight: .semibold)
    static let widgetHeaderKerning: CGFloat = 2

    // MARK: - Labels
    static let label = Font.system(size: 16, weight: .semibold)
    static let labelSmall = Font.system(size: 13, weight: .semibold)
    static let labelKerning: CGFloat = 2

    // MARK: - Body
    static let body = Font.system(size: 18, weight: .regular)

    // MARK: - Body Small
    static let bodySmall = Font.system(size: 16, weight: .regular)

    // MARK: - Values / Data
    static let dataValue = Font.system(size: 18, weight: .regular)

    // MARK: - Large Values
    static let largeValue = Font.system(size: 20, weight: .regular)

    // MARK: - Section Label
    static let sectionLabel = Font.system(size: 16, weight: .semibold)
    static let sectionLabelKerning: CGFloat = 2

    // MARK: - Notes / Italic
    static let note = Font.system(size: 14, weight: .regular).italic()

    // MARK: - Tab Label
    static let tabLabel = Font.system(size: 18, weight: .regular)
    static let tabLabelKerning: CGFloat = 1
}
