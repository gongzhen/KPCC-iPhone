//
//  InterfaceUpdatable.swift
//  KPCC
//
//  Created by Fuller, Christopher on 6/20/16.
//  Copyright © 2016 Southern California Public Radio. All rights reserved.
//

import UIKit

struct UpdateInterfaceNotification: UserInfoTransformableNotification {

    private struct Key {
        static var animated = "animated"
    }

    private(set) var animated: Bool

    var userInfo: [NSObject : AnyObject]? {
        return [
            Key.animated: animated
        ]
    }

    init?(userInfo: [NSObject : AnyObject]?) {
        guard let animated = userInfo?[Key.animated] as? Bool else {
            return nil
        }
        self.animated = animated
    }

    init(animated: Bool) {
        self.animated = animated
    }

}

protocol UpdateInterfaceNotifiable: AnyObject {

    var notificationQueue: NSNotificationQueue { get }

}

extension UpdateInterfaceNotifiable {

    func updateInterface() {
        notificationQueue.enqueue(
            UpdateInterfaceNotification(animated: false).materialize(object: self),
            postingStyle: .PostNow
        )
    }

    func setNeedsUpdateInterface() {
        notificationQueue.enqueue(
            UpdateInterfaceNotification(animated: true).materialize(object: self),
            postingStyle: .PostASAP
        )
    }

}

protocol InterfaceUpdatable: UpdateInterfaceNotifiable, NotificationObservable {

    func updateInterface(notification: UpdateInterfaceNotification)

}

extension InterfaceUpdatable {

    func observeUpdateInterfaceNotification(ofObject object: AnyObject? = nil) {
        observeNotification(ofObject: object ?? self) {
            [ weak self ] (_, _, notification: UpdateInterfaceNotification?) in
            guard let _self = self else { return }
            if let notification = notification {
                let applicationState = UIApplication.sharedApplication().applicationState
                if !notification.animated || (applicationState != .Background) {
                    _self.updateInterface(notification)
                }
            }
        }
    }

    func updateInterfaceWhenApplicationWillEnterForeground() {
        observeNotification(name: UIApplicationWillEnterForegroundNotification) {
            [ weak self ] _, _ in
            guard let _self = self else { return }
            _self.updateInterface()
        }
    }

}
