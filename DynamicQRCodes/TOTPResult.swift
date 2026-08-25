import Foundation

struct TOTPResult: Equatable, Sendable {
    let previous: String
    let current: String
    let next: String
    let remainingTime: UInt64
}
