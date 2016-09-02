//
//  ObjectAssociable.swift
//  KPCC
//
//  Created by Fuller, Christopher on 8/8/16.
//  Copyright © 2016 Southern California Public Radio. All rights reserved.
//

import Foundation

protocol ObjectAssociable: AnyObject {}

extension ObjectAssociable {

    func getAssociatedObject<T: AnyObject>(key key: UnsafePointer<Void>) -> T? {
        return objc_getAssociatedObject(self, key) as? T
    }

    func setAssociatedObject<T: AnyObject>(key key: UnsafePointer<Void>, value: T?) {
        objc_setAssociatedObject(self, key, value, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
    }

}
