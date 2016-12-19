//
//  ClosureExecutable.swift
//  KPCC
//
//  Created by Fuller, Christopher on 8/31/16.
//  Copyright © 2016 Southern California Public Radio. All rights reserved.
//

import Foundation

protocol ClosureExecutable: AnyObject {}

extension ClosureExecutable {

    func execute(main main: Bool = false, closure: (AnyObject) -> Void) {
        if !main || NSThread.isMainThread() {
            closure(self)
        }
        else {
            Dispatch.sync {
                closure(self)
            }
        }
    }

}
