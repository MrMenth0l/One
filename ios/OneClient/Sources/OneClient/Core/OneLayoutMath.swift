import CoreGraphics

enum OneLayoutMath {
    static func nonNegative(_ value: CGFloat) -> CGFloat {
        guard value.isFinite else {
            return 0
        }
        return max(0, value)
    }

    static func unitInterval(_ value: Double) -> Double {
        guard value.isFinite else {
            return 0
        }
        return min(max(value, 0), 1)
    }

    static func unitInterval(_ value: CGFloat) -> CGFloat {
        guard value.isFinite else {
            return 0
        }
        return min(max(value, 0), 1)
    }

    static func filledWidth(
        containerWidth: CGFloat,
        fraction: Double,
        minimumWhenVisible: CGFloat = 0
    ) -> CGFloat {
        let safeFraction = unitInterval(fraction)
        let resolvedWidth = nonNegative(containerWidth) * CGFloat(safeFraction)
        return max(resolvedWidth, safeFraction > 0 ? minimumWhenVisible : 0)
    }

    static func filledWidth(
        containerWidth: CGFloat,
        fraction: CGFloat,
        minimumWhenVisible: CGFloat = 0
    ) -> CGFloat {
        let safeFraction = unitInterval(fraction)
        let resolvedWidth = nonNegative(containerWidth) * safeFraction
        return max(resolvedWidth, safeFraction > 0 ? minimumWhenVisible : 0)
    }

    static func percent(_ value: Double) -> Int {
        Int((unitInterval(value) * 100).rounded())
    }

    static func percent(_ value: CGFloat) -> Int {
        Int((unitInterval(value) * 100).rounded())
    }
}
