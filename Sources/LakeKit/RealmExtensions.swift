import Foundation
import RealmSwift

/// Forked from: https://github.com/realm/realm-swift/blob/9f7a605dfcf6a60e019a296dc8d91c3b23837a82/RealmSwift/SwiftUI.swift
private func safeWrite<Value>(_ value: Value, _ block: (Realm?, Value) -> Void) where Value: ThreadConfined {
    let thawed = value.realm == nil ? value : value.thaw() ?? value
    if let realm = thawed.realm, !realm.isInWriteTransaction {
        try! realm.write {
            block(realm, thawed)
        }
    } else {
        block(nil, thawed)
    }
}

extension URL: FailableCustomPersistable {
  public typealias PersistedType = String

  public init?(persistedValue: String) {
      self.init(string: persistedValue)
  }

  public var persistableValue: String {
    absoluteString
  }
}

public extension Object {
    var primaryKeyValue: String? {
        guard let pkName = type(of: self).sharedSchema()?.primaryKeyProperty?.name else { return nil }
        guard let pkType = type(of: self).sharedSchema()?.primaryKeyProperty?.type else { return nil }
        guard let pkValue = self.value(forKey: pkName) else { return nil }
        switch pkType {
        case .UUID:
            return (pkValue as? UUID)?.uuidString
        default:
            return pkValue as? String
        }
    }
    
    func isSameObjectByPrimaryKey(as other: Object?) -> Bool {
        guard let other = other else { return false }
        guard type(of: self) == type(of: other) else { return false }
        guard let pk1Value = self.primaryKeyValue else { return false }
        return !pk1Value.isEmpty && pk1Value == other.primaryKeyValue
    }
}

public extension BoundCollection where Value == Results<Element>, Element: Object & Decodable {
    func replace<O>(with objects: [O]) throws where O: Encodable {
        let encodedObjects = try objects.map { try JSONEncoder().encode($0) }
        let realmObjects = try encodedObjects.map { try JSONDecoder().decode(Element.self, from: $0) }
        
        safeWrite(wrappedValue) { realm, list in
            guard let realm = realm else {
                print("No realm?")
                return
            }
            
            realm.add(realmObjects, update: .modified)
            let addedPKs = Set(realmObjects.compactMap { $0.primaryKeyValue })
            
            for existingObject in self.wrappedValue {
                guard let existingPK = existingObject.primaryKeyValue else { continue }
                if !addedPKs.contains(existingPK) {
                    remove(existingObject)
                }
            }
        }
    }
}

//public extension BoundCollection where Value == Results<Element>, Element: ObjectBase & ThreadConfined {
/*@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public extension BoundCollection where Value == Results<Element>, Element: ObjectBase & ThreadConfined {
    /// :nodoc:
    func remove(_ object: Value.Element) {
        guard let thawed = object.thaw(),
              let index = wrappedValue.thaw()?.index(of: thawed) else {
            return
        }
        safeWrite(self.wrappedValue) { results in
            results.realm?.delete(results[index])
        }
    }
    /// :nodoc:
    func remove(atOffsets offsets: IndexSet) {
        safeWrite(self.wrappedValue) { results in
            results.realm?.delete(Array(offsets.map { results[$0] }))
        }
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public extension BoundCollection where Value == MutableSet<Element> {
    /// :nodoc:
    func remove(_ element: Value.Element) {
        safeWrite(self.wrappedValue) { mutableSet in
            mutableSet.remove(element)
        }
    }
    /// :nodoc:
    func insert(_ value: Value.Element) {
        safeWrite(self.wrappedValue) { mutableSet in
            mutableSet.insert(value)
        }
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public extension BoundCollection where Value == MutableSet<Element>, Element: ObjectBase & ThreadConfined {
    /// :nodoc:
    func remove(_ object: Value.Element) {
        safeWrite(self.wrappedValue) { mutableSet in
            mutableSet.remove(thawObjectIfFrozen(object))
        }
    }
    /// :nodoc:
    func insert(_ value: Value.Element) {
        // if the value is unmanaged but the set is managed, we are adding this value to the realm
        if value.realm == nil && self.wrappedValue.realm != nil {
            SwiftUIKVO.observedObjects[value]?.cancel()
        }
        safeWrite(self.wrappedValue) { mutableSet in
            mutableSet.insert(thawObjectIfFrozen(value))
        }
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public extension BoundCollection where Value == Results<Element>, Element: Object {
    /// :nodoc:
    func append(_ value: Value.Element) {
        if value.realm == nil && self.wrappedValue.realm != nil {
            SwiftUIKVO.observedObjects[value]?.cancel()
        }
        safeWrite(self.wrappedValue) { results in
            results.realm?.add(thawObjectIfFrozen(value))
        }
    }
}

@available(iOS 13.0, macOS 10.15, tvOS 13.0, watchOS 6.0, *)
public extension BoundCollection where Value == Results<Element>, Element: ProjectionObservable & ThreadConfined, Element.Root: Object {
    /// :nodoc:
    func append(_ value: Value.Element) {
        if value.realm == nil && self.wrappedValue.realm != nil {
            SwiftUIKVO.observedObjects[value.rootObject]?.cancel()
        }
        safeWrite(self.wrappedValue) { results in
            results.realm?.add(thawObjectIfFrozen(value.rootObject))
        }
    }
}
*/
