//
//  MapZoomPolicy.swift
//  BorrowBuddy
//
//  Created by Dilmani Balalla on 2026-10-19.
//

import Foundation

enum MapZoomPolicy {
    static let minimumDistance = 100.0
    static let maximumDistance = 20_000_000.0

    static func distance(from current: Double, zoomingIn: Bool) -> Double {
        let validDistance = current.isFinite && current > 0 ? current : 5_000
        let scaled = validDistance * (zoomingIn ? 0.5 : 2)
        return min(maximumDistance, max(minimumDistance, scaled))
    }
}
