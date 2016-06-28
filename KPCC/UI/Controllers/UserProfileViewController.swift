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

    @IBOutlet var loggedOutView: UIView!
    @IBOutlet var loggedInView: UIView!

    @IBOutlet weak var emailAddress: UILabel!

    private let blurredImageView = UIImageView()

    private lazy var authenticationMessageViewController = AuthenticationViewController.MessageViewController(
        heading: "Success!",
        message: "You're logged in. Now, back to the app.",
        buttonTitle: "Go to your profile"
    )

    init() {
        super.init(nibName: String(UserProfileViewController), bundle: nil)
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }

}

extension UserProfileViewController {

    override func viewDidLoad() {

        super.viewDidLoad()

        loggedOutView.autoresizingMask = [ .FlexibleWidth, .FlexibleHeight ]
        loggedInView.autoresizingMask = [ .FlexibleWidth, .FlexibleHeight ]

        loggedOutView.frame = view.bounds
        loggedInView.frame = view.bounds

        view.addSubview(loggedOutView)
        view.addSubview(loggedInView)

        navigationItem.title = "Your Profile"

        tableView.scrollEnabled = false

        blurredImageView.frame = view.bounds
        blurredImageView.alpha = 0.65
        blurredImageView.image = DesignManager.shared().currentBlurredLiveImage

        tableView.backgroundView = blurredImageView

    }

    override func viewWillAppear(animated: Bool) {

        super.viewWillAppear(animated)

        updateUI()

    }

}

extension UserProfileViewController {

    @IBAction func signUp(sender: AnyObject) {
        let authenticationViewController = AuthenticationViewController()
        authenticationViewController.defaultAuthenticationMode = .SignUp
        authenticationViewController.messageViewController = authenticationMessageViewController
        presentViewController(authenticationViewController, animated: true, completion: nil)
    }

    @IBAction func logIn(sender: AnyObject) {
        let authenticationViewController = AuthenticationViewController()
        authenticationViewController.defaultAuthenticationMode = .LogIn
        authenticationViewController.messageViewController = authenticationMessageViewController
        presentViewController(authenticationViewController, animated: true, completion: nil)
    }

    @IBAction func logOut(sender: AnyObject) {

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

    @IBAction func contactUs(sender: AnyObject) {
        authenticationManager.presentMailComposeViewController(presentFrom: self)
    }

}

extension UserProfileViewController {

    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 0
    }

    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return 0
    }

}

private extension UserProfileViewController {

    func updateUI() {
        if authenticationManager.isAuthenticated {
            loggedOutView.hidden = true
            loggedInView.hidden = false
        }
        else {
            loggedOutView.hidden = false
            loggedInView.hidden = true
        }
        Dispatch.async {
            [ weak self ] in
            guard let _self = self else { return }
            let email = _self.authenticationManager.userProfile?.email
            if let email = email {
                _self.emailAddress.text = email
                _self.emailAddress.textColor = UIColor.whiteColor()
            }
            else {
                _self.emailAddress.text = "No Email Address Provided"
                _self.emailAddress.textColor = UIColor.lightGrayColor()
            }
        }
    }

}
