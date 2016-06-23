//
//  AuthenticationViewController.swift
//  KPCC
//
//  Created by Fuller, Christopher on 6/20/16.
//  Copyright © 2016 Southern California Public Radio. All rights reserved.
//

import UIKit
import Lock

class AuthenticationViewController: UINavigationController {

    lazy var authenticationManager = AuthenticationManager.sharedInstance

    var defaultAuthenticationMode: AuthenticationMode = .SignUp
    var cancelSignUpConfirmationMessage: String?
    var cancelLogInConfirmationMessage: String?
    var messageViewController: MessageViewController?

    private var authenticationMode: AuthenticationMode = .SignUp {
        didSet {
            switch authenticationMode {
            case .SignUp:
                if let lockSignUpViewController = newLockSignUpViewController() {
                    hideKeyboard()
                    viewControllers = [ lockSignUpViewController ]
                }
            case .LogIn:
                if let lockViewController = newLockViewController() {
                    hideKeyboard()
                    viewControllers = [ lockViewController ]
                }
            }
        }
    }

}

extension AuthenticationViewController {

    private static var backgroundColor: UIColor {
        return A0Theme.KPCCTheme().colorForKey(
            A0ThemeScreenBackgroundColor,
            defaultColor: UIColor.whiteColor()
        )
    }

}

extension AuthenticationViewController {

    enum AuthenticationMode {
        case SignUp
        case LogIn
    }

    class MessageViewController: UIViewController {

        var activity = false {
            didSet {
                if activity != oldValue {
                    if activity {
                        activityIndicatorView.startAnimating()
                        headingLabel.hidden = true
                        messageLabel.hidden = true
                        button.hidden = true
                    }
                    else {
                        activityIndicatorView.stopAnimating()
                        headingLabel.hidden = false
                        messageLabel.hidden = false
                        button.hidden = false
                    }
                }
            }
        }

        private let activityIndicatorView = UIActivityIndicatorView(activityIndicatorStyle: .Gray)

        private let headingLabel: UILabel = {
            let headingLabel = UILabel()
            headingLabel.numberOfLines = 0
            headingLabel.textAlignment = .Center
            return headingLabel
        }()

        private let messageLabel: UILabel = {
            let messageLabel = UILabel()
            messageLabel.numberOfLines = 0
            messageLabel.textAlignment = .Center
            return messageLabel
        }()

        private let button = UIButton(type: .System)

        convenience init(heading: String, message: String, buttonTitle: String) {
            self.init()
            set(heading: heading, message: message, buttonTitle: buttonTitle)
            button.addTarget(self, action: #selector(dismiss), forControlEvents: .TouchUpInside)
        }

        func set(heading heading: String, message: String, buttonTitle: String) {
            headingLabel.text = heading
            messageLabel.text = message
            button.setTitle(buttonTitle, forState: .Normal)
        }

        override func viewDidLoad() {

            super.viewDidLoad()

            view.backgroundColor = AuthenticationViewController.backgroundColor

            activityIndicatorView.translatesAutoresizingMaskIntoConstraints = false
            headingLabel.translatesAutoresizingMaskIntoConstraints = false
            messageLabel.translatesAutoresizingMaskIntoConstraints = false
            button.translatesAutoresizingMaskIntoConstraints = false

            view.addSubview(activityIndicatorView)
            view.addSubview(headingLabel)
            view.addSubview(messageLabel)
            view.addSubview(button)

            let views = [
                "activityIndicatorView": activityIndicatorView,
                "headingLabel": headingLabel,
                "messageLabel": messageLabel,
                "button": button
            ]

            view.addConstraint(
                NSLayoutConstraint(
                    item: view,
                    attribute: .CenterX,
                    relatedBy: .Equal,
                    toItem: activityIndicatorView,
                    attribute: .CenterX,
                    multiplier: 1.0,
                    constant: 0.0
                )
            )

            view.addConstraint(
                NSLayoutConstraint(
                    item: view,
                    attribute: .CenterY,
                    relatedBy: .Equal,
                    toItem: activityIndicatorView,
                    attribute: .CenterY,
                    multiplier: 1.0,
                    constant: 64.0
                )
            )

            view.addConstraints(
                NSLayoutConstraint.constraintsWithVisualFormat(
                    "H:|-32-[headingLabel]-32-|",
                    options: [],
                    metrics: nil,
                    views: views
                )
            )

            view.addConstraints(
                NSLayoutConstraint.constraintsWithVisualFormat(
                    "H:|-32-[messageLabel]-32-|",
                    options: [],
                    metrics: nil,
                    views: views
                )
            )

            view.addConstraints(
                NSLayoutConstraint.constraintsWithVisualFormat(
                    "H:|-32-[button]-32-|",
                    options: [],
                    metrics: nil,
                    views: views
                )
            )

            view.addConstraint(
                NSLayoutConstraint(
                    item: view,
                    attribute: .CenterY,
                    relatedBy: .Equal,
                    toItem: button,
                    attribute: .CenterY,
                    multiplier: 1.0,
                    constant: 32.0
                )
            )

            view.addConstraints(
                NSLayoutConstraint.constraintsWithVisualFormat(
                    "V:[headingLabel]-[messageLabel]-[button]",
                    options: [],
                    metrics: nil,
                    views: views
                )
            )

        }

        @objc private func dismiss() {
            dismissViewControllerAnimated(true, completion: nil)
        }

    }

}

extension AuthenticationViewController {

