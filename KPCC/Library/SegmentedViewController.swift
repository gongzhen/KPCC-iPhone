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
        willSet {
            cacheNavigationItemAttributes()
        }
        didSet {
            if selectedViewController !== oldValue {
                setNeedsStatusBarAppearanceUpdate()
                updateNavigationItemAttributes()
            }
        }
    }

    private var segmentedControl = UISegmentedControl(items: nil)
    private var containerView = UIView(frame: CGRectZero)

    private var cachedTitle: String?
    private var cachedTitleView: UIView?
    private var cachedBackBarButtonItem: UIBarButtonItem?
    private var cachedLeftBarButtonItem: UIBarButtonItem?
    private var cachedRightBarButtonItem: UIBarButtonItem?

    deinit {
        stopObservingUpdateInterfaceNotification()
    }

}

extension SegmentedViewController: UpdateInterfaceNotification {

    func updateInterface(notification: NSNotification) {

        let margin: CGFloat = 4.0

        let segmentedControlFrame = CGRect(
            x: margin,
            y: margin,
            width: view.frame.width - (margin * 2.0),
            height: segmentedControl.frame.height
        )

        segmentedControl.hidden = (viewControllers.count < 2)

        let containerViewFrame: CGRect

        if segmentedControl.hidden {
            containerViewFrame = view.bounds
        }
        else {
            let y = (segmentedControl.frame.height + (margin * 2.0))
            containerViewFrame = CGRect(
                x: 0.0,
                y: y,
                width: view.frame.width,
                height: view.frame.height - y
            )
        }

        let segmentedControlFrameChanged = (segmentedControlFrame != segmentedControl.frame)
        let containerViewFrameChanged = (containerViewFrame != containerView.frame)

        if segmentedControlFrameChanged || containerViewFrameChanged {

            segmentedControl.removeFromSuperview()
            containerView.removeFromSuperview()

            segmentedControl.frame = segmentedControlFrame
            containerView.frame = containerViewFrame

            view.addSubview(segmentedControl)
            view.addSubview(containerView)

        }

    }

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

        startObservingUpdateInterfaceNotification()

    }

    override func viewWillAppear(animated: Bool) {

        super.viewWillAppear(animated)

        setNeedsUpdateInterface()

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
        setNeedsUpdateInterface()
    }

    func removeViewController(viewController: UIViewController, animated: Bool) {
        if let index = childViewControllers.indexOf(viewController) {
            viewController.view.removeFromSuperview()
            viewController.willMoveToParentViewController(nil)
            viewController.removeFromParentViewController()
            segmentedControl.removeSegmentAtIndex(index, animated: animated)
            setNeedsUpdateInterface()
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

    func cacheNavigationItemAttributes() {

        let selectedItem = selectedViewController?.navigationItem

        if navigationItem.title != selectedItem?.title {
            cachedTitle = navigationItem.title
        }

        if navigationItem.titleView != selectedItem?.titleView {
            cachedTitleView = navigationItem.titleView
        }

        if navigationItem.backBarButtonItem != selectedItem?.backBarButtonItem {
            cachedBackBarButtonItem = navigationItem.backBarButtonItem
        }

        if navigationItem.leftBarButtonItem != selectedItem?.leftBarButtonItem {
            cachedLeftBarButtonItem = navigationItem.leftBarButtonItem
        }

        if navigationItem.rightBarButtonItem != selectedItem?.rightBarButtonItem {
            cachedRightBarButtonItem = navigationItem.rightBarButtonItem
        }

    }

    func updateNavigationItemAttributes() {

        var title: String? = cachedTitle
        var titleView: UIView? = cachedTitleView
        var backBarButtonItem: UIBarButtonItem? = cachedBackBarButtonItem
        var leftBarButtonItem: UIBarButtonItem? = cachedLeftBarButtonItem
        var rightBarButtonItem: UIBarButtonItem? = cachedRightBarButtonItem

        if let selectedVC = selectedViewController, segmentVC = selectedVC as? SegmentViewController {

            let attributes = segmentVC.navigationItemAttributes()

            if attributes.contains(.Title) {
                title = selectedVC.navigationItem.title
            }

            if attributes.contains(.TitleView) {
                titleView = selectedVC.navigationItem.titleView
            }

            if attributes.contains(.BackBarButtonItem) {
                backBarButtonItem = selectedVC.navigationItem.backBarButtonItem
            }

            if attributes.contains(.LeftBarButtonItem) {
                leftBarButtonItem = selectedVC.navigationItem.leftBarButtonItem
            }

            if attributes.contains(.RightBarButtonItem) {
                rightBarButtonItem = selectedVC.navigationItem.rightBarButtonItem
            }

        }

        let attributes = navigationItemAttributes()

        if attributes.contains(.Title) {
            navigationItem.title = title
        }

        if attributes.contains(.TitleView) {
            navigationItem.titleView = titleView
        }

        if attributes.contains(.BackBarButtonItem) {
            navigationItem.backBarButtonItem = backBarButtonItem
        }

        if attributes.contains(.LeftBarButtonItem) {
            navigationItem.leftBarButtonItem = leftBarButtonItem
        }

        if attributes.contains(.RightBarButtonItem) {
            navigationItem.rightBarButtonItem = rightBarButtonItem
        }

    }

}
