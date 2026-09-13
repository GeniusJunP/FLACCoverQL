import Foundation

/// FLAC PICTURE ブロックから抽出した画像情報。
public struct FLACPicture: Sendable {
    /// RFC 9639 が定める画像種別（3 = フロントカバー）。
    public let pictureType: UInt32
    /// 画像の MIME タイプ文字列。
    public let mimeType: String
    /// 画像の説明文字列。
    public let description: String
    /// 画像の幅（ピクセル）。
    public let width: UInt32
    /// 画像の高さ（ピクセル）。
    public let height: UInt32
    /// 画像本体の生バイナリデータ。
    public let data: Data

    /// MIME タイプに対応するファイル拡張子。
    public var fileExtension: String {
        switch mimeType {
        case "image/jpeg": "jpg"
        case "image/png": "png"
        case "image/gif": "gif"
        case "image/webp": "webp"
        default: "bin"
        }
    }

    public init(
        pictureType: UInt32,
        mimeType: String,
        description: String,
        width: UInt32,
        height: UInt32,
        data: Data
    ) {
        self.pictureType = pictureType
        self.mimeType = mimeType
        self.description = description
        self.width = width
        self.height = height
        self.data = data
    }
}
