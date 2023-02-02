import SwiftUI

public struct DownloadProgress: View {
    @ObservedObject var download: Downloadable
    let retryAction: (() -> Void)
    
    private var statusText: String {
        switch download.downloadProgress {
        case .downloading(let progress):
            return "\(progress.completedUnitCount) of \(progress.totalUnitCount)"
        case .waitingForResponse:
            return "Waiting for response from server..."
        case .completed(let destinationLocation, let error):
            if let error = error {
                return "Error: \(error.localizedDescription)"
            } else if destinationLocation != nil {
                if download.isFinishedProcessing {
                    return "Finished"
                } else {
                    return "Installing..."
                }
            }
        default:
            break
        }
        return ""
    }
    
    private var isFailed: Bool {
        switch download.downloadProgress {
        case .completed(_, let urlError):
            return urlError != nil
        default:
            return false
        }
    }
    
    private var fractionCompleted: Double {
        switch download.downloadProgress {
        case .downloading(let progress):
            return progress.fractionCompleted
        case .completed(let destinationLocation, let error):
            return destinationLocation != nil && error == nil ? 1.0 : 0
        default:
            return 0
        }
    }
    
    public var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if download.isFinishedProcessing {
                Image(systemName: "checkmark.circle")
                    .foregroundColor(.green)
            } else {
                if isFailed {
                    Image(systemName: "exclamationmark.circle")
                        .foregroundColor(.red)
                } else {
                    ProgressView()
                        .progressViewStyle(.circular)
                        .scaleEffect(1.0, anchor: .center)
                }
            }
            VStack(alignment: .leading) {
                Text("Downloading \(download.name)")
                ProgressView(value: fractionCompleted)
                    .progressViewStyle(.linear)
                    .frame(height: 5)
                    .clipShape(Capsule())
                Text(statusText)
                    .font(.callout)
                    .foregroundColor(isFailed ? .red : .secondary)
            }
            .font(.callout)
            if isFailed {
                Button("Retry") {
                    retryAction()
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }
    
    public init(download: Downloadable, retryAction: @escaping (() -> Void)) {
        self.download = download
        self.retryAction = retryAction
    }
}

public struct ActiveDownloadsList: View {
    public var body: some View {
        ScrollView {
            LazyVStack {
                ForEach(DownloadController.shared.unfinishedDownloads) { download in
                    DownloadProgress(download: download, retryAction: {
                        DownloadController.shared.ensureDownloaded([download])
                    })
                    .padding(.horizontal, 6)
                    Divider()
                        .padding(.horizontal, 6)
                }
            }
        }
    }
    
    public init() {
    }
}
