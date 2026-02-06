import SwiftUI
import UniformTypeIdentifiers

private enum FileDownloadExporterError: Error {
    case unsupported
}

public struct FileDownloadExportRequest: Identifiable, Equatable {
    public let id = UUID()
    public let url: URL
    public let defaultFilename: String
    public let contentType: UTType
    
    public init(url: URL, defaultFilename: String, contentType: UTType) {
        self.url = url
        self.defaultFilename = defaultFilename
        self.contentType = contentType
    }
}

public struct FileDownloadExporterModifier: ViewModifier {
    @Binding private var request: FileDownloadExportRequest?
    private let progressTitle: LocalizedStringKey
    private let cancelButtonTitle: LocalizedStringKey
    private let errorTitle: LocalizedStringKey
    private let onCompletion: (() -> Void)?
    
    public init(
        request: Binding<FileDownloadExportRequest?>,
        progressTitle: LocalizedStringKey,
        cancelButtonTitle: LocalizedStringKey,
        errorTitle: LocalizedStringKey,
        onCompletion: (() -> Void)?
    ) {
        self._request = request
        self.progressTitle = progressTitle
        self.cancelButtonTitle = cancelButtonTitle
        self.errorTitle = errorTitle
        self.onCompletion = onCompletion
    }
    
    public func body(content: Content) -> some View {
        content
            .sheet(item: $request) { item in
                FileDownloadExporterSheet(
                    request: item,
                    progressTitle: progressTitle,
                    cancelButtonTitle: cancelButtonTitle,
                    errorTitle: errorTitle
                ) {
                    request = nil
                    onCompletion?()
                }
            }
    }
}

public extension View {
    func fileDownloadExporter(
        request: Binding<FileDownloadExportRequest?>,
        progressTitle: LocalizedStringKey = "Preparing file…",
        cancelButtonTitle: LocalizedStringKey = "Cancel",
        errorTitle: LocalizedStringKey = "Unable to Save File",
        onCompletion: (() -> Void)? = nil
    ) -> some View {
        modifier(
            FileDownloadExporterModifier(
                request: request,
                progressTitle: progressTitle,
                cancelButtonTitle: cancelButtonTitle,
                errorTitle: errorTitle,
                onCompletion: onCompletion
            )
        )
    }
}

private struct FileDownloadExporterSheet: View {
    let request: FileDownloadExportRequest
    let progressTitle: LocalizedStringKey
    let cancelButtonTitle: LocalizedStringKey
    let errorTitle: LocalizedStringKey
    let onDismiss: () -> Void
    
    @State private var exporterDocument: TemporaryDownloadedFileDocument?
    @State private var downloadTask: Task<Void, Never>?
    @State private var isFileExporterPresented = false
    @State private var errorMessage: String?
    @State private var didComplete = false
    
    var body: some View {
        VStack(spacing: 16) {
            if let errorMessage {
                Label(errorTitle, systemImage: "exclamationmark.triangle")
                    .font(.headline)
                Text(errorMessage)
                    .font(.footnote)
                    .multilineTextAlignment(.center)
                    .foregroundColor(.secondary)
                Button(cancelButtonTitle) {
                    finishAndDismiss()
                }
            } else {
                ProgressView(progressTitle)
                    .controlSize(.small)
                Button(cancelButtonTitle) {
                    cancelAndDismiss()
                }
            }
        }
        .padding(24)
        .modifier {
#if os(iOS)
            if #available(iOS 16, *) {
                $0.presentationDetents([.fraction(0.25)])
            } else {
                $0
            }
#else
            $0
#endif
        }
        .interactiveDismissDisabled(true)
        .onAppear(perform: startDownloadIfNeeded)
        .onDisappear(perform: cleanupIfNeeded)
        .background(exporterBridge)
    }
    
    @ViewBuilder
    private var exporterBridge: some View {
        if let document = exporterDocument {
            Color.clear
                .fileExporter(
                    isPresented: $isFileExporterPresented,
                    document: document,
                    contentType: request.contentType,
                    defaultFilename: request.defaultFilename
                ) { _ in
                    finishAndDismiss()
                }
                .onChange(of: isFileExporterPresented) { presented in
                    if !presented {
                        finishAndDismiss()
                    }
                }
        }
    }
    
    private func startDownloadIfNeeded() {
        guard downloadTask == nil, exporterDocument == nil else { return }
        errorMessage = nil
        downloadTask = Task(priority: .userInitiated) {
            do {
                let document = try await TemporaryDownloadedFileDocument.prepare(for: request)
                try Task.checkCancellation()
                await MainActor.run {
                    exporterDocument = document
                    isFileExporterPresented = true
                }
            } catch is CancellationError {
                // No-op, cancellation handled elsewhere.
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                }
            }
            await MainActor.run {
                downloadTask = nil
            }
        }
    }
    
    private func cancelAndDismiss() {
        downloadTask?.cancel()
        finishAndDismiss()
    }
    
    private func finishAndDismiss() {
        guard !didComplete else { return }
        didComplete = true
        cleanupIfNeeded()
        onDismiss()
    }
    
    private func cleanupIfNeeded() {
        downloadTask?.cancel()
        downloadTask = nil
        exporterDocument?.cleanup()
        exporterDocument = nil
    }
}

private struct TemporaryDownloadedFileDocument: FileDocument {
    static var readableContentTypes: [UTType] { [] }
    static var writableContentTypes: [UTType] { [.data] }
    
    var fileURL: URL
    private let cleanupDirectoryURL: URL
    
    init(fileURL: URL, cleanupDirectoryURL: URL) {
        self.fileURL = fileURL
        self.cleanupDirectoryURL = cleanupDirectoryURL
    }
    
    init(configuration: ReadConfiguration) throws {
        throw FileDownloadExporterError.unsupported
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        try FileWrapper(url: fileURL, options: .immediate)
    }
    
    func cleanup() {
        try? FileManager.default.removeItem(at: cleanupDirectoryURL)
    }
    
    static func prepare(for request: FileDownloadExportRequest) async throws -> TemporaryDownloadedFileDocument {
        let (temporaryURL, _) = try await URLSession.shared.download(from: request.url)
        let workingDirectory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FileDownloadExporter-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: workingDirectory, withIntermediateDirectories: true)
        let destinationURL = workingDirectory.appendingPathComponent(request.defaultFilename)
        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destinationURL)
        return TemporaryDownloadedFileDocument(fileURL: destinationURL, cleanupDirectoryURL: workingDirectory)
    }
}
