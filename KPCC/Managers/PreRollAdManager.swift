//
//  PreRollAdManager.swift
//  KPCC
//
//  Created by Fuller, Christopher on 6/9/16.
//  Copyright © 2016 Southern California Public Radio. All rights reserved.
//

import UIKit

private class CustomAction {

    var baseURL: String

    private var queryItems: [NSURLQueryItem]?

    private func execute() {}

    init(baseURL: String) {
        self.baseURL = baseURL
    }

    func resumeDataTask(URL URL: String, method: String, data: [String: String]? = nil, completion: (Bool) -> Void) {
        guard let URL = NSURL(string: URL) else { return }
        let request = NSMutableURLRequest(URL: URL, HTTPMethod: method)
        if let data = data {
            request.setHTTPBodyWithDictionary(data)
            if let length = request.HTTPBody?.length where length > 0 {
                request.addValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
                request.addValue(String(length), forHTTPHeaderField: "Content-Length")
            }
        }
        var backgroundTask = BackgroundTask("CustomAction.resumeDataTask(URL:method:data:completion:")
        let task = NSURLSession.sharedSession().dataTaskWithRequest(request) {
            _, response, _ in
            if let response = response as? NSHTTPURLResponse {
                completion(response.statusCode == 200)
            }
            else {
                completion(false)
            }
            backgroundTask?.end()
        }
        task.resume()
    }

}

private class EloquaAction: CustomAction {

    lazy var authenticationManager = AuthenticationManager.sharedInstance

    init() {
        super.init(baseURL: "https://s1715082578.t.eloqua.com/e/f2")
    }

    private override func execute() {
        if authenticationManager.isAuthenticated {
            if let email = authenticationManager.userProfile?.email {
                var data = [ "emailAddress": email ]
                if let queryItems = queryItems {
                    for queryItem in queryItems {
                        if let value = queryItem.value {
                            data[queryItem.name] = value
                        }
                    }
                }
                resumeDataTask(URL: baseURL, method: "POST", data: data) {
                    [ weak self ] _ in
                    guard let _self = self else { return }
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
                    Dispatch.async {
                        _self.presentAlertController(alertController)
                    }
                }

            }
            else {
                let alertController = UIAlertController(
                    title: "Error",
                    message: "An unexpected error occurred.",
                    preferredStyle: .Alert
                )
                alertController.addAction(
                    UIAlertAction(
                        title: "OK",
                        style: .Default,
                        handler: nil
                    )
                )
                presentAlertController(alertController)
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
            presentAlertController(alertController)
        }
    }

    private func presentAlertController(alertController: UIAlertController, animated: Bool = true) {
        let rootViewController = UIApplication.sharedApplication().delegate?.window??.rootViewController
        rootViewController?.presentViewController(alertController, animated: animated, completion: nil)
    }

}

class PreRollAdManager: NSObject {

    static var sharedInstance: PreRollAdManager {
        return _sharedInstance
    }

    private static let _sharedInstance = PreRollAdManager()

    private static let customActions: [CustomAction] = {
        return [ EloquaAction() ]
    }()

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
        for customAction in PreRollAdManager.customActions {
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
