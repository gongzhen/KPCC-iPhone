// A0GoogleProvider.m
//
// Copyright (c) 2015 Auth0 (http://auth0.com)
//
// Permission is hereby granted, free of charge, to any person obtaining a copy
// of this software and associated documentation files (the "Software"), to deal
// in the Software without restriction, including without limitation the rights
// to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
// copies of the Software, and to permit persons to whom the Software is
// furnished to do so, subject to the following conditions:
//
// The above copyright notice and this permission notice shall be included in
// all copies or substantial portions of the Software.
//
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
// IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
// FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
// AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
// LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
// OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
// THE SOFTWARE.

#import "A0GoogleProvider.h"
#import <Google/SignIn.h>
#import <Lock/A0Errors.h>

#define A0LogError(fmt, ...)
#define A0LogVerbose(fmt, ...)
#define A0LogDebug(fmt, ...)

@interface A0GoogleProvider () <GIDSignInDelegate, GIDSignInUIDelegate>
@property (strong, nonatomic) GIDSignIn *authentication;
@property (copy, nonatomic) A0GoogleAuthentication onAuthentication;
@property (assign, nonatomic) BOOL authenticating;
@end

@implementation A0GoogleProvider

- (instancetype)initWithScopes:(NSArray *)scopes {
    GIDSignIn *authentication = [GIDSignIn sharedInstance];
    return [self initWithAuthentication:authentication scopes:scopes];
}

- (instancetype)initWithClientId:(NSString *)clientId scopes:(NSArray *)scopes {
    GIDSignIn *authentication = [GIDSignIn sharedInstance];
    return [self initWithAuthentication:authentication clientId:clientId scopes:scopes];
}

- (instancetype)initWithAuthentication:(GIDSignIn *)authentication clientId:(NSString *)clientId scopes:(NSArray *)scopes {
    authentication.clientID = clientId;
    return [self initWithAuthentication:authentication scopes:scopes];
}

- (instancetype)initWithAuthentication:(GIDSignIn *)authentication scopes:(NSArray *)scopes {
    self = [super init];
    if (self) {
        authentication.scopes = scopes;
        authentication.delegate = self;
        authentication.uiDelegate = self;
        authentication.allowsSignInWithWebView = YES;
        _authentication = authentication;
        _onAuthentication = ^(NSError *error, NSString *token) {};
        _authenticating = NO;
    }
    return self;
}

- (void)authenticateWithScopes:(nullable NSArray *)scopes callback:(A0GoogleAuthentication __nonnull)callback {
    if (scopes.count > 0) {
        self.authentication.scopes = scopes;
    }
    self.authentication.serverClientID = self.serverClientId;
    self.onAuthentication = callback;
    A0LogVerbose(@"Authenticating with Google with clientId %@, scopes %@", self.authentication.clientID, self.authentication.scopes);
    [self.authentication signIn];
}

- (void)cancelAuthentication {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.authenticating) {
            return;
        }
        A0GoogleAuthentication callback = self.onAuthentication;
        self.onAuthentication = ^(NSError *error, NSString *token) {};
        callback([A0Errors googleplusCancelled], nil);
    });
}

- (BOOL)handleURL:(NSURL * __nonnull)url sourceApplication:(NSString * __nonnull)sourceApplication {
    self.authenticating = [self.authentication handleURL:url sourceApplication:sourceApplication annotation:nil];
    return self.authenticating;
}

- (void)clearSession {
    [self.authentication signOut];
}

- (void)applicationLaunchedWithOptions:(NSDictionary *)launchOptions {
    NSError *error;
    [[GGLContext sharedInstance] configureWithError: &error];
    if (error) {
        A0LogDebug(@"Failed to configure from plist file with error %@", error);
    }
}

#pragma mark - GPPSignInDelegate

- (void)signIn:(GIDSignIn *)signIn didSignInForUser:(GIDGoogleUser *)user withError:(NSError *)error {
    A0GoogleAuthentication callback = self.onAuthentication;
    self.onAuthentication = ^(NSError *error, NSString *token) {};
    dispatch_async(dispatch_get_main_queue(), ^{
        self.authenticating = NO;
        if (error) {
            A0LogError(@"Failed Google authentication with error %@", error);
            callback(error, nil);
        } else {
            A0LogDebug(@"Authenticated Google User with ID %@", user.userID);
            NSString *token = self.serverClientId ? user.authentication.idToken : user.authentication.accessToken;
            callback(nil, token);
        }
    });
}

#pragma mark - GIDSignInUIDelegate

- (void)signIn:(GIDSignIn *)signIn presentViewController:(UIViewController *)viewController {
    [[self presenterViewController] presentViewController:viewController animated:YES completion:nil];
}

- (void)signIn:(GIDSignIn *)signIn dismissViewController:(UIViewController *)viewController {
    [viewController.presentingViewController dismissViewControllerAnimated:YES completion:nil];
}

#pragma Utility methods

- (UIViewController *)presenterViewController {
    UIViewController* viewController = [UIApplication sharedApplication].keyWindow.rootViewController;
    return [self findBestViewController:viewController];
}

- (UIViewController*) findBestViewController:(UIViewController*)controller {
    if (controller.presentedViewController) {
        return [self findBestViewController:controller.presentedViewController];
    } else if ([controller isKindOfClass:[UISplitViewController class]]) {
        UISplitViewController* splitViewController = (UISplitViewController*) controller;
        if (splitViewController.viewControllers.count > 0) {
            return [self findBestViewController:splitViewController.viewControllers.lastObject];
        } else {
            return controller;
        }
    } else if ([controller isKindOfClass:[UINavigationController class]]) {
        UINavigationController* navigationController = (UINavigationController*) controller;
        if (navigationController.viewControllers.count > 0) {
            return [self findBestViewController:navigationController.topViewController];
        } else {
            return controller;
        }
    } else if ([controller isKindOfClass:[UITabBarController class]]) {
        UITabBarController* tabBarController = (UITabBarController*) controller;
        if (tabBarController.viewControllers.count > 0) {
            return [self findBestViewController:tabBarController.selectedViewController];
        } else {
            return controller;
        }
    } else {
        return controller;
    }
}

@end
