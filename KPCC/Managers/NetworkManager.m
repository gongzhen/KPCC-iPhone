//
//  NetworkManager.m
//  KPCC
//
//  Created by John Meeker on 3/18/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "NetworkManager.h"
#import <XMLDictionary/XMLDictionary.h>
#import "AudioManager.h"
#import "AnalyticsManager.h"

@import AdSupport;

#define kFailThreshold 5.5

static NetworkManager *singleton = nil;

@implementation NetworkManager

+ (NetworkManager*)shared {
    if ( !singleton ) {
        @synchronized(self) {
            singleton = [[NetworkManager alloc] init];
        }
    }
    
    return singleton;
}

- (NetworkHealth)checkNetworkHealth {
    if ( [self.floatingReachability reachable] ) {
        if ( [self.anchoredStaticContentReachability reachable] ) {
            if ( [self.anchoredReachability reachable] ) {
                return NetworkHealthAllOK;
            } else {
                return NetworkHealthNetworkDown;
            }
        } else {
            return NetworkHealthContentServerDown;
        }
    }
    
    return NetworkHealthStreamingServerDown;

}

- (NSString*)networkInformation {
    
    NetworkStatus remoteHostStatus = [self.basicReachability currentReachabilityStatus];
    NSString *nInfo = @"";
    if ( remoteHostStatus == ReachableViaWiFi ) {
        nInfo = @"Wi-Fi";
    } else if ( remoteHostStatus == ReachableViaWWAN ) {
        CTTelephonyNetworkInfo *netinfo = [[CTTelephonyNetworkInfo alloc] init];
        CTCarrier *carrier = [netinfo subscriberCellularProvider];
        NSString *carrierName = [carrier carrierName];
        nInfo = carrierName;
    } else {
        nInfo = @"No Connection";
    }
    
    return nInfo;
}

- (void)setupReachability {
    
    
    NSURL *contentUrl = [NSURL URLWithString:kServerBase];
    NSString *contentServer = [contentUrl host];
    
    self.anchoredStaticContentReachability = [KSReachability reachabilityToHost:contentServer];
    self.anchoredReachability = [KSReachability reachabilityToLocalNetwork];
    [self applyNotifiersToReachability:self.anchoredReachability];
    [self applyNotifiersToReachability:self.anchoredStaticContentReachability];
    [self setupFloatingReachabilityWithHost:[[NSURL URLWithString:kHLS] host]];
    
    self.basicReachability = [Reachability reachabilityForInternetConnection];
    
}

- (BOOL)wifi {
    NetworkStatus remoteHostStatus = [self.basicReachability currentReachabilityStatus];
    if ( remoteHostStatus == ReachableViaWiFi ) {
        return YES;
    }
    
    return NO;
}

- (void)applyNotifiersToReachability:(KSReachability *)reachability {
#ifndef DISABLE_INTERRUPT
    __block NetworkManager *weakself_ = self;
    __block KSReachability *weakreach_ = reachability;
    reachability.onReachabilityChanged = ^(KSReachability* reach) {
        dispatch_async(dispatch_get_main_queue(), ^{
            
            if ( weakself_.failTimer ) {
                if ( [weakself_.failTimer isValid] ) {
                    [weakself_.failTimer invalidate];
                }
                weakself_.failTimer = nil;
            }
            
            if ( [weakreach_ reachable] ) {
                NSLog(@"Reachability reports reachable.");

                weakself_.timeReturned = [NSDate date];
                

                
                weakself_.networkDown = NO;
                [[NSNotificationCenter defaultCenter] postNotificationName:@"network-status-good"
                                                                object:nil];
                
                if ( weakself_.timeDropped && weakself_.timeReturned ) {
                    weakself_.timeReturned = nil;
                    weakself_.timeDropped = nil;
                }
                
            } else {
                NSLog(@"Reachability reports unreachable.");

                weakself_.failTimer = [NSTimer scheduledTimerWithTimeInterval:kFailThreshold
                                                                       target:weakself_
                                                                     selector:@selector(trueFail)
                                                                     userInfo:nil
                                                                      repeats:NO];
                
            }
        });
    };
#endif
}

