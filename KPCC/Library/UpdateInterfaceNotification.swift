//
//  UpdateInterfaceNotification.swift
//  KPCC
//
//  Created by Fuller, Christopher on 6/12/16.
//  Copyright © 2016 Southern California Public Radio. All rights reserved.
//

import Foundation

private let NeedsUpdateInterfaceNotification = "NeedsUpdateInterfaceNotification"

@objc protocol UpdateInterfaceNotification {

    func updateInterface(notification: NSNotification)

}

extension UpdateInterfaceNotification {

    func startObservingUpdateInterfaceNotification() {
        NSNotificationCenter.defaultCenter().addObserver(
            self,
            selector: #selector(updateInterface),
            name: NeedsUpdateInterfaceNotification,
            object: self
        )
    }

    func stopObservingUpdateInterfaceNotification() {
        NSNotificationCenter.defaultCenter().removeObserver(
            self,
            name: NeedsUpdateInterfaceNotification,
            object: self
        )
    }

    func setNeedsUpdateInterface() {
        NSNotificationQueue.defaultQueue().enqueueNotification(
            NSNotification(name: NeedsUpdateInterfaceNotification, object: self),
            postingStyle: .PostASAP,
            coalesceMask: [ .CoalescingOnName, .CoalescingOnSender ],
            forModes: nil
        )
    }

}
