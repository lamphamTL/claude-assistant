import Foundation

final class FileWatcher {
    private let url: URL
    private let queue = DispatchQueue(label: "com.tokenusage.filewatcher", qos: .utility)

    nonisolated(unsafe) private var fileHandle: FileHandle?
    nonisolated(unsafe) private var source: DispatchSourceFileSystemObject?
    nonisolated(unsafe) private var lastOffset: UInt64 = 0

    var onNewData: @Sendable (Data) -> Void = { _ in }
    var onReload:  @Sendable (Data) -> Void = { _ in }

    init(url: URL) {
        self.url = url
    }

    func start() -> Data {
        return openAndArm()
    }

    @discardableResult
    private func openAndArm() -> Data {
        source?.cancel()
        source = nil
        fileHandle?.closeFile()
        fileHandle = nil

        guard let fh = try? FileHandle(forReadingFrom: url) else { return Data() }
        fileHandle = fh
        let initial = fh.readDataToEndOfFile()
        lastOffset = fh.offsetInFile

        let watchFD = open(url.path, O_EVTONLY)
        guard watchFD >= 0 else { return initial }

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: watchFD,
            eventMask: [.write, .extend, .attrib, .link, .rename, .delete, .revoke],
            queue: queue
        )

        src.setEventHandler { [weak self, weak src] in
            guard let self, let src else { return }
            let flags = src.data

            if flags.contains(.delete) || flags.contains(.rename) || flags.contains(.revoke) {
                // File replaced/removed — common for editor atomic saves. Reopen by path.
                self.queue.asyncAfter(deadline: .now() + 0.1) {
                    let full = self.openAndArm()
                    let cb = self.onReload
                    DispatchQueue.main.async { cb(full) }
                }
                return
            }

            let currentSize = (try? FileManager.default.attributesOfItem(atPath: self.url.path)[.size] as? NSNumber)?.uint64Value ?? 0
            if currentSize < self.lastOffset {
                // Truncated or shrunk in place — re-read whole file.
                let full = self.openAndArm()
                let cb = self.onReload
                DispatchQueue.main.async { cb(full) }
                return
            }

            let newData = self.fileHandle?.readDataToEndOfFile() ?? Data()
            self.lastOffset = self.fileHandle?.offsetInFile ?? self.lastOffset
            guard !newData.isEmpty else { return }
            let cb = self.onNewData
            DispatchQueue.main.async { cb(newData) }
        }

        src.setCancelHandler { close(watchFD) }
        src.resume()
        source = src
        return initial
    }

    func stop() {
        source?.cancel()
        source = nil
        fileHandle?.closeFile()
        fileHandle = nil
    }

    deinit { stop() }
}
