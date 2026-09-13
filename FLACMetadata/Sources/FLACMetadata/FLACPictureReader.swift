import Foundation

/// FLAC ファイルからカバーアート画像（PICTURE ブロック）を抽出するパーサー。
///
/// ファイル全体を Data にロードせず、FileHandle による seek/read のみで
/// 必要な範囲（ブロックヘッダおよび PICTURE ブロック本体）だけを読み取る。
public enum FLACPictureReader {
    /// FLAC の識別マジックバイト列 "fLaC"。
    private static let magic: [UInt8] = [0x66, 0x4C, 0x61, 0x43]

    /// FLAC ファイルからカバーアート画像を抽出する。
    /// pictureType 3（フロントカバー）を優先し、なければ最初に見つかった PICTURE ブロックを返す。
    /// PICTURE ブロックが存在しない場合は nil を返す。
    public static func picture(at url: URL) throws -> FLACPicture? {
        let handle = try FileHandle(forReadingFrom: url)
        defer { try? handle.close() }

        var cursor = try resolveDataOffset(handle)
        var firstPicture: FLACPicture?

        while true {
            let header = try readBytes(handle, at: cursor, count: 4)
            guard header.count == 4 else { throw FLACError.truncatedBlock }
            cursor += 4

            let isLast = (header[header.startIndex] & 0x80) != 0
            let blockType = header[header.startIndex] & 0x7F
            let length = (UInt32(header[header.startIndex + 1]) << 16)
                | (UInt32(header[header.startIndex + 2]) << 8)
                | UInt32(header[header.startIndex + 3])

            if blockType == 6 {
                let body = try readBytes(handle, at: cursor, count: Int(length))
                guard body.count == Int(length) else { throw FLACError.truncatedBlock }
                if let picture = try parsePicture(body) {
                    if picture.pictureType == 3 {
                        return picture
                    }
                    if firstPicture == nil {
                        firstPicture = picture
                    }
                }
            }

            cursor += UInt64(length)
            if isLast { break }
        }

        return firstPicture
    }

    /// マジック直後の読み取り開始オフセットを求める。
    /// 先頭に ID3v2 ヘッダが付与されている場合は、そのサイズ分をスキップしてから
    /// 改めて "fLaC" マジックの検証を行う（RFC 9639 が推奨するデコーダ挙動）。
    private static func resolveDataOffset(_ handle: FileHandle) throws -> UInt64 {
        // ID3v2 ヘッダは 10 バイトあるため、最初から 10 バイト読み取って判定する。
        let head = try readBytes(handle, at: 0, count: 10)
        guard head.count >= 4 else { throw FLACError.notFLAC }

        if Array(head[head.startIndex..<head.startIndex + 4]) == magic {
            return 4
        }

        guard head.count >= 10,
              head[head.startIndex] == 0x49,     // 'I'
              head[head.startIndex + 1] == 0x44, // 'D'
              head[head.startIndex + 2] == 0x33  // '3'
        else {
            throw FLACError.notFLAC
        }

        // バイト 6-9 の syncsafe integer から ID3v2 タグ全体のサイズを算出する。
        let tagSize = (UInt32(head[head.startIndex + 6] & 0x7F) << 21)
            | (UInt32(head[head.startIndex + 7] & 0x7F) << 14)
            | (UInt32(head[head.startIndex + 8] & 0x7F) << 7)
            | UInt32(head[head.startIndex + 9] & 0x7F)
        let skipped = UInt64(10) + UInt64(tagSize)

        let magicAfterID3 = try readBytes(handle, at: skipped, count: 4)
        guard magicAfterID3.count == 4, Array(magicAfterID3) == magic else {
            throw FLACError.notFLAC
        }
        return skipped + 4
    }

    /// PICTURE ブロック本体（RFC 9639 準拠のフィールド列）を解析する。
    /// MIME が "-->"（URL 参照）の場合は画像データを含まないため nil を返す。
    private static func parsePicture(_ body: Data) throws -> FLACPicture? {
        var cursor = body.startIndex

        func readUInt32() throws -> UInt32 {
            guard body.distance(from: cursor, to: body.endIndex) >= 4 else {
                throw FLACError.truncatedBlock
            }
            let value = (UInt32(body[cursor]) << 24)
                | (UInt32(body[cursor + 1]) << 16)
                | (UInt32(body[cursor + 2]) << 8)
                | UInt32(body[cursor + 3])
            cursor += 4
            return value
        }

        func readString(length: Int) throws -> String {
            guard body.distance(from: cursor, to: body.endIndex) >= length else {
                throw FLACError.truncatedBlock
            }
            let range = cursor..<(cursor + length)
            let substring = body.subdata(in: range)
            cursor += length
            guard let string = String(data: substring, encoding: .utf8) else {
                throw FLACError.truncatedBlock
            }
            return string
        }

        let pictureType = try readUInt32()
        let mimeLength = try readUInt32()
        let mimeType = try readString(length: Int(mimeLength))
        if mimeType == "-->" {
            return nil
        }
        let descriptionLength = try readUInt32()
        let description = try readString(length: Int(descriptionLength))
        let width = try readUInt32()
        let height = try readUInt32()
        _ = try readUInt32() // color depth（本パーサーでは未使用）
        _ = try readUInt32() // colors used（インデックスカラー時のパレット数、本パーサーでは未使用）
        let imageDataLength = try readUInt32()

        guard body.distance(from: cursor, to: body.endIndex) >= Int(imageDataLength) else {
            throw FLACError.truncatedBlock
        }
        let imageData = body.subdata(in: cursor..<(cursor + Int(imageDataLength)))

        return FLACPicture(
            pictureType: pictureType,
            mimeType: mimeType,
            description: description,
            width: width,
            height: height,
            data: imageData
        )
    }

    /// 指定オフセットから count バイトを読み取る。ファイル末尾に達した場合は実際に読めた分だけ返す。
    private static func readBytes(_ handle: FileHandle, at offset: UInt64, count: Int) throws -> Data {
        try handle.seek(toOffset: offset)
        return try handle.read(upToCount: count) ?? Data()
    }
}
