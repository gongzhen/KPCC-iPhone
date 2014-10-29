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

#define kServerBase @"http://www.scpr.org/api/v3"
#define kFailoverThreshold 4


@protocol ContentProcessor <NSObject>
@optional
- (void)handleProcessedContent:(NSArray*)content flags:(NSDictionary*)flags;
@end


typedef enum {
    NetworkHealthUnknown = 0,
    NetworkHealthServerOK = 1,
    NetworkHealthNetworkOK = 2,
    NetworkHealthServerDown = 3,
    NetworkHealthNetworkDown = 4,
    NetworkHealthAllOK = 5
} NetworkHealth;


@interface NetworkManager : NSObject {
    Reachability *_networkHealthReachability;
}

@property NSInteger failoverCount;

+ (NetworkManager*)shared;

@property (nonatomic,strong) Reachability *networkHealthReachability;

- (NetworkHealth)checkNetworkHealth:(NSString*)server;
- (NSString *)networkInformation;

- (void)fetchProgramInformationFor:(NSDate*)thisTime display:(id<ContentProcessor>)display;
- (void)fetchAllProgramInformation:(id<ContentProcessor>)display;
- (void)fetchEpisodesForProgram:(NSString *)slug dispay:(id<ContentProcessor>)display;
- (void)processResponseData:(NSDictionary*)content;
- (void)requestFromSCPRWithEndpoint:(NSString*)endpoint andDisplay:(id<ContentProcessor>)display;
- (void)requestFromSCPRWithEndpoint:(NSString *)endpoint andDisplay:(id<ContentProcessor>)display flags:(NSDictionary*)flags;

- (void)fetchTritonAd:(NSString *)params completion:(void (^)(TritonAd* tritonAd))completion;
- (void)sendImpressionToTriton:(NSString*)impressionURL completion:(void (^)(BOOL success))completion;


@end
