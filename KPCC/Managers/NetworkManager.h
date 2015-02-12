//
//  NetworkManager.h
//  KPCC
//
//  Created by John Meeker on 3/18/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Reachability.h"
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#import <AFNetworking.h>
#import "TritonAd.h"
#import "Utils.h"
#import <KSReachability/KSReachability.h>

#define kServerBase @"http://www.scpr.org/api/v3"
#define kFailoverThreshold 10



typedef NS_ENUM(NSInteger, NetworkHealth) {
    NetworkHealthUnknown = 0,
    NetworkHealthServerOK,
    NetworkHealthNetworkOK,
    NetworkHealthContentServerDown,
    NetworkHealthNetworkDown,
    NetworkHealthStreamingServerDown,
    NetworkHealthAllOK
} ;


@interface NetworkManager : NSObject {
    
}

@property NSInteger failoverCount;

+ (NetworkManager*)shared;

@property (nonatomic,strong) KSReachability *anchoredReachability;
@property (nonatomic,strong) KSReachability *anchoredStaticContentReachability;
@property (nonatomic,strong) KSReachability *floatingReachability;
@property (nonatomic,strong) KSReachableOperation *reachableOperation;
@property (nonatomic,strong) Reachability *basicReachability;

- (NetworkHealth)checkNetworkHealth;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *networkInformation;

@property BOOL networkDown;
@property BOOL allowOneFail;
@property BOOL audioWillBeInterrupted;

@property (nonatomic, strong) NSTimer *failTimer;

- (void)fetchAllProgramInformation:(CompletionBlockWithValue)completion;
- (void)fetchEpisodesForProgram:(NSString*)slug completion:(CompletionBlockWithValue)completion;
- (void)fetchEditions:(CompletionBlockWithValue)completion;
- (void)requestFromSCPRWithEndpoint:(NSString *)endpoint completion:(CompletionBlockWithValue)completion;
- (void)fetchTritonAd:(NSString *)params completion:(void (^)(TritonAd* tritonAd))completion;
- (void)sendImpressionToTriton:(NSString*)impressionURL completion:(void (^)(BOOL success))completion;
- (void)setupReachability;
- (void)setupFloatingReachabilityWithHost:(NSString*)host;
- (void)applyNotifiersToReachability:(KSReachability*)reachability;

@end
