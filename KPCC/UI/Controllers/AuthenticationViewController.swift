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

    lazy var lockSignUpViewController: A0LockSignUpViewController? = {
        [ unowned self ] in
        let lockSignUpViewController = self.authenticationManager.newLockSignUpViewController() {
            [ weak self ] _ in
            guard let _self = self else { return }
            _self.dismiss()
        }
        if let lockSignUpViewController = lockSignUpViewController {
            lockSignUpViewController.navigationItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .Cancel,
                target: self,
                action: #selector(dismiss)
            )
            lockSignUpViewController.navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Log In",
                style: .Plain,
                target: self,
                action: #selector(showLockViewController)
            )
        }
        return lockSignUpViewController
    }()

    lazy var lockViewController: A0LockViewController? = {
        [ unowned self ] in
        let lockViewController = self.authenticationManager.newLockViewController() {
            [ weak self ] _ in
            guard let _self = self else { return }
            _self.dismiss()
        }
        if let lockViewController = lockViewController {
            lockViewController.navigationItem.leftBarButtonItem = UIBarButtonItem(
                barButtonSystemItem: .Cancel,
                target: self,
                action: #selector(dismiss)
            )
            lockViewController.navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Sign Up",
                style: .Plain,
                target: self,
                action: #selector(showLockSignUpViewController)
            )
        }
        return lockViewController
    }()

}

extension AuthenticationViewController {

    override func viewDidLoad() {

        super.viewDidLoad()

        view.backgroundColor = A0Theme.KPCCTheme().colorForKey(A0ThemeScreenBackgroundColor)

        navigationBar.barStyle = .Default
        navigationBar.translucent = false
        navigationBar.barTintColor = view.backgroundColor

    }

}

extension AuthenticationViewController {

    func showLockSignUpViewController() {
        if let lockSignUpViewController = lockSignUpViewController {
            hideKeyboard()
            viewControllers = [ lockSignUpViewController ]
        }
    }

    func showLockViewController() {
        if let lockViewController = lockViewController {
            hideKeyboard()
            viewControllers = [ lockViewController ]
        }
    }

    func dismiss() {
        hideKeyboard()
        dismissViewControllerAnimated(true, completion: nil)
    }

}

private extension AuthenticationViewController {

    func hideKeyboard() {
        if let viewController = topViewController {
            let selector = NSSelectorFromString("hideKeyboard:")
            if viewController.respondsToSelector(selector) {
                viewController.performSelector(selector, withObject: nil)
            }
        }
    }

}
