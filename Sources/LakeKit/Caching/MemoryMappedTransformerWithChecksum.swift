import Foundation
import Cache

public struct MemoryMappedTransformer<T: Codable>: Transformer {
    typealias Input = T
    typealias Output = Data
    
    private let encoder = PropertyListEncoder()
    private let decoder = PropertyListDecoder()
    
    public func toData(_ input: T) throws -> Data {
        encoder.outputFormat = .binary // Use binary PropertyList format for efficiency
        return try encoder.encode(input)
    }
    
    public func fromData(_ data: Data) throws -> T {
        return try decoder.decode(T.self, from: data)
    }
    
    // Directly map the file into memory for faster access
    public func fromFile(at url: URL) throws -> T {
        let data = try Data(contentsOf: url, options: .mappedIfSafe)
        return try fromData(data)
    }
    
    // Save the file atomically
    public func toFile(_ input: T, at url: URL) throws {
        let data = try toData(input)
        try data.write(to: url, options: .atomic)
    }
}
