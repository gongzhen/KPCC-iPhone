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
    var originForAnalytics: String

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

    init(originForAnalytics: String) {
        self.originForAnalytics = originForAnalytics
        super.init(nibName: String(AuthenticationViewController), bundle: nil)
    }

    required convenience init?(coder aDecoder: NSCoder) {
        if let originForAnalytics = aDecoder.decodeObjectForKey("originForAnalytics") as? String
        {
            self.init(originForAnalytics: originForAnalytics)
        }
        else {
            return nil
        }
    }

    override func encodeWithCoder(aCoder: NSCoder) {
        super.encodeWithCoder(aCoder)
        aCoder.encodeObject(originForAnalytics, forKey: "originForAnalytics")
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
                    activityDidChange()
                }
            }
        }

        private let jogShuttleViewController: SCPRJogShuttleViewController = {
            let jogShuttleViewController = SCPRJogShuttleViewController()
            jogShuttleViewController.view.layoutIfNeeded()
            return jogShuttleViewController
        }()

        private let headingLabel: UILabel = {
            let headingLabel = UILabel()
            A0Theme.KPCCTheme().configureLabel(headingLabel)
            headingLabel.textColor = A0Theme.KPCC.HeadColor
            headingLabel.font = A0Theme.KPCC.HeadFont
            headingLabel.numberOfLines = 0
            headingLabel.textAlignment = .Center
            return headingLabel
        }()

        private let messageLabel: UILabel = {
            let messageLabel = UILabel()
            A0Theme.KPCCTheme().configureLabel(messageLabel)
            messageLabel.textColor = A0Theme.KPCC.BodyColor
            messageLabel.font = A0Theme.KPCC.BodyFont
            messageLabel.numberOfLines = 0
            messageLabel.textAlignment = .Center
            return messageLabel
        }()

        private let dismissButton: UIButton = {
            let dismissButton = UIButton(type: .Custom)
            A0Theme.KPCCTheme().configurePrimaryButton(dismissButton)
            return dismissButton
        }()

        private let actionButton: UIButton = {
            let actionButton = UIButton(type: .Custom)
            A0Theme.KPCCTheme().configurePrimaryButton(actionButton)
            return actionButton
        }()

        private var actionClosure: Closure?

        private var constraintsA: [NSLayoutConstraint]!
        private var constraintsB: [NSLayoutConstraint]!

        convenience init(heading: String, message: String, dismissButtonTitle: String, actionButtonTitle: String? = nil, actionClosure: Closure? = nil) {
            self.init()
            set(
                heading: heading,
                message: message,
                dismissButtonTitle: dismissButtonTitle,
                actionButtonTitle: actionButtonTitle,
                actionClosure: actionClosure
            )
            dismissButton.addTarget(
                self,
                action: #selector(dismiss),
                forControlEvents: .TouchUpInside
            )
            actionButton.addTarget(
                self,
                action: #selector(action),
                forControlEvents: .TouchUpInside
            )
        }

        func set(heading heading: String, message: String, dismissButtonTitle: String, actionButtonTitle: String? = nil, actionClosure: Closure? = nil) {

            headingLabel.text = heading
            messageLabel.text = message

            dismissButton.setTitle(dismissButtonTitle, forState: .Normal)

            if let actionButtonTitle = actionButtonTitle {
                actionButton.setTitle(actionButtonTitle, forState: .Normal)
            }

            self.actionClosure = actionClosure

            if let _ = view {
                NSLayoutConstraint.deactivateConstraints(constraintsA)
                NSLayoutConstraint.deactivateConstraints(constraintsB)
                NSLayoutConstraint.activateConstraints((actionClosure == nil) ? constraintsA : constraintsB)
            }

            actionButton.hidden = (actionClosure == nil)

        }

        override func viewDidLoad() {

            super.viewDidLoad()

            view.backgroundColor = UIColor.whiteColor()

            jogShuttleViewController.view.translatesAutoresizingMaskIntoConstraints = false
            headingLabel.translatesAutoresizingMaskIntoConstraints = false
            messageLabel.translatesAutoresizingMaskIntoConstraints = false
            dismissButton.translatesAutoresizingMaskIntoConstraints = false
            actionButton.translatesAutoresizingMaskIntoConstraints = false

            view.addSubview(jogShuttleViewController.view)
            view.addSubview(headingLabel)
            view.addSubview(messageLabel)
            view.addSubview(dismissButton)
            view.addSubview(actionButton)

            let views = [
                "headingLabel": headingLabel,
                "messageLabel": messageLabel,
                "dismissButton": dismissButton,
                "actionButton": actionButton
            ]

            NSLayoutConstraint.activateConstraints(
                [
                    NSLayoutConstraint(
                        item: jogShuttleViewController.view,
                        attribute: .Width,
                        relatedBy: .Equal,
                        toItem: nil,
                        attribute: .NotAnAttribute,
                        multiplier: 1.0,
                        constant: 100.0
                    ),
                    NSLayoutConstraint(
                        item: jogShuttleViewController.view,
                        attribute: .Height,
                        relatedBy: .Equal,
                        toItem: nil,
                        attribute: .NotAnAttribute,
                        multiplier: 1.0,
                        constant: 100.0
                    ),
                    NSLayoutConstraint(
                        item: view,
                        attribute: .CenterX,
                        relatedBy: .Equal,
                        toItem: jogShuttleViewController.view,
                        attribute: .CenterX,
                        multiplier: 1.0,
                        constant: 0.0
                    ),
                    NSLayoutConstraint(
                        item: view,
                        attribute: .CenterY,
                        relatedBy: .Equal,
                        toItem: jogShuttleViewController.view,
                        attribute: .CenterY,
                        multiplier: 1.0,
                        constant: 64.0
                    )
                ]
            )

            NSLayoutConstraint.activateConstraints(
                NSLayoutConstraint.constraintsWithVisualFormat(
                    "H:|-20-[headingLabel]-20-|",
                    options: [],
                    metrics: nil,
                    views: views
                )
            )

            NSLayoutConstraint.activateConstraints(
                NSLayoutConstraint.constraintsWithVisualFormat(
                    "H:|-20-[messageLabel]-20-|",
                    options: [],
                    metrics: nil,
                    views: views
                )
            )

            constraintsA = NSLayoutConstraint.constraintsWithVisualFormat(
                "H:|-20-[actionButton(==0)][dismissButton]-20-|",
                options: [],
                metrics: nil,
                views: views
            )

            constraintsB = NSLayoutConstraint.constraintsWithVisualFormat(
                "H:|-20-[actionButton]-10-[dismissButton(==actionButton)]-20-|",
                options: [],
                metrics: nil,
                views: views
            )

            NSLayoutConstraint.activateConstraints(
                [
                    NSLayoutConstraint(
                        item: dismissButton,
                        attribute: .Height,
                        relatedBy: .Equal,
                        toItem: nil,
                        attribute: .NotAnAttribute,
                        multiplier: 1.0,
                        constant: 55.0
                    ),
                    NSLayoutConstraint(
                        item: actionButton,
                        attribute: .Height,
                        relatedBy: .Equal,
                        toItem: nil,
                        attribute: .NotAnAttribute,
                        multiplier: 1.0,
                        constant: 55.0
                    )
                ]
            )

            NSLayoutConstraint.activateConstraints(
                NSLayoutConstraint.constraintsWithVisualFormat(
                    "V:|-100-[headingLabel]-10-[messageLabel]",
                    options: [],
                    metrics: nil,
                    views: views
                )
            )

            NSLayoutConstraint.activateConstraints(
                NSLayoutConstraint.constraintsWithVisualFormat(
                    "V:[messageLabel]-22-[dismissButton]",
                    options: [],
                    metrics: nil,
                    views: views
                )
            )

            NSLayoutConstraint.activateConstraints(
                NSLayoutConstraint.constraintsWithVisualFormat(
                    "V:[messageLabel]-22-[actionButton]",
                    options: [],
                    metrics: nil,
                    views: views
                )
            )

        }

        @objc private func dismiss() {
            dismissViewControllerAnimated(true, completion: nil)
        }

        @objc private func action() {
            actionClosure?()
        }

        private func activityDidChange() {

            if activity {

                jogShuttleViewController.view.layoutIfNeeded()

                jogShuttleViewController.animateIndefinitelyWithViewToHide(
                    nil,
                    strokeColor: A0Theme.KPCC.LinkColor,
                    completion: nil
                )

                headingLabel.hidden = true
                messageLabel.hidden = true
                dismissButton.hidden = true
                actionButton.hidden = true

            }
            else {

                jogShuttleViewController.endAnimations()

                headingLabel.alpha = 0.0
                messageLabel.alpha = 0.0
                dismissButton.alpha = 0.0
                actionButton.alpha = 0.0

                headingLabel.hidden = false
                messageLabel.hidden = false
                dismissButton.hidden = false
                actionButton.hidden = (actionClosure == nil)

                UIView.animateWithDuration(
                    0.3,
                    delay: 0.3,
                    options: [],
                    animations: {
                        self.headingLabel.alpha = 1.0
                        self.messageLabel.alpha = 1.0
                        self.dismissButton.alpha = 1.0
                        self.actionButton.alpha = 1.0
                    },
                    completion: nil
                )

            }

        }

    }

}

