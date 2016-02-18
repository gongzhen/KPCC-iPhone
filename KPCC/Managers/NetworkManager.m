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

- (BOOL)wifi {
    NetworkStatus remoteHostStatus = [self.basicReachability currentReachabilityStatus];
    if ( remoteHostStatus == ReachableViaWiFi ) {
        return YES;
    }
    
    return NO;
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

- (void)fetchAudioAd:(NSString *)params completion:(void (^)(AudioAd* audioAd))completion {
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    manager.responseSerializer = [AFHTTPResponseSerializer serializer];
    NSString *idfa = [[[ASIdentifierManager sharedManager] advertisingIdentifier] UUIDString];
    
    NSDictionary *globalConfig = [Utils globalConfig];
    NSString *tritonEndpoint = [NSString stringWithFormat:globalConfig[@"AdServer"][@"Preroll"], idfa];

    [manager GET:tritonEndpoint parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        NSDictionary *convertedData = [NSDictionary dictionaryWithXMLData:responseObject];
        NSLog(@"convertedData %@", convertedData);
        AudioAd *audioAd;
        if ([convertedData[@"Ad"] isKindOfClass:[NSDictionary class]]) {
            audioAd = [[AudioAd alloc] initWithDictionary:convertedData[@"Ad"]];
        }
        completion(audioAd);
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
