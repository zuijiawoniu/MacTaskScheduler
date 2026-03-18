import Foundation

enum LogStream {
    case system
    case stdout
    case stderr
}

struct LogChunk {
    let stream: LogStream
    let text: String
}

enum LogMarkup {
    private static let stdoutToken = "[[STDOUT]]"
    private static let stderrToken = "[[STDERR]]"

    static func encode(stream: LogStream, text: String) -> String {
        guard !text.isEmpty else { return "" }
        switch stream {
        case .system:
            return text
        case .stdout:
            return stdoutToken + text
        case .stderr:
            return stderrToken + text
        }
    }

    static func parse(_ text: String) -> [LogChunk] {
        guard !text.isEmpty else { return [] }

        var chunks: [LogChunk] = []
        var cursor = text.startIndex
        var currentStream: LogStream = .system

        while cursor < text.endIndex {
            let nextStdout = text.range(of: stdoutToken, range: cursor..<text.endIndex)
            let nextStderr = text.range(of: stderrToken, range: cursor..<text.endIndex)

            let nextTokenRange: Range<String.Index>?
            let tokenStream: LogStream

            if let out = nextStdout, let err = nextStderr {
                if out.lowerBound <= err.lowerBound {
                    nextTokenRange = out
                    tokenStream = .stdout
                } else {
                    nextTokenRange = err
                    tokenStream = .stderr
                }
            } else if let out = nextStdout {
                nextTokenRange = out
                tokenStream = .stdout
            } else if let err = nextStderr {
                nextTokenRange = err
                tokenStream = .stderr
            } else {
                nextTokenRange = nil
                tokenStream = currentStream
            }

            if let range = nextTokenRange {
                if cursor < range.lowerBound {
                    chunks.append(LogChunk(stream: currentStream, text: String(text[cursor..<range.lowerBound])))
                }
                currentStream = tokenStream
                cursor = range.upperBound
            } else {
                chunks.append(LogChunk(stream: currentStream, text: String(text[cursor..<text.endIndex])))
                break
            }
        }

        return chunks.filter { !$0.text.isEmpty }
    }
}
