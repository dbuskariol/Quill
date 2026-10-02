import Foundation

enum ArithmeticEvaluator {
    static func evaluate(_ expression: String) throws -> String {
        guard expression.count <= 1024 else { throw TemplateError.invalid("Arithmetic expression is too long.") }
        var parser = Parser(characters: Array(expression))
        let value = try parser.expression()
        parser.skipSpaces()
        guard parser.index == parser.characters.count, value.isFinite, abs(value) <= 1e15 else { throw TemplateError.invalid("Arithmetic expression is invalid or exceeds the numeric limit.") }
        return value.formatted(.number.locale(Locale(identifier: "en_US_POSIX")).grouping(.never).precision(.fractionLength(0...10)))
    }
    private struct Parser {
        let characters: [Character]
        var index = 0
        var depth = 0
        mutating func skipSpaces() { while index < characters.count && characters[index].isWhitespace { index += 1 } }
        mutating func consume(_ character: Character) -> Bool {
            skipSpaces()
            if index < characters.count && characters[index] == character { index += 1; return true }
            return false
        }
        mutating func expression() throws -> Double {
            var value = try term()
            while true {
                if consume("+") { value += try term() }
                else if consume("-") { value -= try term() }
                else { return value }
            }
        }
        mutating func term() throws -> Double {
            var value = try factor()
            while true {
                if consume("*") { value *= try factor() }
                else if consume("/") {
                    let divisor = try factor()
                    guard divisor != 0 else { throw TemplateError.invalid("Cannot divide by zero.") }
                    value /= divisor
                } else { return value }
            }
        }
        mutating func factor() throws -> Double {
            depth += 1
            defer { depth -= 1 }
            guard depth <= 32 else { throw TemplateError.invalid("Arithmetic nesting exceeds 32 levels.") }
            if consume("-") { return try -factor() }
            if consume("+") { return try factor() }
            if consume("(") {
                let value = try expression()
                guard consume(")") else { throw TemplateError.invalid("Close the arithmetic parenthesis.") }
                return value
            }
            skipSpaces()
            let start = index
            while index < characters.count && (characters[index].isASCII && characters[index].isNumber || characters[index] == ".") { index += 1 }
            guard index > start, let value = Double(String(characters[start..<index])), value.isFinite else { throw TemplateError.invalid("Arithmetic expects a number.") }
            return value
        }
    }
}
