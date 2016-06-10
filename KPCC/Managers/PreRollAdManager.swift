//
//  PreRollAdManager.swift
//  KPCC
//
//  Created by Fuller, Christopher on 6/9/16.
//  Copyright © 2016 Southern California Public Radio. All rights reserved.
//

import UIKit

private protocol CustomAction {

    var baseURL: String { get }
    var queryItems: [NSURLQueryItem]? { get set }

    func execute()

}

private extension CustomAction {

    func presentViewController(viewControllerToPresent: UIViewController) {
        let rootViewController = UIApplication.sharedApplication().keyWindow?.rootViewController
        rootViewController?.presentViewController(viewControllerToPresent, animated: true, completion: nil)
    }

}

private class EloquaAction: CustomAction {

    var baseURL = "https://s1715082578.t.eloqua.com/e/f2"
    var queryItems: [NSURLQueryItem]?

    lazy var authenticationManager = AuthenticationManager.sharedInstance

    func execute() {
        if authenticationManager.isAuthenticated {
            let alertController = UIAlertController(
                title: "All set!",
                message: "You've been entered to win.",
                preferredStyle: .Alert
            )
            alertController.addAction(
                UIAlertAction(
                    title: "Hey, thanks!",
                    style: .Default,
                    handler: nil
                )
            )
            presentViewController(alertController)
        }
        else {
            let alertController = UIAlertController(
                title: "Must be logged in to enter :(",
                message: "Please tap 'Profile' in the menu and then tap 'Log In'.",
                preferredStyle: .Alert
            )
            alertController.addAction(
                UIAlertAction(
                    title: "OK",
                    style: .Default,
                    handler: nil
                )
            )
            presentViewController(alertController)
        }
    }

}

class PreRollAdManager: NSObject {

}

extension PreRollAdManager {

    private static let customActions: [CustomAction] = {
        return [ EloquaAction() ]
    }()

}

extension PreRollAdManager {

    static var sharedInstance: PreRollAdManager {
        return _sharedInstance
    }

    private static let _sharedInstance = PreRollAdManager()
    
}

extension PreRollAdManager {

    func openURL(url: String) {
        if let customAction = customActionForURL(url) {
            customAction.execute()
        }
        else if let URL = NSURL(string: url) {
            UIApplication.sharedApplication().openURL(URL)
        }
    }

}

private extension PreRollAdManager {

    func customActionForURL(url: String) -> CustomAction? {
        for var customAction in PreRollAdManager.customActions {
            if let urlComponents = extractLink(baseURL: customAction.baseURL, url: url) {
                customAction.queryItems = urlComponents.queryItems
                return customAction
            }
        }
        return nil
    }

    func extractLink(baseURL baseURL: String, url: String) -> NSURLComponents? {
        let parts = url.componentsSeparatedByString(";link=\(baseURL)")
        if let last = parts.last where parts.count == 2 {
            return NSURLComponents(string: (baseURL + last))
        }
        return nil
    }

}