extension AuthenticationViewController {

    override func viewDidLoad() {

        super.viewDidLoad()

        navigationBar.barStyle = .Default
        navigationBar.translucent = false
        navigationBar.barTintColor = UIColor.whiteColor()
        navigationBar.tintColor = UIColor(r: 43, g: 43, b: 43)

        view.backgroundColor = UIColor.whiteColor()

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
                Dispatch.async(delay: 0.3) {
                    [ weak self ] in
                    guard let _self = self else { return }
                    _self.setViewControllers([ messageViewController ], animated: true)
                }
            }
            else {
                dismiss()
            }
        }
        else {
            let messageViewController = MessageViewController(
                heading: "Sorry!",
                message: "An unexpected error occurred.",
                dismissButtonTitle: "Continue"
            )
            setViewControllers([ messageViewController ], animated: true)
        }
    }

    func newLockSignUpViewController() -> A0LockSignUpViewController? {
        let lockSignUpViewController = authenticationManager.newLockSignUpViewController() {
            [ weak self ] success, profile in
            guard let _self = self else { return }
            #if RELEASE
                if success {
                    let method: String
                    if let identity = profile?.identities.first as? A0UserIdentity {
                        method = identity.connection
                    }
                    else {
                        method = "unknown"
                    }
                    Answers.logSignUpWithMethod(method, success: true, customAttributes: [:])
                    AnalyticsManager.shared().logEvent(
                        "signedUp",
                        withParameters: [
                            "method": method,
                            "origin": _self.originForAnalytics
                        ]
                    )
                }
            #endif
            _self.onAuthentication(success)
        }
        if let lockSignUpViewController = lockSignUpViewController {
            let navItem = lockSignUpViewController.navigationItem
            navItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .Cancel,
                target: self,
                action: #selector(cancel)
            )
            navItem.rightBarButtonItem = UIBarButtonItem(
                title: "Log In",
                style: .Plain,
                target: self,
                action: #selector(toggle)
            )
            if let font = UIFont(name: FreightSansPro.Medium.name, size: 19.0) {
                navItem.leftBarButtonItem?.setTitleTextAttributes(
                    [ NSFontAttributeName: font ],
                    forState: .Normal
                )
                navItem.rightBarButtonItem?.setTitleTextAttributes(
                    [ NSFontAttributeName: font ],
                    forState: .Normal
                )
            }
        }
        return lockSignUpViewController
    }

    func newLockViewController() -> A0LockViewController? {
        let lockViewController = authenticationManager.newLockViewController() {
            [ weak self ] success, profile in
            guard let _self = self else { return }
            #if RELEASE
                if success {
                    let method: String
                    if let identity = profile?.identities.first as? A0UserIdentity {
                        method = identity.connection
                    }
                    else {
                        method = "unknown"
                    }
                    Answers.logLoginWithMethod(method, success: true, customAttributes: [:])
                    AnalyticsManager.shared().logEvent(
                        "loggedIn",
                        withParameters: [
                            "method": method,
                            "origin": _self.originForAnalytics
                        ]
                    )
                }
            #endif
            _self.onAuthentication(success)
        }
        if let lockViewController = lockViewController {
            let navItem = lockViewController.navigationItem
            navItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .Cancel,
                target: self,
                action: #selector(cancel)
            )
            navItem.rightBarButtonItem = UIBarButtonItem(
                title: "Sign Up",
                style: .Plain,
                target: self,
                action: #selector(toggle)
            )
            if let font = UIFont(name: FreightSansPro.Medium.name, size: 19.0) {
                navItem.leftBarButtonItem?.setTitleTextAttributes(
                    [ NSFontAttributeName: font ],
                    forState: .Normal
                )
                navItem.rightBarButtonItem?.setTitleTextAttributes(
                    [ NSFontAttributeName: font ],
                    forState: .Normal
                )
            }
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
