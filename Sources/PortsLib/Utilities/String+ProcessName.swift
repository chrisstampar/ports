import Foundation

extension String {
    /// Replaces escape sequences like `\x20` (space) with the actual character so process names from lsof display correctly.
    public var sanitizedProcessName: String {
        var result = ""
        var i = startIndex
        while i < endIndex {
            if self[i] == "\\", index(after: i) < endIndex {
                let next = index(after: i)
                if self[next] == "x", index(next, offsetBy: 2) <= endIndex {
                    let hexStart = index(after: next)
                    let hexEnd = index(hexStart, offsetBy: 2)
                    let hex = self[hexStart..<hexEnd]
                    if let code = UInt8(hex, radix: 16) {
                        result.append(Character(Unicode.Scalar(code)))
                        i = hexEnd
                        continue
                    }
                }
            }
            result.append(self[i])
            i = index(after: i)
        }
        return result
    }
}
