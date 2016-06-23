// A0GoogleAuthenticator.h
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

#import <Foundation/Foundation.h>
#import <Lock/A0BaseAuthenticator.h>

/**
 * Performs Google authentication using Google's official SDK.
 */
@interface A0GoogleAuthenticator : A0BaseAuthenticator

/**
 * Your server's clientId obtained from Google. 
 * Set this value if you need to use the user's token in your server so all tokens are issued to be used by your backemd
 * By default is nil.
 */
@property (copy, nonatomic) NSString *serverClientId;

/**
 *  Creates a new authenticator with default scopes (login and email) and a clientId.
 *  It will retrieve Google's clientId from `GoogleService-Info.plist` file
 *
 *  @return a new instance
 */
+ (instancetype)newAuthenticator;

/**
 *  Creates a new authenticator with a list of scopes and a clientId.
 *  It will retrieve Google's clientId from `GoogleService-Info.plist` file
 *
 *  @param scopes   list of scopes to send to Google API.
 *
 *  @return a new instance
 */
+ (instancetype)newAuthenticatorWithScopes:(NSArray *)scopes;

/**
 *  Creates a new Google authenticator for a custom connection.
 *  It will retrieve Google's clientId from `GoogleService-Info.plist` file
 *
 *  @param connectionName of the custom Google connection created in Auth0
 *
 *  @return a new instance
 */
+ (instancetype)newAuthenticatorForConnectionName:(NSString *)connectionName;

/**
 *  Creates a new Google authenticator for a custom connection.
 *  It will retrieve Google's clientId from `GoogleService-Info.plist` file
 *
 *  @param connectionName of the custom Google connection created in Auth0
 *  @param scopes         sent to Google API to authenticate
 *
 *  @return a new instance
 */
+ (instancetype)newAuthenticatorForConnectionName:(NSString *)connectionName withScopes:(NSArray *)scopes;

/**
 *  Creates a new Google authenticator for a custom connection.
 *
 *  @param connectionName of the custom Google connection created in Auth0
 *  @param clientId       for your application obtained from Google API dashboard
 *
 *  @return a new instance
 */
+ (instancetype)newAuthenticatorForConnectionName:(NSString *)connectionName withClientId:(NSString *)clientId;

/**
 *  Creates a new Google authenticator for a custom connection.
 *
 *  @param connectionName of the custom Google connection created in Auth0
 *  @param clientId       for your application obtained from Google API dashboard
 *  @param scopes         sent to Google API to authenticate
 *
 *  @return a new instance
 */
+ (instancetype)newAuthenticatorForConnectionName:(NSString *)connectionName withClientId:(NSString *)clientId andScopes:(NSArray *)scopes;

/**
 *  Creates a new authenticator with default scopes (login and email) and a clientId.
 *
 *  @param clientId application clientId in Google+
 *
 *  @return a new instance
 */
+ (instancetype)newAuthenticatorWithClientId:(NSString *)clientId;

/**
 *  Creates a new authenticator with a list of scopes and a clientId.
 *
 *  @param clientId application clientId in Google+
 *  @param scopes   list of scopes to send to Google API.
 *
 *  @return a new instance
 */
+ (instancetype)newAuthenticatorWithClientId:(NSString *)clientId andScopes:(NSArray *)scopes;

@end
