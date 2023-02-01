import SwiftUI

struct DownloadProgress: View {
    @ObservedObject var download: Downloadable
    let retryAction: (() -> Void)
    
    private var statusText: String {
        switch download.downloadProgress {
        case .downloading(let progress):
            return "\(progress.completedUnitCount) of \(progress.totalUnitCount)"
        case .waitingForResponse:
            return "Waiting for response from server..."
        case .completed(let destinationLocation, let urlError):
            if let urlError = urlError {
                return "Error: \(urlError.localizedDescription)"
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
        default:
            return 0
        }
    }
    
    var body: some View {
        HStack {
            if download.isFinishedProcessing {
                
            } else {
                ProgressView()
                    .progressViewStyle(.circular)
            }
            VStack {
                Text("Downloading \(download.name)")
                ProgressView(value: fractionCompleted)
                    .progressViewStyle(.linear)
                    .frame(height: 5)
                    .clipShape(Capsule())
                Text(statusText)
                    .font(.callout)
                    .foregroundColor(isFailed ? .red : .secondary)
            }
            if isFailed {
                Button("Retry") {
                    retryAction()
                }
                .buttonStyle(.borderedProminent)
            }
        }
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
                }
            }
        }
    }
    
    public init() {
    }
}
