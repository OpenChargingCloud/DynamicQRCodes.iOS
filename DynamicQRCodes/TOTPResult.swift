import Foundation

struct TOTPResult {
    let previous:      String
    let current:       String
    let next:          String
    let remainingTime: UInt64
}
