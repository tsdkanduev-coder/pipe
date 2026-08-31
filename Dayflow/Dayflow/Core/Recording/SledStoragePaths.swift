import Foundation

enum SledStoragePaths {
  static let applicationSupportDirectoryName = SledIdentity.applicationSupportDirectoryName
  static let databaseFileName = SledIdentity.databaseFileName
  static let legacyApplicationSupportDirectoryName = "Dayflow"
  static let legacyDatabaseFileName = "chunks.sqlite"
  static let dayflowToSledMigrationFlagKey = "didMigrateDayflowStoreToSled"

  static func applicationSupportDirectory(
    fileManager: FileManager = .default
  ) -> URL {
    let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    return appSupport.appendingPathComponent(applicationSupportDirectoryName, isDirectory: true)
  }

  static func databaseURL(fileManager: FileManager = .default) -> URL {
    applicationSupportDirectory(fileManager: fileManager)
      .appendingPathComponent(databaseFileName)
  }

  static func recordingsDirectory(fileManager: FileManager = .default) -> URL {
    applicationSupportDirectory(fileManager: fileManager)
      .appendingPathComponent("recordings", isDirectory: true)
  }

  static func backupsDirectory(fileManager: FileManager = .default) -> URL {
    applicationSupportDirectory(fileManager: fileManager)
      .appendingPathComponent("backups", isDirectory: true)
  }

  static func timelapsesDirectory(fileManager: FileManager = .default) -> URL {
    applicationSupportDirectory(fileManager: fileManager)
      .appendingPathComponent("timelapses", isDirectory: true)
  }

  static func legacyApplicationSupportDirectory(
    fileManager: FileManager = .default
  ) -> URL {
    let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    return appSupport.appendingPathComponent(
      legacyApplicationSupportDirectoryName, isDirectory: true)
  }

  /// One-time path shift from Dayflow's Application Support tree into Sled.
  /// Reuses the same files; does not create a second database engine.
  @discardableResult
  static func migrateDayflowStoreIfNeeded(
    fileManager: FileManager = .default,
    defaults: UserDefaults = .standard
  ) -> Bool {
    if defaults.bool(forKey: dayflowToSledMigrationFlagKey) {
      renameLegacyDatabaseIfNeeded(in: applicationSupportDirectory(fileManager: fileManager), fileManager: fileManager)
      return false
    }

    let destination = applicationSupportDirectory(fileManager: fileManager)
    let source = legacyApplicationSupportDirectory(fileManager: fileManager)
    try? fileManager.createDirectory(at: destination, withIntermediateDirectories: true)

    if fileManager.fileExists(atPath: source.path),
      source.standardizedFileURL.path != destination.standardizedFileURL.path
    {
      relocateDirectoryContents(from: source, to: destination, fileManager: fileManager)
    }

    renameLegacyDatabaseIfNeeded(in: destination, fileManager: fileManager)
    defaults.set(true, forKey: dayflowToSledMigrationFlagKey)
    return true
  }

  static func renameLegacyDatabaseIfNeeded(
    in directory: URL,
    fileManager: FileManager = .default
  ) {
    let legacyNames = [
      legacyDatabaseFileName,
      "\(legacyDatabaseFileName)-wal",
      "\(legacyDatabaseFileName)-shm",
    ]
    for legacyName in legacyNames {
      let suffix = String(legacyName.dropFirst(legacyDatabaseFileName.count))
      let destinationName = databaseFileName + suffix
      let from = directory.appendingPathComponent(legacyName)
      let to = directory.appendingPathComponent(destinationName)
      guard fileManager.fileExists(atPath: from.path) else { continue }
      if fileManager.fileExists(atPath: to.path) {
        try? fileManager.removeItem(at: from)
        continue
      }
      try? fileManager.moveItem(at: from, to: to)
    }
  }

  private static func relocateDirectoryContents(
    from source: URL,
    to destination: URL,
    fileManager: FileManager
  ) {
    guard
      let contents = try? fileManager.contentsOfDirectory(
        at: source,
        includingPropertiesForKeys: [.isDirectoryKey],
        options: [.skipsHiddenFiles]
      )
    else { return }

    for item in contents {
      let target = destination.appendingPathComponent(item.lastPathComponent)
      let isDirectory =
        (try? item.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) ?? false
      if isDirectory {
        try? fileManager.createDirectory(at: target, withIntermediateDirectories: true)
        relocateDirectoryContents(from: item, to: target, fileManager: fileManager)
        try? fileManager.removeItem(at: item)
        continue
      }
      if fileManager.fileExists(atPath: target.path) {
        try? fileManager.removeItem(at: item)
      } else {
        try? fileManager.moveItem(at: item, to: target)
      }
    }
    try? fileManager.removeItem(at: source)
  }
}
