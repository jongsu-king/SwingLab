import Foundation

/// Completes or rolls back a previously interrupted, explicitly requested deletion.
/// Database references decide which files survive; unrelated folders are untouched.
public enum MediaDeletionRecovery {
    public static func reconcile(library: URL, referencedNames: Set<String>, fileManager: FileManager = .default) throws {
        try fileManager.createDirectory(at: library, withIntermediateDirectories: true)
        let parent = library.deletingLastPathComponent()
        let prefix = library.lastPathComponent + ".deleted-"
        let folders = try fileManager.contentsOfDirectory(at: parent, includingPropertiesForKeys: nil).filter {
            $0.lastPathComponent.hasPrefix(prefix) && UUID(uuidString: String($0.lastPathComponent.dropFirst(prefix.count))) != nil
        }
        for folder in folders {
            for file in try fileManager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil) {
                let originalName = unstagedName(file.lastPathComponent) ?? file.lastPathComponent
                let destination = library.appendingPathComponent(originalName)
                if referencedNames.contains(originalName), !fileManager.fileExists(atPath: destination.path) {
                    try fileManager.moveItem(at: file, to: destination)
                }
            }
            try fileManager.removeItem(at: folder)
        }
        for file in try fileManager.contentsOfDirectory(at: library, includingPropertiesForKeys: nil) {
            guard let originalName = unstagedName(file.lastPathComponent) else { continue }
            let destination = library.appendingPathComponent(originalName)
            if referencedNames.contains(originalName), !fileManager.fileExists(atPath: destination.path) {
                try fileManager.moveItem(at: file, to: destination)
            } else { try fileManager.removeItem(at: file) }
        }
    }
    private static func unstagedName(_ name: String) -> String? {
        guard name.hasPrefix(".delete-") else { return nil }
        let tail = name.dropFirst(8)
        guard tail.count > 37, UUID(uuidString: String(tail.prefix(36))) != nil,
              tail.dropFirst(36).first == "-" else { return nil }
        return String(tail.dropFirst(37))
    }
}
