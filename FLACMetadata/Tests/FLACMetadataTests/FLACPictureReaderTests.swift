import XCTest
@testable import FLACMetadata

final class FLACPictureReaderTests: XCTestCase {
    /// 1x1 透明 PNG（テスト用の最小画像データ）。
    private static let onePixelPNG = Data(base64Encoded:
        "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNk+A8AAQUBAScY42YAAAAASUVORK5CYII="
    )!

    // MARK: - ヘルパー

    private func writeTempFile(_ data: Data) -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("flac")
        try! data.write(to: url)
        return url
    }

    private func uint32BE(_ value: UInt32) -> Data {
        Data([
            UInt8((value >> 24) & 0xFF),
            UInt8((value >> 16) & 0xFF),
            UInt8((value >> 8) & 0xFF),
            UInt8(value & 0xFF),
        ])
    }

    /// メタデータブロックヘッダ（4バイト）を組み立てる。
    private func blockHeader(isLast: Bool, type: UInt8, length: Int) -> Data {
        let flagAndType: UInt8 = (isLast ? 0x80 : 0x00) | (type & 0x7F)
        let lengthBytes = uint32BE(UInt32(length))
        // length は下位24bitのみ使用する。
        return Data([flagAndType]) + lengthBytes.suffix(3)
    }

    /// 最小の STREAMINFO ブロック本体（34バイト、内容は本パーサーでは未使用）。
    private func streamInfoBody() -> Data {
        Data(repeating: 0, count: 34)
    }

    /// PICTURE ブロック本体を組み立てる。
    private func pictureBody(
        pictureType: UInt32,
        mime: String,
        description: String,
        width: UInt32,
        height: UInt32,
        imageData: Data
    ) -> Data {
        var body = Data()
        body += uint32BE(pictureType)
        let mimeData = mime.data(using: .utf8)!
        body += uint32BE(UInt32(mimeData.count))
        body += mimeData
        let descData = description.data(using: .utf8)!
        body += uint32BE(UInt32(descData.count))
        body += descData
        body += uint32BE(width)
        body += uint32BE(height)
        body += uint32BE(0) // color depth
        body += uint32BE(0) // colors used
        body += uint32BE(UInt32(imageData.count))
        body += imageData
        return body
    }

    /// "fLaC" + STREAMINFO(非最終) + 指定 PICTURE ブロック(最終) から成る FLAC ファイルを組み立てる。
    private func makeFLAC(pictureBody: Data?) -> Data {
        var data = Data("fLaC".utf8)

        let streamInfo = streamInfoBody()
        data += blockHeader(isLast: pictureBody == nil, type: 0, length: streamInfo.count)
        data += streamInfo

        if let pictureBody {
            data += blockHeader(isLast: true, type: 6, length: pictureBody.count)
            data += pictureBody
        }

        return data
    }

    // MARK: - テスト

    /// 合成バイト列から PICTURE ブロックを正しく読み取れること。
    func testReadsPictureBlock() throws {
        let picBody = pictureBody(
            pictureType: 3,
            mime: "image/png",
            description: "cover",
            width: 1,
            height: 1,
            imageData: Self.onePixelPNG
        )
        let fileData = makeFLAC(pictureBody: picBody)
        let url = writeTempFile(fileData)
        defer { try? FileManager.default.removeItem(at: url) }

        let picture = try FLACPictureReader.picture(at: url)

        XCTAssertNotNil(picture)
        XCTAssertEqual(picture?.pictureType, 3)
        XCTAssertEqual(picture?.mimeType, "image/png")
        XCTAssertEqual(picture?.description, "cover")
        XCTAssertEqual(picture?.width, 1)
        XCTAssertEqual(picture?.height, 1)
        XCTAssertEqual(picture?.data, Self.onePixelPNG)
    }

    /// PICTURE ブロックが存在しない FLAC の場合、nil が返ること。
    func testReturnsNilWhenNoPictureBlock() throws {
        let fileData = makeFLAC(pictureBody: nil)
        let url = writeTempFile(fileData)
        defer { try? FileManager.default.removeItem(at: url) }

        let picture = try FLACPictureReader.picture(at: url)

        XCTAssertNil(picture)
    }

    /// マジックが "fLaC" でない場合、notFLAC エラーが投げられること。
    func testThrowsNotFLACForInvalidMagic() throws {
        let fileData = Data("XXXXinvalid data".utf8)
        let url = writeTempFile(fileData)
        defer { try? FileManager.default.removeItem(at: url) }

        XCTAssertThrowsError(try FLACPictureReader.picture(at: url)) { error in
            XCTAssertEqual(error as? FLACError, .notFLAC)
        }
    }

    /// 先頭に ID3v2 ヘッダが付与された FLAC でも、スキップして正しく読み取れること。
    func testSkipsID3v2Prefix() throws {
        let picBody = pictureBody(
            pictureType: 3,
            mime: "image/png",
            description: "",
            width: 1,
            height: 1,
            imageData: Self.onePixelPNG
        )
        let flacData = makeFLAC(pictureBody: picBody)

        // ID3v2 ヘッダ: "ID3" + バージョン(2) + フラグ(1) + syncsafe size(4) = 10バイト固定部。
        // タグ本体は付与せず、size=0 とする。
        var id3Header = Data("ID3".utf8)
        id3Header += Data([0x03, 0x00]) // version 2.3.0
        id3Header += Data([0x00]) // flags
        id3Header += Data([0x00, 0x00, 0x00, 0x00]) // syncsafe size = 0

        let fileData = id3Header + flacData
        let url = writeTempFile(fileData)
        defer { try? FileManager.default.removeItem(at: url) }

        let picture = try FLACPictureReader.picture(at: url)

        XCTAssertNotNil(picture)
        XCTAssertEqual(picture?.pictureType, 3)
        XCTAssertEqual(picture?.data, Self.onePixelPNG)
    }

    /// MIME が "-->" の PICTURE ブロックしかない場合、nil が返ること。
    func testReturnsNilForOnlyUrlReferences() throws {
        let picBody = pictureBody(
            pictureType: 3,
            mime: "-->",
            description: "",
            width: 0,
            height: 0,
            imageData: Data()
        )
        let fileData = makeFLAC(pictureBody: picBody)
        let url = writeTempFile(fileData)
        defer { try? FileManager.default.removeItem(at: url) }

        let picture = try FLACPictureReader.picture(at: url)

        XCTAssertNil(picture)
    }

    /// URL 参照ブロックを飛ばして後続の有効な PICTURE ブロックを取得できること。
    func testSkipsUrlReferenceAndFindsNextPicture() throws {
        let urlRefBody = pictureBody(
            pictureType: 3,
            mime: "-->",
            description: "",
            width: 0,
            height: 0,
            imageData: Data()
        )
        let validBody = pictureBody(
            pictureType: 0,
            mime: "image/png",
            description: "",
            width: 1,
            height: 1,
            imageData: Self.onePixelPNG
        )
        var data = Data("fLaC".utf8)
        let streamInfo = streamInfoBody()
        data += blockHeader(isLast: false, type: 0, length: streamInfo.count)
        data += streamInfo
        data += blockHeader(isLast: false, type: 6, length: urlRefBody.count)
        data += urlRefBody
        data += blockHeader(isLast: true, type: 6, length: validBody.count)
        data += validBody

        let url = writeTempFile(data)
        defer { try? FileManager.default.removeItem(at: url) }

        let picture = try FLACPictureReader.picture(at: url)

        XCTAssertNotNil(picture)
        XCTAssertEqual(picture?.mimeType, "image/png")
        XCTAssertEqual(picture?.data, Self.onePixelPNG)
    }
}
