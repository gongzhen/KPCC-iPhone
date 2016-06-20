//
//  Notification.swift
//  KPCC
//
//  Created by Fuller, Christopher on 6/20/16.
//  Copyright © 2016 Southern California Public Radio. All rights reserved.
//

import Foundation

struct Notification {

    static var notificationQueue = NSNotificationQueue.defaultQueue()

}

extension Notification {

    private static let defaultCoalesceMask: NSNotificationCoalescing = [ .CoalescingOnName, .CoalescingOnSender ]

    static func enqueue(notification: NSNotification, postingStyle: NSPostingStyle, coalesceMask: NSNotificationCoalescing? = nil) {
        let closure = {
            let coalesceMask = (coalesceMask ?? defaultCoalesceMask)
            notificationQueue.enqueueNotification(notification, postingStyle: postingStyle, coalesceMask: coalesceMask, forModes: nil)
        }
        NSThread.isMainThread() ? closure() : Dispatch.async(closure: closure)
    }

    static func dequeue(notification: NSNotification, coalesceMask: NSNotificationCoalescing? = nil) {
        let closure = {
            let coalesceMask = (coalesceMask ?? defaultCoalesceMask)
            notificationQueue.dequeueNotificationsMatching(notification, coalesceMask: Int(coalesceMask.rawValue))
        }
        NSThread.isMainThread() ? closure() : Dispatch.async(closure: closure)
    }

}
