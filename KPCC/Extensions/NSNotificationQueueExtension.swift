//
//  NSNotificationQueueExtension.swift
//  KPCC
//
//  Created by Fuller, Christopher on 4/19/16.
//  Copyright © 2016 Southern California Public Radio. All rights reserved.
//

import Foundation

extension NSNotificationQueue: ClosureExecutable {

    func enqueue(notification: NSNotification, postingStyle: NSPostingStyle, coalesceMask: NSNotificationCoalescing? = nil) {
        execute(main: true) {
            notificationQueue in
            notificationQueue.enqueueNotification(
                notification,
                postingStyle: postingStyle,
                coalesceMask: (coalesceMask ?? [ .CoalescingOnName, .CoalescingOnSender ]),
                forModes: nil
            )
        }
    }

    func dequeue(notification: NSNotification, coalesceMask: NSNotificationCoalescing? = nil) {
        execute(main: true) {
            notificationQueue in
            notificationQueue.dequeueNotificationsMatching(
                notification,
                coalesceMask: Int((coalesceMask ?? [ .CoalescingOnName, .CoalescingOnSender ]).rawValue)
            )
        }
    }

}
