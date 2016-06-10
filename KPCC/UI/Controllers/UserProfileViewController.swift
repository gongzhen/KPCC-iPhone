//
//  UserProfileViewController.swift
//  KPCC
//
//  Created by Fuller, Christopher on 6/6/16.
//  Copyright © 2016 Southern California Public Radio. All rights reserved.
//

import UIKit

class UserProfileViewController: UITableViewController {

    lazy var authenticationManager = AuthenticationManager.sharedInstance

}

extension UserProfileViewController {

    override func viewDidLoad() {

        super.viewDidLoad()

        tableView.registerClass(style: .Value1)

        navigationItem.title = "Profile"

    }

    override func viewWillAppear(animated: Bool) {

        super.viewWillAppear(animated)

        updateUI()

    }

}

extension UserProfileViewController {

    func dismissViewController(sender: AnyObject) {
        dismissViewControllerAnimated(true, completion: nil)
    }

}

extension UserProfileViewController {

    func signUp(sender: AnyObject) {
        presentAuthenticationViewControllers(initialViewControllerIndex: 0)
    }

    func logIn(sender: AnyObject) {
        presentAuthenticationViewControllers(initialViewControllerIndex: 1)
    }

    func logOut(sender: AnyObject) {

        let alertController = UIAlertController(
            title: nil,
            message: nil,
            preferredStyle: .ActionSheet
        )

        alertController.addAction(
            UIAlertAction(
                title: "Log Out",
                style: .Destructive,
                handler: {
                    [ weak self ] _ in
                    guard let _self = self else { return }
                    _self.authenticationManager.reset()
                    _self.updateUI()
                }
            )
        )

        alertController.addAction(
            UIAlertAction(
                title: "Cancel",
                style: .Cancel,
                handler: nil
            )
        )

        presentViewController(alertController, animated: true, completion: nil)

    }

}

extension UserProfileViewController {

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return authenticationManager.isAuthenticated ? 1 : 0
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(style: .Value1)
        if let userProfile = authenticationManager.userProfile {
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "Email"
                cell.detailTextLabel?.text = userProfile.email
            default:
                cell.textLabel?.text = nil
                cell.detailTextLabel?.text = nil
            }
        }
        else {
            cell.textLabel?.text = nil
            cell.detailTextLabel?.text = nil
        }
        return cell
    }

}

private extension UserProfileViewController {

    func updateUI() {
        if authenticationManager.isAuthenticated {
            tableView.tableHeaderView = nil
            tableView.tableFooterView = tableHeaderFooterViewButton(
                title: "Log Out",
                action: #selector(logOut)
            )
        }
        else {
            tableView.tableHeaderView = tableHeaderFooterViewButton(
                title: "Sign Up",
                action: #selector(signUp)
            )
            tableView.tableFooterView = tableHeaderFooterViewButton(
                title: "Log In",
                action: #selector(logIn)
            )
        }
        tableView.reloadData()
    }

    func tableHeaderFooterViewButton(title title: String, action: Selector) -> UIButton {
        let button = UIButton(type: .System)
        button.frame = CGRect(x: 0.0, y: 0.0, width: tableView.frame.width, height: 48.0)
        button.backgroundColor = UIColor(white: 0.95, alpha: 1.0)
        button.setTitle(title, forState: .Normal)
        button.addTarget(self, action: action, forControlEvents: .TouchUpInside)
        return button
    }

    func presentAuthenticationViewControllers(initialViewControllerIndex selectedSegmentIndex: Int) {

        let signUpVC = authenticationManager.newSignUpViewController() {
            [ weak self ] _ in
            guard let _self = self else { return }
            _self.dismissViewController(_self)
        }

        let lockVC = authenticationManager.newLockViewController() {
            [ weak self ] _ in
            guard let _self = self else { return }
            _self.dismissViewController(_self)
        }

        if let signUpVC = signUpVC, lockVC = lockVC {

            signUpVC.navigationItem.title = "Sign Up"
            lockVC.navigationItem.title = "Log In"

            let segmentedVC = SegmentedViewController()

            segmentedVC.navigationItem.leftBarButtonItem = UIBarButtonItem(
                title: "Close",
                style: .Plain,
                target: self,
                action: #selector(dismissViewController)
            )

            segmentedVC.view.backgroundColor = UIColor(r: 242, g: 242, b: 242)
            segmentedVC.viewControllers = [ signUpVC, lockVC ]
            segmentedVC.selectedSegmentIndex = selectedSegmentIndex

            let navigationController = UINavigationController(rootViewController: segmentedVC)

            navigationController.navigationBar.translucent = false
            navigationController.navigationBar.barTintColor = segmentedVC.view.backgroundColor

            presentViewController(navigationController, animated: true, completion: nil)

        }

    }

}
