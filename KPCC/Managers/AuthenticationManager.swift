//
//  AuthenticationManager.swift
//  KPCC
//
//  Created by Fuller, Christopher on 6/6/16.
//  Copyright © 2016 Southern California Public Radio. All rights reserved.
//

import Lock

@objc class AuthenticationManager: NSObject {

    static let sharedInstance = AuthenticationManager()

    lazy var theme = A0Theme.sharedInstance()

    var lock: A0Lock?
    var userProfile: A0UserProfile?

    private override init() {}

    func registerTheme(bundle bundle: NSBundle) {

        let theme = A0Theme()

        theme.registerColor(
            UIColor(r: 49, g: 171, b: 212),
            forKey: A0ThemePrimaryButtonNormalColor
        )

        theme.registerColor(
            UIColor(r: 0, g: 115, b: 151),
            forKey: A0ThemePrimaryButtonHighlightedColor
        )

        if let font = UIFont(name: FreightSansPro.Semibold.name, size: 18.0) {
            theme.registerFont(font, forKey: A0ThemePrimaryButtonFont)
        }

        theme.registerColor(
            UIColor.whiteColor(),
            forKey: A0ThemePrimaryButtonTextColor
        )

        theme.registerColor(
            UIColor.clearColor(),
            forKey: A0ThemeSecondaryButtonBackgroundColor
        )

        if let font = UIFont(name: FreightSansPro.Book.name, size: 16.0) {
            theme.registerFont(font, forKey: A0ThemeSecondaryButtonFont)
        }

        theme.registerColor(
            UIColor(r: 49, g: 171, b: 212),
            forKey: A0ThemeSecondaryButtonTextColor
        )

        if let font = UIFont(name: FreightSansPro.Book.name, size: 16.0) {
            theme.registerFont(font, forKey: A0ThemeTextFieldFont)
        }

        theme.registerColor(
            UIColor(r: 133, g: 133, b: 133),
            forKey: A0ThemeTextFieldTextColor
        )

        theme.registerColor(
            UIColor(r: 155, g: 165, b: 169),
            forKey: A0ThemeTextFieldPlaceholderTextColor
        )

        theme.registerColor(
            UIColor(r: 49, g: 171, b: 212),
            forKey: A0ThemeTextFieldIconColor
        )

        if let font = UIFont(name: FreightSansPro.Book.name, size: 27.0) {
            theme.registerFont(font, forKey: A0ThemeTitleFont)
        }

        theme.registerColor(
            UIColor(r: 248, g: 126, b: 33),
            forKey: A0ThemeTitleTextColor
        )

        if let font = UIFont(name: FreightSansPro.Book.name, size: 17.0) {
            theme.registerFont(font, forKey: A0ThemeDescriptionFont)
        }

        theme.registerColor(
            UIColor(r: 108, g: 117, b: 121),
            forKey: A0ThemeDescriptionTextColor
        )

        theme.registerColor(
            UIColor(r: 242, g: 242, b: 242),
            forKey: A0ThemeScreenBackgroundColor
        )

        theme.registerImageWithName(
            "KPCCLogo30",
            bundle: bundle,
            forKey: A0ThemeIconImageName
        )

        theme.registerColor(
            UIColor(r: 247, g: 247, b: 247),
            forKey: A0ThemeIconBackgroundColor
        )

        if let font = UIFont(name: FreightSansPro.Medium.name, size: 14.0) {
            theme.registerFont(font, forKey: A0ThemeSeparatorTextFont)
        }

        theme.registerColor(
            UIColor(r: 108, g: 117, b: 121),
            forKey: A0ThemeSeparatorTextColor
        )

        theme.registerColor(
            UIColor(r: 201, g: 213, b: 216),
            forKey: A0ThemeCredentialBoxBorderColor
        )

        theme.registerColor(
            UIColor(r: 201, g: 213, b: 216),
            forKey: A0ThemeCredentialBoxSeparatorColor
        )

        theme.registerColor(
            UIColor(r: 242, g: 242, b: 242),
            forKey: A0ThemeCredentialBoxBackgroundColor
        )

        self.theme.registerTheme(theme)

    }

    func initializeLock(clientId clientId: String, domain: String) {
        lock = A0Lock(clientId: clientId, domain: domain)
    }

}