- (void)setupFloatingReachabilityWithHost:(NSString *)host {
    NSURL *url = [NSURL URLWithString:host];
    self.floatingReachability = [KSReachability reachabilityToHost:[url host]];
    [self applyNotifiersToReachability:self.floatingReachability];
}

- (void)trueFail {
    self.timeDropped = [NSDate date];
    self.networkDown = YES;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"network-status-fail"
                                                        object:nil];
}


- (void)requestFromSCPRWithEndpoint:(NSString *)endpoint completion:(CompletionBlockWithValue)completion {
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    manager.responseSerializer = [AFJSONResponseSerializer serializerWithReadingOptions: NSJSONReadingMutableContainers];
    [manager GET:endpoint parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        if (responseObject[@"meta"] && [responseObject[@"meta"][@"status"][@"code"] intValue] == 200) {
            
            NSArray *keys = [responseObject allKeys];
            NSString *responseKey;
            for (NSString *key in keys) {
                if (![key isEqualToString:@"meta"]) {
                    id thing = responseObject[key];
                    if ( [thing isKindOfClass:[NSDictionary class]] || [thing isKindOfClass:[NSArray class]] ) {
                        responseKey = key;
                        break;
                    }
                }
            }
            
            if ( responseKey ) {
                NSDictionary *response = (NSDictionary*)responseObject;
                id serverObjects = response[responseKey];
                if (!serverObjects) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completion(nil);
                    });
                    return;
                }
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(serverObjects);
                });
                
            } else {
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    completion(nil);
                });
                return;
                
            }
            
        }
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        dispatch_async(dispatch_get_main_queue(), ^{
            completion(nil);
        });
        return;
    }];
}



- (void)fetchAllProgramInformation:(CompletionBlockWithValue)completion {
    NSString *urlString = [NSString stringWithFormat:@"%@/programs?air_status=onair,online",kServerBase];
    [self requestFromSCPRWithEndpoint:urlString completion:^(id returnedObject) {
        completion(returnedObject);
    }];
}

- (void)fetchEpisodesForProgram:(NSString *)slug completion:(CompletionBlockWithValue)completion {
    NSString *urlString = [NSString stringWithFormat:@"%@/episodes?program=%@&limit=8",kServerBase,slug];
    [self requestFromSCPRWithEndpoint:urlString
                           completion:^(id returnedObject) {
                               completion(returnedObject);
                           }];
}

- (void)fetchEditions:(CompletionBlockWithValue)completion {
    NSString *urlString = [NSString stringWithFormat:@"%@/editions?limit=1",kServerBase];
    [self requestFromSCPRWithEndpoint:urlString completion:^(id returnedObject) {
        completion(returnedObject);
    }];
}

- (void)fetchTritonAd:(NSString *)params completion:(void (^)(TritonAd* tritonAd))completion {
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    NSString *idfa = [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
    
    NSDictionary *globalConfig = [Utils globalConfig];
    NSString *tritonEndpoint = [NSString stringWithFormat:globalConfig[@"AdServer"][@"Preroll"], idfa];

    [manager GET:tritonEndpoint parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *convertedData = [NSDictionary dictionaryWithXMLData:responseObject];
        NSLog(@"convertedData %@", convertedData);
        TritonAd *tritonAd;
        if ([convertedData[@"Ad"] isKindOfClass:[NSDictionary class]]) {
            tritonAd = [[TritonAd alloc] initWithDictionary:convertedData[@"Ad"]];
        }
        completion(tritonAd);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"failure? %@", error);
        completion(nil);
    }];
}

- (void)pingTritonUrl:(NSString*)url completion:(void (^)(BOOL success))completion
{
    if (url && !SEQ(url,@"")) {
        AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
        manager.responseSerializer = [AFHTTPResponseSerializer serializer];
        [manager GET:url parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
            completion(YES);
        } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
            NSLog(@"Touching Triton URL Failure? %@", error);
            completion(NO);
        }];
    } else {
        NSLog(@"Touching Triton URL: No URL");
    }
}

- (NSString*)serverBase {
    NSDictionary *globalConfig = [Utils globalConfig];
    return globalConfig[@"SCPR"][@"api"];
}

@end
