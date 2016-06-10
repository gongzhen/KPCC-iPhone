//
//  BackgroundTask.swift
//  KPCC
//
//  Created by Fuller, Christopher on 4/14/16.
//  Copyright © 2016 Southern California Public Radio. All rights reserved.
//

import UIKit

struct BackgroundTask {

    lazy var application = UIApplication.sharedApplication()

    private var identifier = UIBackgroundTaskInvalid

    init?(_ name: String, expirationHandler handler: Closure? = nil) {
        identifier = application.beginBackgroundTaskWithName(name) {
            handler?()
            self.end()
        }
        if identifier == UIBackgroundTaskInvalid {
            return nil
        }
    }

}

extension BackgroundTask {

    mutating func end() {
        if identifier != UIBackgroundTaskInvalid {
            application.endBackgroundTask(identifier)
            identifier = UIBackgroundTaskInvalid
        }
    }

}
