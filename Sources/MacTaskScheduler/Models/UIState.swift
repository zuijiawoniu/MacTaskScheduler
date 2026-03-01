import Foundation
import Combine

@MainActor
final class UIState: ObservableObject {
    @Published var showHelp = false
}
