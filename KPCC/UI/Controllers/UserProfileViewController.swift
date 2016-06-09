//
//  UserProfileViewController.swift
//  KPCC
//
//  Created by Fuller, Christopher on 6/6/16.
//  Copyright © 2016 Southern California Public Radio. All rights reserved.
//

import UIKit
import Lock

class Value1TableViewCell: UITableViewCell {

    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: .Value1, reuseIdentifier: reuseIdentifier)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

}

class UserProfileViewController: UITableViewController {

    lazy var authenticationManager = AuthenticationManager.sharedInstance

    override func viewDidLoad() {

        super.viewDidLoad()

        tableView.registerClass(
            Value1TableViewCell.self,
            forCellReuseIdentifier: String(Value1TableViewCell)
        )

        navigationItem.title = "Profile"

    }

    override func viewWillAppear(animated: Bool) {

        super.viewWillAppear(animated)

        updateUI()

    }

    override func viewDidAppear(animated: Bool) {

        super.viewDidAppear(animated)

        if let userProfile = authenticationManager.userProfile where authenticationManager.isAuthenticated {
            if (userProfile.metadataName?.isEmpty ?? true) || (userProfile.metadataPhone?.isEmpty ?? true) {
                promptForNameAndPhone()
            }
        }

    }

    func textFieldEditingChanged(sender: AnyObject) {
        if let alertController = presentedViewController as? UIAlertController {
            if let defaultAction = alertController.actions.last {
                let name = alertController.textFields?.first?.text
                let phone = alertController.textFields?.last?.text
                let nameEmpty = (name?.isEmpty ?? true)
                let phoneValid = (phone?.isPhoneNumber ?? false)
                defaultAction.enabled = (!nameEmpty && phoneValid)
            }
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

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 3
    }

    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(String(Value1TableViewCell))!
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

    private func updateUI() {
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

    private func promptForNameAndPhone() {
        let alertController = UIAlertController(
            title: "One More Thing",
            message: "If you ever win a contest or drawing, we'll need to contact you quickly.",
            preferredStyle: .Alert
        )
        alertController.addTextFieldWithConfigurationHandler {
            [ weak self ] textField in
            guard let _self = self else { return }
            textField.placeholder = "First and Last Name"
            textField.text = _self.authenticationManager.userProfile?.metadataName
            textField.addTarget(
                self,
                action: #selector(_self.textFieldEditingChanged),
                forControlEvents: .EditingChanged
            )
        }
        alertController.addTextFieldWithConfigurationHandler {
            [ weak self ] textField in
            guard let _self = self else { return }
            textField.placeholder = "Phone Number"
            textField.text = _self.authenticationManager.userProfile?.metadataPhone
            textField.addTarget(
                self,
                action: #selector(_self.textFieldEditingChanged),
                forControlEvents: .EditingChanged
            )
        }
        alertController.addAction(
            UIAlertAction(
                title: "Cancel",
                style: .Cancel,
                handler: nil
            )
        )
        let defaultAction = UIAlertAction(
            title: "Submit",
            style: .Default,
            handler: {
                [ weak self ] _ in
                guard let _self = self else { return }
                let name = alertController.textFields?.first?.text
                let phone = alertController.textFields?.last?.text
                _self.authenticationManager.updateUserProfile(name: name, phone: phone) {
                    [ weak self ] _ in
                    guard let _self = self else { return }
                    _self.updateUI()
                }
            }
        )
        defaultAction.enabled = false
        alertController.addAction(defaultAction)
        presentViewController(alertController, animated: true, completion: nil)
    }

}
