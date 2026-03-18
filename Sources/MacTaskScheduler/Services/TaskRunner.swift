import Foundation

struct TaskRunResult {
    let exitCode: Int32
    let output: String
    let finishedAt: Date
}

struct TaskOutputChunk {
    let stream: LogStream
    let text: String
}

private final class TimeoutState: @unchecked Sendable {
    private let queue = DispatchQueue(label: "TaskRunner.TimeoutState")
    private var timedOut = false

    func setTimedOut() {
        queue.sync { timedOut = true }
    }

    func isTimedOut() -> Bool {
        queue.sync { timedOut }
    }
}

private final class OutputBuffer: @unchecked Sendable {
    private let queue = DispatchQueue(label: "TaskRunner.OutputBuffer")
    private var storage = ""

    func append(_ text: String) {
        queue.sync {
            storage += text
        }
    }

    func snapshot() -> String {
        queue.sync { storage }
    }
}

enum TaskRunner {
    static func run(
        task: TaskItem,
        onOutput: @Sendable @escaping (TaskOutputChunk) -> Void = { _ in },
        completion: @Sendable @escaping (TaskRunResult) -> Void
    ) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()
            let outputBuffer = OutputBuffer()
            let timeoutState = TimeoutState()

            let appendChunk: @Sendable (LogStream, String) -> Void = { stream, text in
                guard !text.isEmpty else { return }
                outputBuffer.append(LogMarkup.encode(stream: stream, text: text))
                onOutput(TaskOutputChunk(stream: stream, text: text))
            }

            let consume: @Sendable (FileHandle, LogStream) -> Void = { handle, stream in
                let data = handle.availableData
                guard !data.isEmpty else { return }
                let text = String(data: data, encoding: .utf8) ?? String(decoding: data, as: UTF8.self)
                appendChunk(stream, text)
            }

            let isAppBundle = task.scriptPath.lowercased().hasSuffix(".app")
            let executable = FileManager.default.isExecutableFile(atPath: task.scriptPath)

            if isAppBundle {
                process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
                var args = ["-a", task.scriptPath]

                let rawArgs = task.argumentArray
                let opensAsTarget = rawArgs.allSatisfy { value in
                    value.contains("://") || value.hasPrefix("/") || value.hasPrefix("~")
                }

                if !rawArgs.isEmpty {
                    if opensAsTarget {
                        // URL/file targets should be passed directly to `open`, not via `--args`.
                        args.append(contentsOf: rawArgs)
                    } else {
                        args.append("--args")
                        args.append(contentsOf: rawArgs)
                    }
                }
                process.arguments = args
            } else if executable {
                process.executableURL = URL(fileURLWithPath: task.scriptPath)
                process.arguments = task.argumentArray
            } else {
                process.executableURL = URL(fileURLWithPath: "/bin/zsh")
                var args = [task.scriptPath]
                args.append(contentsOf: task.argumentArray)
                process.arguments = args
            }

            if !task.workingDirectory.isEmpty {
                process.currentDirectoryURL = URL(fileURLWithPath: task.workingDirectory)
            }

            process.standardOutput = outputPipe
            process.standardError = errorPipe
            outputPipe.fileHandleForReading.readabilityHandler = { handle in
                consume(handle, .stdout)
            }
            errorPipe.fileHandleForReading.readabilityHandler = { handle in
                consume(handle, .stderr)
            }

            do {
                try process.run()
                let timeoutSeconds = max(1, task.timeoutSeconds)
                let timeoutWork = DispatchWorkItem {
                    guard process.isRunning else { return }
                    timeoutState.setTimedOut()
                    appendChunk(.system, "[TaskRunner] Execution timed out after \(timeoutSeconds)s. Terminating process...\n")
                    process.terminate()
                    DispatchQueue.global().asyncAfter(deadline: .now() + 2) {
                        if process.isRunning {
                            process.interrupt()
                        }
                    }
                }
                DispatchQueue.global().asyncAfter(deadline: .now() + .seconds(timeoutSeconds), execute: timeoutWork)
                process.waitUntilExit()
                timeoutWork.cancel()

                outputPipe.fileHandleForReading.readabilityHandler = nil
                errorPipe.fileHandleForReading.readabilityHandler = nil

                let tailStdout = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let tailStderr = errorPipe.fileHandleForReading.readDataToEndOfFile()
                if !tailStdout.isEmpty {
                    let text = String(data: tailStdout, encoding: .utf8) ?? String(decoding: tailStdout, as: UTF8.self)
                    appendChunk(.stdout, text)
                }
                if !tailStderr.isEmpty {
                    let text = String(data: tailStderr, encoding: .utf8) ?? String(decoding: tailStderr, as: UTF8.self)
                    appendChunk(.stderr, text)
                }

                let combined = outputBuffer.snapshot()
                let exitCode = timeoutState.isTimedOut() ? 124 : process.terminationStatus

                completion(TaskRunResult(exitCode: exitCode, output: combined, finishedAt: Date()))
            } catch {
                completion(TaskRunResult(exitCode: -1, output: "Execution failed: \(error.localizedDescription)", finishedAt: Date()))
            }
        }
    }
}
