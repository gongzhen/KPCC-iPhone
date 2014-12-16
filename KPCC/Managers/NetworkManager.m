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

#define kFailThreshold 2.0

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

- (NetworkHealth)checkNetworkHealth:(NSString *)server {
    
    if ( [self.anchoredReachability reachable] ) {
        if ( [self.anchoredStaticContentReachability reachable] ) {
            if ( [self.floatingReachability reachable] ) {
                return NetworkHealthAllOK;
            } else {
                return NetworkHealthServerDown;
            }
        } else {
            return NetworkHealthServerDown;
        }
    } else {
        return NetworkHealthNetworkDown;
    }
    
    return NetworkHealthNetworkDown;
}

- (NSString*)networkInformation {
    
    NetworkStatus remoteHostStatus = [self.basicReachability currentReachabilityStatus];
    
    if ( remoteHostStatus == ReachableViaWiFi ) {
        return @"Wi-Fi";
    }
    if ( remoteHostStatus == ReachableViaWWAN ) {
        CTTelephonyNetworkInfo *netinfo = [[CTTelephonyNetworkInfo alloc] init];
        CTCarrier *carrier = [netinfo subscriberCellularProvider];
        NSString *carrierName = [carrier carrierName];
        return carrierName;
    }
    
    return @"No Connection";
}

- (void)setupReachability {
    
    
    NSURL *contentUrl = [NSURL URLWithString:kServerBase];
    NSString *contentServer = [contentUrl host];
    
    self.anchoredStaticContentReachability = [KSReachability reachabilityToHost:contentServer];
    self.anchoredReachability = [KSReachability reachabilityToLocalNetwork];
    [self applyNotifiersToReachability:self.anchoredReachability];
    [self applyNotifiersToReachability:self.anchoredStaticContentReachability];
    
    self.basicReachability = [Reachability reachabilityForInternetConnection];
    
    /*
    self.reachableOperation = [KSReachableOperation operationWithHost:contentServer
                                                            allowWWAN:YES
                                               onReachabilityAchieved:^{
                                                   
                                                   [[NSNotificationCenter defaultCenter] postNotificationName:@"network-status-good"
                                                                                                       object:nil];
                                                   
                                               }];*/
    
    
}

- (void)applyNotifiersToReachability:(KSReachability *)reachability {
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
                weakself_.networkDown = NO;
                [[NSNotificationCenter defaultCenter] postNotificationName:@"network-status-good"
                                                                object:nil];
            } else {
                weakself_.networkDown = YES;
                weakself_.failTimer = [NSTimer scheduledTimerWithTimeInterval:kFailThreshold
                                                                       target:weakself_
                                                                     selector:@selector(trueFail)
                                                                     userInfo:nil
                                                                      repeats:NO];
            }
        });
    };
    
}

- (void)setupFloatingReachabilityWithHost:(NSString *)host {

    
    NSURL *url = [NSURL URLWithString:host];

    self.floatingReachability = [KSReachability reachabilityToHost:[url host]];
    [self applyNotifiersToReachability:self.floatingReachability];
    
}

- (void)trueFail {
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
                    responseKey = key;
                    break;
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
    NSString *urlString = [NSString stringWithFormat:@"%@/programs?air_status=onair",kServerBase];
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
    NSString *tritonEndpoint = @"http://cmod.live.streamtheworld.com/ondemand/ars?type=preroll&stid=83153";

    [manager GET:tritonEndpoint parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *convertedData = [NSDictionary dictionaryWithXMLData:responseObject];
        NSLog(@"convertedData %@", convertedData);

        TritonAd *tritonAd = nil;
        if (convertedData != nil && convertedData[@"Ad"]) {
            tritonAd = [[TritonAd alloc] initWithDict:convertedData[@"Ad"]];
        }

        completion(tritonAd);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"failure? %@", error);
        completion(nil);
    }];
}

- (void)sendImpressionToTriton:(NSString*)impressionURL completion:(void (^)(BOOL success))completion {
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    [manager GET:impressionURL parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        completion(YES);
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"send impression failure? %@", error);
        completion(NO);
    }];
}

@end
