//
//  NetworkManager.h
//  KPCC
//
//  Created by John Meeker on 3/18/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <CoreTelephony/CTTelephonyNetworkInfo.h>
#import <CoreTelephony/CTCarrier.h>
#import "AudioAd.h"
#import "Utils.h"
#import "BlockTypes.h"

#define kServerBase [[NetworkManager shared] serverBase]
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

@property (nonatomic,strong) NSDate *timeDropped;
@property (nonatomic,strong) NSDate *timeReturned;

@property BOOL networkDown;
@property BOOL allowOneFail;
@property BOOL audioWillBeInterrupted;

@property (nonatomic, strong) NSTimer *failTimer;

- (void)fetchAllProgramInformation:(CompletionBlockWithValue)completion;
- (void)fetchEpisodesForProgram:(NSString*)slug completion:(CompletionBlockWithValue)completion;
- (void)fetchEditions:(CompletionBlockWithValue)completion;
- (void)requestFromSCPRWithEndpoint:(NSString *)endpoint completion:(CompletionBlockWithValue)completion;
- (void)fetchAudioAd:(NSString *)params completion:(void (^)(AudioAd* audioAd))completion;
- (void)pingAudioAdUrl:(NSString*)url completion:(void (^)(BOOL success))completion;

- (NSString*)serverBase;

@end
