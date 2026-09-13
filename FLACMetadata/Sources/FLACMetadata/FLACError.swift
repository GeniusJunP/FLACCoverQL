import Foundation

/// FLAC メタデータ解析時に発生するエラー種別。
public enum FLACError: Error, Sendable, Equatable {
    /// 先頭に "fLaC" マジックが存在しない。
    case notFLAC
    /// メタデータブロックがファイル末尾で途中切断されている。
    case truncatedBlock
}
