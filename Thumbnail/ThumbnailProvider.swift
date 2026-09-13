import QuickLookThumbnailing
import FLACMetadata
import os

private let logger = Logger(subsystem: "io.github.geniusjunp.flaccoverql.thumbnail", category: "provider")

final class ThumbnailProvider: QLThumbnailProvider {
    override func provideThumbnail(
        for request: QLFileThumbnailRequest,
        _ handler: @escaping (QLThumbnailReply?, (any Error)?) -> Void
    ) {
        do {
            guard let picture = try FLACPictureReader.picture(at: request.fileURL) else {
                handler(nil, nil)
                return
            }

            let tempURL = FileManager.default.temporaryDirectory
                .appendingPathComponent(UUID().uuidString)
                .appendingPathExtension(picture.fileExtension)
            try picture.data.write(to: tempURL)

            handler(QLThumbnailReply(imageFileURL: tempURL), nil)
        } catch {
            logger.error("\(error.localizedDescription, privacy: .public)")
            handler(nil, error)
        }
    }
}
