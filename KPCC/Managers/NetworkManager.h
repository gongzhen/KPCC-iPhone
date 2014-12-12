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

#define kServerBase @"http://www.scpr.org/api/v3"
#define kFailoverThreshold 4



typedef NS_ENUM(NSInteger, NetworkHealth) {
    NetworkHealthUnknown = 0,
    NetworkHealthServerOK = 1,
    NetworkHealthNetworkOK = 2,
    NetworkHealthServerDown = 3,
    NetworkHealthNetworkDown = 4,
    NetworkHealthAllOK = 5
} ;


@interface NetworkManager : NSObject {
    Reachability *_networkHealthReachability;
}

@property NSInteger failoverCount;

+ (NetworkManager*)shared;

@property (nonatomic,strong) Reachability *networkHealthReachability;

- (NetworkHealth)checkNetworkHealth:(NSString*)server;
@property (NS_NONATOMIC_IOSONLY, readonly, copy) NSString *networkInformation;


- (void)fetchAllProgramInformation:(CompletionBlockWithValue)completion;
- (void)fetchEpisodesForProgram:(NSString*)slug completion:(CompletionBlockWithValue)completion;
- (void)fetchEditions:(CompletionBlockWithValue)completion;



- (void)requestFromSCPRWithEndpoint:(NSString *)endpoint completion:(CompletionBlockWithValue)completion;

- (void)fetchTritonAd:(NSString *)params completion:(void (^)(TritonAd* tritonAd))completion;
- (void)sendImpressionToTriton:(NSString*)impressionURL completion:(void (^)(BOOL success))completion;


@end
