import CoreFoundation
import Foundation

/// Host JSON conversion keeps shared containers but rejects cycles and excessive nesting.
struct JSONConversion {
    private var ancestors = Set<ObjectIdentifier>()

    mutating func value(_ value: Any, depth: Int = 0) throws -> JSONValue {
        guard depth <= 64 else {
            throw JSONValue.NotJSON(description: "JSON nesting must not exceed 64 levels")
        }
        switch value {
        case let date as Date: return .string(date.rfc3339)
        case let url as URL: return .string(url.absoluteString)
        case let uuid as UUID: return .string(uuid.uuidString)
        default: return try object(value as AnyObject, depth: depth)
        }
    }

    private mutating func object(_ object: AnyObject, depth: Int) throws -> JSONValue {
        switch object {
        case is NSNull: return .null
        case let number as NSNumber: return try numeric(number)
        case let string as NSString: return .string(string as String)
        case let array as NSArray:
            try enter(array)
            defer { ancestors.remove(ObjectIdentifier(array)) }
            // Cocoa subscripts bridge whole containers to Swift before validation and can
            // recurse through a cycle. Toll-free CF access reads one retained child at a time.
            let storage = unsafeBitCast(array, to: CFArray.self)
            return .array(try (0..<array.count).map { index in
                let child = Unmanaged<AnyObject>.fromOpaque(CFArrayGetValueAtIndex(storage, index)).takeUnretainedValue()
                return try value(child, depth: depth + 1)
            })
        case let dictionary as NSDictionary:
            try enter(dictionary)
            defer { ancestors.remove(ObjectIdentifier(dictionary)) }
            return .object(try members(dictionary, depth: depth))
        default:
            throw JSONValue.NotJSON(description: "a \(type(of: object)) is not JSON")
        }
    }

    private mutating func enter(_ object: AnyObject) throws {
        guard ancestors.insert(ObjectIdentifier(object)).inserted else {
            throw JSONValue.NotJSON(description: "JSON properties must not contain cycles")
        }
    }

    private mutating func members(_ dictionary: NSDictionary, depth: Int) throws -> [String: JSONValue] {
        let storage = unsafeBitCast(dictionary, to: CFDictionary.self)
        var keys = [UnsafeRawPointer?](repeating: nil, count: dictionary.count)
        var values = keys
        CFDictionaryGetKeysAndValues(storage, &keys, &values)
        var members: [String: JSONValue] = [:]
        for index in keys.indices {
            let keyObject = Unmanaged<AnyObject>.fromOpaque(keys[index]!).takeUnretainedValue()
            guard let key = keyObject as? String else {
                throw JSONValue.NotJSON(description: "a dictionary key is not a string")
            }
            let child = Unmanaged<AnyObject>.fromOpaque(values[index]!).takeUnretainedValue()
            members[key] = try value(child, depth: depth + 1)
        }
        return members
    }

    private func numeric(_ number: NSNumber) throws -> JSONValue {
        if CFGetTypeID(number) == CFBooleanGetTypeID() { return .bool(number.boolValue) }
        guard number.doubleValue.isFinite else {
            throw JSONValue.NotJSON(description: "a non-finite number is not JSON")
        }
        if CFNumberIsFloatType(number) { return .number(number.doubleValue) }
        if let integer = Int64(number.stringValue) { return .integer(integer) }
        if let unsigned = UInt64(number.stringValue) { return .unsigned(unsigned) }
        return .number(number.doubleValue)
    }
}
