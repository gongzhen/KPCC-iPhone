//
//  PreRollAdController.swift
//  KPCC
//
//  Created by Fuller, Christopher on 6/9/16.
//  Copyright © 2016 Southern California Public Radio. All rights reserved.
//

import UIKit

private protocol CustomAction {

    var baseURL: String { get }
    var preRollAdController: PreRollAdController? { get set }
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
    var preRollAdController: PreRollAdController?
    var queryItems: [NSURLQueryItem]?

    lazy var authenticationManager = AuthenticationManager.sharedInstance

    @objc func textFieldEditingChanged(sender: AnyObject) {
        if let textField = sender as? UITextField, alertController = textField.alertController {
            AuthenticationManager.validateUserProfileAlertController(alertController)
        }
    }

    func execute() {
        if authenticationManager.isAuthenticated {
            let userProfileComplete = (authenticationManager.userProfile?.isComplete ?? false)
            if userProfileComplete {
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
                presentUserProfileAlertController()
            }
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

    private func presentUserProfileAlertController() {
        let action = #selector(textFieldEditingChanged)
        let alertController = authenticationManager.newUserProfileAlertController(target: self, action: action) {
            [ weak self ] success in
            guard let _self = self else { return }
            if success {
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
                _self.presentViewController(alertController)
            }
        }
        presentViewController(alertController)
    }

}

class PreRollAdController: NSObject {

}

extension PreRollAdController {

    private static let customActions: [CustomAction] = {
        return [ EloquaAction() ]
    }()

}

extension PreRollAdController {

    func openURL(url: String) {
        if let customAction = customActionForURL(url) {
            customAction.execute()
        }
        else if let URL = NSURL(string: url) {
            UIApplication.sharedApplication().openURL(URL)
        }
    }

}

private extension PreRollAdController {

    func customActionForURL(url: String) -> CustomAction? {
        for var customAction in PreRollAdController.customActions {
            if let urlComponents = extractLink(baseURL: customAction.baseURL, url: url) {
                customAction.preRollAdController = self
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
