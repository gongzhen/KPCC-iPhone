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
        if let alertController = presentedViewController as? UIAlertController {
            AuthenticationManager.validateUserProfileAlertController(alertController)
        }
    }

    func logInTapped(sender: AnyObject) {
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

    func logOutTapped(sender: AnyObject) {

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
        return 3
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
                title: "Log Out",
                style: .Plain,
                target: self,
                action: #selector(logOutTapped)
            )
        }
        else {
            navigationItem.rightBarButtonItem = UIBarButtonItem(
                title: "Log In",
                style: .Plain,
                target: self,
                action: #selector(logInTapped)
            )
        }
        tableView.reloadData()
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
