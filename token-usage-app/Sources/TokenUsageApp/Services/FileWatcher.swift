import Foundation

final class FileWatcher {
    private let url: URL
    private let queue = DispatchQueue(label: "com.tokenusage.filewatcher", qos: .utility)

    nonisolated(unsafe) private var fileHandle: FileHandle?
    nonisolated(unsafe) private var source: DispatchSourceFileSystemObject?

    var onNewData: @Sendable (Data) -> Void = { _ in }

    init(url: URL) {
        self.url = url
    }

    func start() -> Data {
        guard let fh = try? FileHandle(forReadingFrom: url) else { return Data() }
        fileHandle = fh
        let initial = fh.readDataToEndOfFile()

        let watchFD = open(url.path, O_EVTONLY)
        guard watchFD >= 0 else { return initial }

        let src = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: watchFD,
            eventMask: .extend,
            queue: queue
        )

        src.setEventHandler { [weak self] in
            guard let self else { return }
            let newData = self.fileHandle?.readDataToEndOfFile() ?? Data()
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
