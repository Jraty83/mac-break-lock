import Foundation

enum Persistence {
    private static var directoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = base.appendingPathComponent("BreakLock", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private static var stateURL: URL {
        directoryURL.appendingPathComponent("state.json")
    }

    static func load() -> BreakLockState {
        guard let data = try? Data(contentsOf: stateURL),
              let state = try? JSONDecoder().decode(BreakLockState.self, from: data) else {
            return .empty
        }
        return state
    }

    static func save(_ state: BreakLockState) {
        guard let data = try? JSONEncoder().encode(state) else { return }
        try? data.write(to: stateURL, options: [.atomic])
    }
}
