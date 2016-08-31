// A0GoogleAuthenticator.m
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

#import "A0GoogleAuthenticator.h"
#import <Lock/A0Strategy.h>
#import <Lock/A0APIClient.h>
#import <Lock/A0IdentityProviderCredentials.h>
#import <Lock/A0Errors.h>
#import <Lock/A0AuthParameters.h>
#import <UIKit/UIKit.h>
#import "A0GoogleProvider.h"

#define A0LogError(fmt, ...)
#define A0LogVerbose(fmt, ...)
#define A0LogDebug(fmt, ...)

static NSString * const DefaultConnectionName = @"google-oauth2";

@interface A0GoogleAuthenticator ()
@property (strong, nonatomic) A0GoogleProvider *google;
@property (copy, nonatomic) NSString *connectionName;
@end

@implementation A0GoogleAuthenticator

- (instancetype)initWithConnectionName:(NSString *)connectionName andScopes:(NSArray *)scopes {
    return [self initWithConnectionName:connectionName
                      andGoogleProvider:[[A0GoogleProvider alloc] initWithScopes:scopes]];
}

- (instancetype)initWithConnectionName:(NSString *)connectionName andClientId:(NSString *)clientId scopes:(NSArray *)scopes {
    return [self initWithConnectionName:connectionName
                      andGoogleProvider:[[A0GoogleProvider alloc] initWithClientId:clientId scopes:scopes]];
}

- (instancetype)initWithConnectionName:(NSString *)connectionName andGoogleProvider:(A0GoogleProvider *)google {
    self = [super init];
    if (self) {
        _google = google;
        _connectionName = [connectionName copy];
        [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(handleDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];
    }
    return self;
}

- (void)applicationLaunchedWithOptions:(NSDictionary *)launchOptions {
    [self.google applicationLaunchedWithOptions:launchOptions];
}

- (void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (NSString *)identifier {
    return self.connectionName;
}

- (void)authenticateWithParameters:(A0AuthParameters *)parameters
                           success:(void (^)(A0UserProfile *, A0Token *))success
                           failure:(void (^)(NSError *))failure {
    NSAssert(success != nil, @"Must provide a non-nil success block");
    NSAssert(failure != nil, @"Must provide a non-nil failure block");
    A0APIClient *client = [self apiClient];
    NSString *connectionName = [self identifier];
    self.google.serverClientId = self.serverClientId;
    [self.google authenticateWithScopes:[self scopesFromParameters:parameters] callback:^(NSError *error, NSString *token) {
        if (error) {
            A0LogError(@"Failed to authenticate with Google with error %@", error);
            failure(error);
        } else {
            A0LogVerbose(@"Authenticated with Google. Token: %@", token);
            A0IdentityProviderCredentials *credentials = [[A0IdentityProviderCredentials alloc] initWithAccessToken:token];
            [client authenticateWithSocialConnectionName:connectionName
                                             credentials:credentials
                                              parameters:parameters
                                                 success:success
                                                 failure:failure];
        }
    }];
    A0LogVerbose(@"Started Google authentication with connection name %@", connectionName);
}

- (void)clearSessions {
    [self.google clearSession];
    A0LogVerbose(@"Cleaned up Google session");
}

- (BOOL)handleURL:(NSURL *)url sourceApplication:(NSString *)sourceApplication {
    return [self.google handleURL:url sourceApplication:sourceApplication];
}

- (void)handleDidBecomeActive:(NSNotification *)notification {
    [self.google cancelAuthentication];
}

#pragma mark - Utility methods

- (NSArray *)scopesFromParameters:(A0AuthParameters *)parameters {
    NSArray *connectionScopes = parameters.connectionScopes[self.identifier];
    if (connectionScopes.count == 0) {
        A0LogDebug(@"Using Google default scopes");
        return nil;
    }
    A0LogDebug(@"Google scopes %@", connectionScopes);
    return [[NSSet setWithArray:connectionScopes] allObjects];
}

- (A0APIClient *)apiClient {
#pragma GCC diagnostic push
#pragma GCC diagnostic ignored "-Wdeprecated"
    return [self.clientProvider apiClient] ?: [A0APIClient sharedClient];
#pragma GCC diagnostic pop
}

#pragma mark - Factory methods for default connection

+ (instancetype)newAuthenticator {
    return [[A0GoogleAuthenticator alloc] initWithConnectionName:DefaultConnectionName andScopes:nil];
}

+ (instancetype)newAuthenticatorWithScopes:(NSArray *)scopes {
    return [[A0GoogleAuthenticator alloc] initWithConnectionName:DefaultConnectionName andScopes:scopes];
}

+ (instancetype)newAuthenticatorWithClientId:(NSString *)clientId {
    return [self newAuthenticatorForConnectionName:DefaultConnectionName withClientId:clientId];
}

+ (instancetype)newAuthenticatorWithClientId:(NSString *)clientId andScopes:(NSArray *)scopes {
    return [self newAuthenticatorForConnectionName:DefaultConnectionName withClientId:clientId andScopes:scopes];
}

#pragma mark - Factory methods for custom connection

+ (instancetype)newAuthenticatorForConnectionName:(NSString *)connectionName {
    return [[A0GoogleAuthenticator alloc] initWithConnectionName:connectionName andScopes:nil];
}

+ (instancetype)newAuthenticatorForConnectionName:(NSString *)connectionName withScopes:(NSArray *)scopes {
    return [[A0GoogleAuthenticator alloc] initWithConnectionName:connectionName andScopes:scopes];
}

+ (instancetype)newAuthenticatorForConnectionName:(NSString *)connectionName withClientId:(NSString *)clientId {
    return [[A0GoogleAuthenticator alloc] initWithConnectionName:connectionName andClientId:clientId scopes:nil];
}

+ (instancetype)newAuthenticatorForConnectionName:(NSString *)connectionName withClientId:(NSString *)clientId andScopes:(NSArray *)scopes {
    return [[A0GoogleAuthenticator alloc] initWithConnectionName:connectionName andClientId:clientId scopes:scopes];
}


@end
