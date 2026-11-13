import Foundation
import CryptoKit
import Security
import UIKit
import ImageIO

enum VaultError: LocalizedError {
    case keychain(OSStatus)
    case sealFailed
    case badImage

    var errorDescription: String? {
        switch self {
        case .keychain(let s): "Keychain error (\(s))"
        case .sealFailed: "Could not encrypt the file"
        case .badImage: "The image could not be read"
        }
    }
}

/// Stores document images encrypted with AES-GCM (256-bit).
/// The key lives in the Keychain, readable only while the device is unlocked and never synced or backed up.
final class SecureStore: @unchecked Sendable {
    static let shared = SecureStore()

    private let lock = NSLock()
    private var cachedKey: SymmetricKey?
    private let service = "app.folio.vault"
    private let account = "master-key"
    let directory: URL

    init(directory: URL? = nil) {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        var dir = directory ?? base.appendingPathComponent("Vault", isDirectory: true)
        try? FileManager.default.createDirectory(
            at: dir,
            withIntermediateDirectories: true,
            attributes: [.protectionKey: FileProtectionType.complete]
        )
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? dir.setResourceValues(values)
        self.directory = dir
    }

    // MARK: Crypto (pure, testable)

    static func seal(_ data: Data, key: SymmetricKey) throws -> Data {
        guard let combined = try AES.GCM.seal(data, using: key).combined else { throw VaultError.sealFailed }
        return combined
    }

    static func open(_ data: Data, key: SymmetricKey) throws -> Data {
        try AES.GCM.open(AES.GCM.SealedBox(combined: data), using: key)
    }

    // MARK: Files

    @discardableResult
    func save(_ data: Data) throws -> String {
        let id = UUID().uuidString
        let sealed = try Self.seal(data, key: key())
        try sealed.write(to: url(for: id), options: [.atomic, .completeFileProtection])
        return id
    }

    /// Re-encodes the image as JPEG (max 2400 px) and stores it encrypted.
    func saveImage(_ image: UIImage) throws -> String {
        let resized = image.resizedToFit(maxPixel: 2400)
        guard let data = resized.jpegData(compressionQuality: 0.85) else { throw VaultError.badImage }
        return try save(data)
    }

    func load(_ id: String) throws -> Data {
        try Self.open(Data(contentsOf: url(for: id)), key: key())
    }

    func delete(_ id: String?) {
        guard let id else { return }
        try? FileManager.default.removeItem(at: url(for: id))
    }

    private func url(for id: String) -> URL {
        directory.appendingPathComponent(id).appendingPathExtension("vault")
    }

    // MARK: Key management

    func key() throws -> SymmetricKey {
        lock.lock()
        defer { lock.unlock() }
        if let cachedKey { return cachedKey }
        if let data = try readKey() {
            let k = SymmetricKey(data: data)
            cachedKey = k
            return k
        }
        let k = SymmetricKey(size: .bits256)
        try writeKey(k.withUnsafeBytes { Data($0) })
        cachedKey = k
        return k
    }

    private func readKey() throws -> Data? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]
        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)
        if status == errSecItemNotFound { return nil }
        guard status == errSecSuccess else { throw VaultError.keychain(status) }
        return item as? Data
    }

    private func writeKey(_ data: Data) throws {
        let attributes: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
            kSecValueData as String: data,
            kSecAttrAccessible as String: kSecAttrAccessibleWhenUnlockedThisDeviceOnly,
        ]
        let status = SecItemAdd(attributes as CFDictionary, nil)
        guard status == errSecSuccess else { throw VaultError.keychain(status) }
    }
}

// MARK: - Decrypted image loading with a small in-memory cache

enum ImageLoader {
    private static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.countLimit = 60
        return c
    }()

    static func image(_ id: String?, maxPixel: CGFloat = 1000) async -> UIImage? {
        guard let id else { return nil }
        let key = "\(id)-\(Int(maxPixel))" as NSString
        if let hit = cache.object(forKey: key) { return hit }
        let result: UIImage? = await Task.detached(priority: .userInitiated) {
            guard let data = try? SecureStore.shared.load(id) else { return nil }
            return downsample(data, maxPixel: maxPixel)
        }.value
        if let result { cache.setObject(result, forKey: key) }
        return result
    }

    static func evict(_ id: String?) {
        guard let id else { return }
        for size in [600, 1000, 2400] { cache.removeObject(forKey: "\(id)-\(size)" as NSString) }
    }

    static func downsample(_ data: Data, maxPixel: CGFloat) -> UIImage? {
        let options = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithData(data as CFData, options) else { return nil }
        let thumbOptions = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ] as [CFString: Any] as CFDictionary
        guard let cg = CGImageSourceCreateThumbnailAtIndex(source, 0, thumbOptions) else { return nil }
        return UIImage(cgImage: cg)
    }
}

extension UIImage {
    func resizedToFit(maxPixel: CGFloat) -> UIImage {
        let longest = max(size.width, size.height) * scale
        guard longest > maxPixel else { return normalizedOrientation() }
        let factor = maxPixel / longest
        let target = CGSize(width: size.width * scale * factor, height: size.height * scale * factor)
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: target, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: target))
        }
    }

    /// Redraws the image so its pixel data is `.up` (Vision and JPEG export then agree).
    func normalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let format = UIGraphicsImageRendererFormat()
        format.scale = scale
        return UIGraphicsImageRenderer(size: size, format: format).image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }
}
