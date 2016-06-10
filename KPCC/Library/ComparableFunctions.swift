//
//  ComparableFunctions.swift
//  KPCC
//
//  Created by Fuller, Christopher on 6/3/16.
//  Copyright © 2016 Southern California Public Radio. All rights reserved.
//

@warn_unused_result
public func clamp<T: Comparable>(min: T, _ val: T, _ max: T) -> T {
    return Swift.min(Swift.max(min, val), max)
}
