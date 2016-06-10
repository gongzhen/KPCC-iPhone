//
//  UserProfileViewController.swift
//  KPCC
//
//  Created by Fuller, Christopher on 6/6/16.
//  Copyright © 2016 Southern California Public Radio. All rights reserved.
//

import UIKit
import Lock

class UserProfileViewController: UITableViewController {

    lazy var authenticationManager = AuthenticationManager.sharedInstance

}

extension UserProfileViewController {

    override func viewDidLoad() {

        super.viewDidLoad()

        tableView.registerClass(style: .Value1)

        navigationItem.title = "Profile"

        let button = UIButton(type: .System)

        button.frame = CGRect(x: 0.0, y: 0.0, width: tableView.frame.width, height: 48.0)
        button.backgroundColor = UIColor(white: 0.95, alpha: 1.0)

        button.addTarget(
            self,
            action: #selector(toggleAuthenticationButtonTapped),
            forControlEvents: .TouchUpInside
        )

        tableView.tableFooterView = button

    }

    override func viewWillAppear(animated: Bool) {

        super.viewWillAppear(animated)

        updateUI()

    }

    override func viewDidAppear(animated: Bool) {

        super.viewDidAppear(animated)

        if authenticationManager.isAuthenticated {
            let userProfileComplete = (authenticationManager.userProfile?.isComplete ?? false)
            if (!userProfileComplete) {
                presentUserProfileAlertController()
            }
        }

    }

}

extension UserProfileViewController {

    func textFieldEditingChanged(sender: AnyObject) {
        if let textField = sender as? UITextField, alertController = textField.alertController {
            AuthenticationManager.validateUserProfileAlertController(alertController)
        }
    }

    func toggleAuthenticationButtonTapped(sender: AnyObject) {
        authenticationManager.isAuthenticated ? logOut() : logIn()
    }

    func editButtonTapped(sender: AnyObject) {
        presentUserProfileAlertController()
    }

}

extension UserProfileViewController {

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return authenticationManager.isAuthenticated ? 3 : 0
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(style: .Value1)
        if let userProfile = authenticationManager.userProfile {
            switch indexPath.row {
            case 0:
                cell.textLabel?.text = "Email"
                cell.detailTextLabel?.text = userProfile.email
            case 1:
                cell.textLabel?.text = "Name"
                cell.detailTextLabel?.text = userProfile.metadataName
            case 2:
                cell.textLabel?.text = "Phone"
                cell.detailTextLabel?.text = userProfile.metadataPhone
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
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Edit",
                style: .Plain,
                target: self,
                action: #selector(editButtonTapped)
            )
        }
        else {
            navigationItem.rightBarButtonItem = nil
        }

        if let button = tableView.tableFooterView as? UIButton {
            let title = (authenticationManager.isAuthenticated ? "Log Out" : "Log In")
            button.setTitle(title, forState: .Normal)
        }

        tableView.reloadData()

    }

    func logIn() {
        let lockVC = authenticationManager.newLockViewController() {
            [ weak self ] _ in
            guard let _self = self else { return }
            _self.dismissViewControllerAnimated(true, completion: nil)
        }
        if let lockVC = lockVC {
            lockVC.closable = true
            presentViewController(lockVC, animated: true, completion: nil)
        }
    }

    func logOut() {

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

    func presentUserProfileAlertController() {
        let action = #selector(textFieldEditingChanged)
        let alertController = authenticationManager.newUserProfileAlertController(target: self, action: action) {
            [ weak self ] _ in
            guard let _self = self else { return }
            _self.updateUI()
        }
        presentViewController(alertController, animated: true, completion: nil)
    }

}