    override func viewDidLoad() {

        super.viewDidLoad()

        navigationBar.barStyle = .Default
        navigationBar.translucent = false
        navigationBar.barTintColor = AuthenticationViewController.backgroundColor

        view.backgroundColor = AuthenticationViewController.backgroundColor

    }

    override func viewWillAppear(animated: Bool) {

        super.viewWillAppear(animated)

        if viewControllers.count == 0 {
            if authenticationManager.isAuthenticated {
                onAuthentication(true)
            }
            else {
                authenticationMode = defaultAuthenticationMode
            }
        }

    }

}

private extension AuthenticationViewController {

    @objc func toggle() {
        switch authenticationMode {
        case .SignUp:
            authenticationMode = .LogIn
        case .LogIn:
            authenticationMode = .SignUp
        }
    }

    @objc func cancel() {

        let cancelConfirmationMessage: String?

        switch authenticationMode {
        case .SignUp:
            cancelConfirmationMessage = cancelSignUpConfirmationMessage
        case .LogIn:
            cancelConfirmationMessage = cancelLogInConfirmationMessage
        }

        guard let message = cancelConfirmationMessage else {
            dismiss()
            return
        }

        let alertController = UIAlertController(
            title: "Are you sure you want to cancel?",
            message: message,
            preferredStyle: .Alert
        )

        alertController.addAction(
            UIAlertAction(
                title: "Yes",
                style: .Default,
                handler: {
                    [ weak self ] _ in
                    guard let _self = self else { return }
                    _self.dismiss()
                }
            )
        )

        alertController.addAction(
            UIAlertAction(
                title: "No",
                style: .Cancel,
                handler: nil
            )
        )

        presentViewController(alertController, animated: true, completion: nil)

    }

    @objc func dismiss() {
        hideKeyboard()
        dismissViewControllerAnimated(true, completion: nil)
    }

}

private extension AuthenticationViewController {

    func onAuthentication(success: Bool) {
        if success {
            if let messageViewController = messageViewController {
                setViewControllers([ messageViewController ], animated: true)
            }
            else {
                dismiss()
            }
        }
        else {
            let messageViewController = MessageViewController(
                heading: "Error",
                message: "An unexpected error occurred.",
                buttonTitle: "Ok"
            )
            setViewControllers([ messageViewController ], animated: true)
        }
    }

    func newLockSignUpViewController() -> A0LockSignUpViewController? {
        let lockSignUpViewController = authenticationManager.newLockSignUpViewController() {
            [ weak self ] success in
            guard let _self = self else { return }
            _self.onAuthentication(success)
        }
        if let lockSignUpViewController = lockSignUpViewController {
            lockSignUpViewController.navigationItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .Cancel,
                target: self,
                action: #selector(cancel)
            )
            lockSignUpViewController.navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Log In",
                style: .Plain,
                target: self,
                action: #selector(toggle)
            )
        }
        return lockSignUpViewController
    }

    func newLockViewController() -> A0LockViewController? {
        let lockViewController = authenticationManager.newLockViewController() {
            [ weak self ] success in
            guard let _self = self else { return }
            _self.onAuthentication(success)
        }
        if let lockViewController = lockViewController {
            lockViewController.navigationItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .Cancel,
                target: self,
                action: #selector(cancel)
            )
            lockViewController.navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Sign Up",
                style: .Plain,
                target: self,
                action: #selector(toggle)
            )
        }
        return lockViewController
    }

    func hideKeyboard() {
        var viewController: UIViewController?
        if let lockSignUpViewController = topViewController as? A0LockSignUpViewController {
            viewController = lockSignUpViewController
        }
        else if let lockViewController = topViewController as? A0LockViewController {
            viewController = lockViewController
        }
        if let viewController = viewController {
            let selector = NSSelectorFromString("hideKeyboard:")
            if viewController.respondsToSelector(selector) {
                viewController.performSelector(selector, withObject: nil)
            }
        }
    }

}
