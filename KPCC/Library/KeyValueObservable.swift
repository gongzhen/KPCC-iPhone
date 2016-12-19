//
//  KeyValueObservable.swift
//  KPCC
//
//  Created by Fuller, Christopher on 7/21/16.
//  Copyright © 2016 Southern California Public Radio. All rights reserved.
//

import Foundation

extension NSObject: KeyValueObservable {}

typealias ValueChanged = (observer: KeyValueObserver, object: AnyObject, newValue: AnyObject?, oldValue: AnyObject?) -> Void

private struct Key {
    static var observers = 0
}

protocol KeyValueObservable: AnyObject, ObjectAssociable {}

extension KeyValueObservable {

    private var observers: KeyValueObservers? {
        get {
            return getAssociatedObject(key: &Key.observers)
        }
        set {
            setAssociatedObject(key: &Key.observers, value: newValue)
        }
    }

    func observeKeyPath<T: AnyObject where T: Equatable>(keyPath: String, ofObject object: AnyObject, initial: Bool = false, closure: (observer: KeyValueObserver, object: AnyObject, newValue: T?, oldValue: T?) -> Void) -> KeyValueObserver {
        if observers == nil {
            observers = KeyValueObservers(observable: self)
        }
        return observers!.addObserver(keyPath: keyPath, ofObject: object, initial: initial, closure: closure)
    }

    func stopObservingKeyPaths(ofObject object: AnyObject) {
        observers?.removeObservers(ofObject: object)
    }

    func stopObservingKeyPaths() {
        observers = nil
    }

}

class KeyValueObserver {

    private weak var observers: KeyValueObservers!

    private init(observers: KeyValueObservers) {
        self.observers = observers
    }

    func remove() {
        observers.removeObserver(self)
    }

}

private class KeyValueObservers: NSObject {

    class Observer: KeyValueObserver {

        private var context = 0
        private let keyPath: String
        private weak var object: AnyObject!
        private let closure: ValueChanged

        init(observers: KeyValueObservers, keyPath: String, object: AnyObject, closure: ValueChanged) {
            self.keyPath = keyPath
            self.object = object
            self.closure = closure
            super.init(observers: observers)
        }

        func observe(keyPath keyPath: String, object: AnyObject, newValue: AnyObject?, oldValue: AnyObject?) {
            closure(observer: self, object: object, newValue: newValue, oldValue: oldValue)
        }

    }

    private weak var observable: KeyValueObservable!

    private var observers = [Observer]()

    init(observable: KeyValueObservable) {
        self.observable = observable
    }

    deinit {
        observers.forEach { removeObserver($0) }
    }

    func addObserver<T: AnyObject where T: Equatable>(keyPath keyPath: String, ofObject object: AnyObject, initial: Bool = false, closure: (observer: KeyValueObserver, object: AnyObject, newValue: T?, oldValue: T?) -> Void) -> KeyValueObserver {
        let observer = Observer(observers: self, keyPath: keyPath, object: object) {
            observer, object, newValue, oldValue in
            let newValue = ((newValue as? T?) ?? (nil as T?))
            let oldValue = ((oldValue as? T?) ?? (nil as T?))
            if newValue != oldValue {
                closure(observer: observer, object: object, newValue: newValue, oldValue: oldValue)
            }
        }
        observers.append(observer)
        let options: NSKeyValueObservingOptions = (initial ? [ .New, .Old, .Initial ] : [ .New, .Old ])
        object.addObserver(self, forKeyPath: keyPath, options: options, context: &observer.context)
        return observer
    }

    func removeObserver(observer: KeyValueObserver) {
        if let index = observers.indexOf({ $0 === observer }) {
            let observer = observers.removeAtIndex(index)
            observer.object.removeObserver(self, forKeyPath: observer.keyPath, context: &observer.context)
            if let observable = observable where observers.isEmpty {
                observable.observers = nil
            }
        }
    }

    func removeObservers(ofObject object: AnyObject) {
        observers.filter({ $0.object === object }).forEach { removeObserver($0) }
    }

    private override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
        guard let keyPath = keyPath, object = object, change = change else { return }
        if let observer = observers.filter({ &$0.context == context }).first {
            let newValue = change[NSKeyValueChangeNewKey]
            let oldValue = change[NSKeyValueChangeOldKey]
            observer.observe(keyPath: keyPath, object: object, newValue: newValue, oldValue: oldValue)
        }
    }

}
