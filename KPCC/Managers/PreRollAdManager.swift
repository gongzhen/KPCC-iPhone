//
//  PreRollAdManager.swift
//  KPCC
//
//  Created by Fuller, Christopher on 6/9/16.
//  Copyright © 2016 Southern California Public Radio. All rights reserved.
//

import UIKit

private let EloquaActionBaseURL = "https://s1715082578.t.eloqua.com/e/f2"

private class CustomAction {

    var baseURL: String

    private var queryItems: [NSURLQueryItem]?

    private func execute(presentViewControllerBlock presentViewController: (UIViewController) -> Void) {}

    init(baseURL: String) {
        self.baseURL = baseURL
    }

    func queryItemsDictionary() -> [String: String] {
        var data = [String: String]()
        if let queryItems = queryItems {
            for queryItem in queryItems {
                if let value = queryItem.value {
                    data[queryItem.name] = value
                }
            }
        }
        return data
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

    private class MessageViewController: AuthenticationViewController.MessageViewController {

        lazy var authenticationManager = AuthenticationManager.sharedInstance

        weak var eloquaAction: EloquaAction?

        private override func viewWillAppear(animated: Bool) {

            super.viewWillAppear(animated)

            guard !activity else { return }

            if let eloquaAction = eloquaAction {
                if let email = authenticationManager.userProfile?.email {
                    var data = eloquaAction.queryItemsDictionary()
                    data["emailAddress"] = email
                    activity = true
                    eloquaAction.resumeDataTask(URL: eloquaAction.baseURL, method: "POST", data: data) {
                        success in
                        Dispatch.async {
                            [ weak self ] in
                            guard let _self = self else { return }
                            if !success {
                                _self.error()
                            }
                            _self.activity = false
                        }
                    }
                }
                else {
                    set(
                        heading: "Sorry!",
                        message: "We can't submit your information for giveaways, as your social profile settings do not allow visibility of your email address. We'll need that to contact you if you win. Contact us for assistance.",
                        dismissButtonTitle: "Go to KPCC Live",
                        actionButtonTitle: "Contact Us",
                        actionClosure: {
                            [ weak self ] in
                            guard let _self = self else { return }
                            _self.authenticationManager.presentMailComposeViewController(presentFrom: _self)
                        }
                    )
                }
            }
            else {
                error()
            }

            eloquaAction = nil

        }

        private func error() {
            set(
                heading: "Sorry!",
                message: "An unexpected error occurred.",
                dismissButtonTitle: "Continue"
            )
        }

    }

    private lazy var authenticationMessageViewController: MessageViewController = {
        let authenticationMessageViewController = MessageViewController(
            heading: "Success!",
            message: "You've been entered to win.",
            dismissButtonTitle: "Go to KPCC Live"
        )
        authenticationMessageViewController.eloquaAction = self
        return authenticationMessageViewController
    }()

    init() {
        super.init(baseURL: EloquaActionBaseURL)
    }

    private override func execute(presentViewControllerBlock presentViewController: (UIViewController) -> Void) {
        let authenticationViewController = AuthenticationViewController(originForAnalytics: "ticketTuesdayAd")
        authenticationViewController.cancelSignUpConfirmationMessage = "You can only enter to win if you create an account."
        authenticationViewController.cancelLogInConfirmationMessage = "You can only enter to win if you log into the app."
        authenticationViewController.messageViewController = authenticationMessageViewController
        presentViewController(authenticationViewController)
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

    func openURL(url: String, presentViewControllerBlock presentViewController: (UIViewController) -> Void) {
        if let customAction = customActionForURL(url) {
            #if RELEASE
                AnalyticsManager.shared().logEvent(
                    "ticketTuesdayAdTapped",
                    withParameters: customAction.queryItemsDictionary()
                )
            #endif
            customAction.execute(presentViewControllerBlock: presentViewController)
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
