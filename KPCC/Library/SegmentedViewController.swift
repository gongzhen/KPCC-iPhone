//
//  SegmentedViewController.swift
//  KPCC
//
//  Created by Fuller, Christopher on 6/9/16.
//  Copyright © 2016 Southern California Public Radio. All rights reserved.
//

import UIKit

struct NavigationItemAttributes: OptionSetType {

    let rawValue: UInt

    static let None               = NavigationItemAttributes(rawValue: 0)
    static let Title              = NavigationItemAttributes(rawValue: 1 << 0)
    static let TitleView          = NavigationItemAttributes(rawValue: 1 << 1)
    static let BackBarButtonItem  = NavigationItemAttributes(rawValue: 1 << 2)
    static let LeftBarButtonItem  = NavigationItemAttributes(rawValue: 1 << 3)
    static let RightBarButtonItem = NavigationItemAttributes(rawValue: 1 << 4)

    static let All: NavigationItemAttributes = [
        .Title,
        .TitleView,
        .BackBarButtonItem,
        .LeftBarButtonItem,
        .RightBarButtonItem
    ]

}

protocol SegmentViewController {

    func navigationItemAttributes() -> NavigationItemAttributes

}

class SegmentedViewController: UIViewController {

    var viewControllers: [UIViewController] {
        get {
            return childViewControllers
        }
        set {
            removeAllViewControllers()
            for viewController in newValue {
                addViewController(viewController, animated: false)
            }
            selectedSegmentIndex = (newValue.isEmpty ? -1 : 0)
        }
    }

    var selectedSegmentIndex: Int {
        get {
            return segmentedControl.selectedSegmentIndex
        }
        set {
            if newValue != segmentedControl.selectedSegmentIndex {
                segmentedControl.selectedSegmentIndex = newValue
                segmentedControlValueChanged(segmentedControl)
            }
        }
    }

    private(set) var selectedViewController: UIViewController? {
        didSet {
            if selectedViewController !== oldValue {
                setNeedsStatusBarAppearanceUpdate()
                updateNavigationItemAttributes()
            }
        }
    }

    private var segmentedControl = UISegmentedControl(items: nil)
    private var containerView = UIView(frame: CGRectZero)

}

extension SegmentedViewController {

    override func childViewControllerForStatusBarStyle() -> UIViewController? {
        return selectedViewController
    }

    override func viewDidLoad() {

        super.viewDidLoad()

        edgesForExtendedLayout = [ .Left, .Right, .Bottom ]

        view.backgroundColor = UIColor.whiteColor()

        segmentedControl.addTarget(
            self,
            action: #selector(segmentedControlValueChanged),
            forControlEvents: .ValueChanged
        )

    }

    override func viewWillAppear(animated: Bool) {

        super.viewWillAppear(animated)

        segmentedControl.removeFromSuperview()
        containerView.removeFromSuperview()

        let margin: CGFloat = 4.0

        segmentedControl.frame = CGRect(
            x: margin,
            y: margin,
            width: view.frame.width - (margin * 2.0),
            height: segmentedControl.frame.height
        )

        let y = (segmentedControl.frame.height + (margin * 2.0))

        containerView.frame = CGRect(
            x: 0.0,
            y: y,
            width: view.frame.width,
            height: view.frame.height - y
        )

        view.addSubview(segmentedControl)
        view.addSubview(containerView)

    }

}

extension SegmentedViewController {

    func navigationItemAttributes() -> NavigationItemAttributes {
        return .All
    }

    func addViewController(viewController: UIViewController, animated: Bool) {
        let title = (viewController.title ?? viewController.navigationItem.title)
        let index = childViewControllers.count
        segmentedControl.insertSegmentWithTitle(title, atIndex: index, animated: animated)
        viewController.willMoveToParentViewController(self)
        addChildViewController(viewController)
    }

    func removeViewController(viewController: UIViewController, animated: Bool) {
        if let index = childViewControllers.indexOf(viewController) {
            viewController.view.removeFromSuperview()
            viewController.willMoveToParentViewController(nil)
            viewController.removeFromParentViewController()
            segmentedControl.removeSegmentAtIndex(index, animated: animated)
        }
    }

    func removeAllViewControllers() {
        for childViewController in childViewControllers {
            removeViewController(childViewController, animated: false)
        }
    }

}

private extension SegmentedViewController {

    @objc func segmentedControlValueChanged(sender: AnyObject) {
        if let selectedVC = selectedViewController {
            selectedVC.view.removeFromSuperview()
        }
        if selectedSegmentIndex >= 0 {
            selectedViewController = childViewControllers[selectedSegmentIndex]
        }
        else {
            selectedViewController = nil
        }
        if let selectedVC = selectedViewController {
            selectedVC.view.frame = containerView.bounds
            containerView.addSubview(selectedVC.view)
        }

    }

    func updateNavigationItemAttributes() {

        if navigationItemAttributes().contains(.Title) {
            if let selectedVC = selectedViewController {
                if let segmentVC = selectedVC as? SegmentViewController {
                    if segmentVC.navigationItemAttributes().contains(.Title) {
                        navigationItem.title = selectedVC.navigationItem.title
                    }
                }
            }
            else {
                navigationItem.title = nil
            }
        }

        if navigationItemAttributes().contains(.TitleView) {
            if let selectedVC = selectedViewController {
                if let segmentVC = selectedVC as? SegmentViewController {
                    if segmentVC.navigationItemAttributes().contains(.TitleView) {
                        navigationItem.titleView = selectedVC.navigationItem.titleView
                    }
                }
            }
            else {
                navigationItem.titleView = nil
            }
        }

        if navigationItemAttributes().contains(.BackBarButtonItem) {
            if let selectedVC = selectedViewController {
                if let segmentVC = selectedVC as? SegmentViewController {
                    if segmentVC.navigationItemAttributes().contains(.BackBarButtonItem) {
                        navigationItem.backBarButtonItem = selectedVC.navigationItem.backBarButtonItem
                    }
                }
            }
            else {
                navigationItem.backBarButtonItem = nil
            }
        }

        if navigationItemAttributes().contains(.LeftBarButtonItem) {
            if let selectedVC = selectedViewController {
                if let segmentVC = selectedVC as? SegmentViewController {
                    if segmentVC.navigationItemAttributes().contains(.LeftBarButtonItem) {
                        navigationItem.leftBarButtonItem = selectedVC.navigationItem.leftBarButtonItem
                    }
                }
            }
            else {
                navigationItem.leftBarButtonItem = nil
            }
        }

        if navigationItemAttributes().contains(.RightBarButtonItem) {
            if let selectedVC = selectedViewController {
                if let segmentVC = selectedVC as? SegmentViewController {
                    if segmentVC.navigationItemAttributes().contains(.RightBarButtonItem) {
                        navigationItem.rightBarButtonItem = selectedVC.navigationItem.rightBarButtonItem
                    }
                }
            }
            else {
                navigationItem.rightBarButtonItem = nil
            }
        }

    }

}
