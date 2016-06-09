//
//  AuthenticationManager.swift
//  KPCC
//
//  Created by Fuller, Christopher on 6/6/16.
//  Copyright © 2016 Southern California Public Radio. All rights reserved.
//

import Auth0
import Lock
import SimpleKeychain

private let SimpleKeychainService = "Auth0"

extension A0SimpleKeychain {

    private enum Attribute {

        case profile
        case idToken
        case refreshToken

        var key: String {
            switch self {
            case .profile:
                return "profile"
            case .idToken:
                return "id_token"
            case .refreshToken:
                return "refresh_token"
            }
        }

    }

    var profile: A0UserProfile? {
        get {
            if let data = dataForKey(Attribute.profile.key) {
                return NSKeyedUnarchiver.unarchiveObjectWithData(data) as? A0UserProfile
            }
            return nil
        }
        set {
            if let newValue = newValue {
                let data = NSKeyedArchiver.archivedDataWithRootObject(newValue)
                setData(data, forKey: Attribute.profile.key)
            }
            else {
                deleteEntryForKey(Attribute.profile.key)
            }
        }
    }

    var idToken: String? {
        get {
            return stringForKey(Attribute.idToken.key)
        }
        set {
            if let newValue = newValue {
                setString(newValue, forKey: Attribute.idToken.key)
            }
            else {
                deleteEntryForKey(Attribute.idToken.key)
            }
        }
    }

    var refreshToken: String? {
        get {
            return stringForKey(Attribute.refreshToken.key)
        }
        set {
            if let newValue = newValue {
                setString(newValue, forKey: Attribute.refreshToken.key)
            }
            else {
                deleteEntryForKey(Attribute.refreshToken.key)
            }
        }
    }

}

extension A0Theme {

    static func KPCCTheme(bundle bundle: NSBundle) -> A0Theme {

        let theme = A0Theme()

        theme.statusBarStyle = .Default

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

        return theme

    }

}

extension A0UserProfile {

    var metaName: String? {
        return userMetadata["name"] as? String
    }

    var metaPhone: String? {
        return userMetadata["phone"] as? String
    }

    var isMetaNameEmpty: Bool {
        let count = (metaName?.characters.count ?? 0)
        return (count > 0)
    }

    var isMetaPhoneEmpty: Bool {
        let count = (metaPhone?.characters.count ?? 0)
        return (count > 0)
    }

}

@objc class AuthenticationManager: NSObject {

    lazy var theme = A0Theme.sharedInstance()
    lazy var simpleKeychain = A0SimpleKeychain(service: SimpleKeychainService)

    var isAuthenticated: Bool {
        return (userProfile != nil)
    }

    private(set) var auth0: Auth0?
    private(set) var lock: A0Lock?

    private(set) var userProfile: A0UserProfile?

    private override init() {}

}

extension AuthenticationManager {

    static var sharedInstance: AuthenticationManager {
        return _sharedInstance
    }

    private static let _sharedInstance = AuthenticationManager()

}

extension AuthenticationManager {

    func registerTheme(bundle bundle: NSBundle) {

        self.theme.statusBarStyle = .Default

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

    func initialize(clientId clientId: String, domain: String) {
        auth0 = Auth0(domain: domain)
        lock = A0Lock(clientId: clientId, domain: domain)
        if let profile = simpleKeychain.profile, _ = simpleKeychain.idToken, _ = simpleKeychain.refreshToken {
            userProfile = profile
        }
    }

    func newLockViewController(completion: ((Bool) -> Void)) -> A0LockViewController? {
        if let lockVC = lock?.newLockViewController() {
            lockVC.onAuthenticationBlock = {
                [ weak self ] profile, token in
                guard let _self = self, profile = profile, token = token else {
                    completion(false)
                    return
                }
                _self.set(profile: profile, token: token)
                completion(true)
            }
            return lockVC
        }
        return nil
    }

    func refresh(completion: ((Bool) -> Void)) {
        guard let lock = lock, refreshToken = simpleKeychain.refreshToken else {
            completion(false)
            return
        }
        lock.apiClient().fetchNewIdTokenWithRefreshToken(
            refreshToken,
            parameters: nil,
            success: {
                [ weak self ] token in
                guard let _self = self else {
                    completion(false)
                    return
                }
                _self.set(token: token)
                completion(true)
            },
            failure: {
                [ weak self ] _ in
                guard let _self = self else {
                    completion(false)
                    return
                }
                _self.reset()
                completion(false)
            }
        )
    }

    func updateUser(name name: String?, phone: String?, completion: ((Bool) -> Void)) {
        guard let auth0 = auth0, idToken = simpleKeychain.idToken else {
            completion(false)
            return
        }
        auth0.users(idToken).update(
            userMetadata: [
                "name" : (name ?? ""),
                "phone" : (phone ?? "")
            ]
        ).responseJSON {
            [ weak self ] _, payload in
            let success = (payload != nil)
            guard let _self = self else {
                completion(success)
                return
            }
            if success {
                guard let lock = _self.lock else {
                    completion(success)
                    return
                }
                lock.apiClient().fetchUserProfileWithIdToken(
                    idToken,
                    success: {
                        [ weak self ] profile in
                        guard let _self = self else {
                            completion(success)
                            return
                        }
                        _self.set(profile: profile)
                        completion(success)
                    },
                    failure: {
                        _ in
                        completion(success)
                    }
                )
            }
            else {
                completion(success)
            }
        }
    }

    func reset() {
        set(profile: nil, token: nil)
    }

}

extension AuthenticationManager {

    private func set(profile profile: A0UserProfile?, token: A0Token?) {
        set(profile: profile)
        set(token: token)
    }

    private func set(profile profile: A0UserProfile?) {
        userProfile = profile
        simpleKeychain.profile = profile
    }

    private func set(token token: A0Token?) {
        simpleKeychain.idToken = token?.idToken
        simpleKeychain.refreshToken = token?.refreshToken
    }

}
