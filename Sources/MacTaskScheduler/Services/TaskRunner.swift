import Foundation

struct TaskRunResult {
    let exitCode: Int32
    let output: String
}

enum TaskRunner {
    static func run(task: TaskItem, completion: @escaping (TaskRunResult) -> Void) {
        DispatchQueue.global(qos: .userInitiated).async {
            let process = Process()
            let outputPipe = Pipe()
            let errorPipe = Pipe()

            let executable = FileManager.default.isExecutableFile(atPath: task.scriptPath)
            if executable {
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

            do {
                try process.run()
                process.waitUntilExit()

                let stdout = String(data: outputPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
                let stderr = String(data: errorPipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""

                let combined = [stdout, stderr]
                    .filter { !$0.isEmpty }
                    .joined(separator: "\n")

                completion(TaskRunResult(exitCode: process.terminationStatus, output: combined))
            } catch {
                completion(TaskRunResult(exitCode: -1, output: "Execution failed: \(error.localizedDescription)"))
            }
        }
    }
}
