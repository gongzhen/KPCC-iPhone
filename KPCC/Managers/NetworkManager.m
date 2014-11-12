//
//  NetworkManager.m
//  KPCC
//
//  Created by John Meeker on 3/18/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "NetworkManager.h"
#import <XMLDictionary/XMLDictionary.h>

static NetworkManager *singleton = nil;

@implementation NetworkManager

+ (NetworkManager*)shared {
    if ( !singleton ) {
        @synchronized(self) {
            singleton = [[NetworkManager alloc] init];
            singleton.networkHealthReachability = [Reachability reachabilityForInternetConnection];
            [singleton.networkHealthReachability startNotifier];
        }
    }
    
    return singleton;
}

- (NetworkHealth)checkNetworkHealth:(NSString *)server {
    if ([self.networkHealthReachability isReachable]) {
        if (server) {
            Reachability *serverReach = [Reachability reachabilityWithHostname:server];
            if ([serverReach isReachable]) {
                return NetworkHealthAllOK;
            } else {
                return NetworkHealthServerDown;
            }
        } else {
            return NetworkHealthAllOK;
        }
    }
    
    return NetworkHealthNetworkDown;
}

- (NSString*)networkInformation {
    
    NetworkStatus remoteHostStatus = [self.networkHealthReachability currentReachabilityStatus];
    
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


- (void)requestFromSCPRWithEndpoint:(NSString *)endpoint completion:(CompletionBlockWithValue)completion {
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    manager.responseSerializer = [AFJSONResponseSerializer serializerWithReadingOptions: NSJSONReadingMutableContainers];
    [manager GET:endpoint parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        if ([responseObject objectForKey:@"meta"] && [[[[responseObject objectForKey:@"meta"] objectForKey:@"status"] objectForKey:@"code"] intValue] == 200) {
            
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
        if (convertedData != nil && [convertedData objectForKey:@"Ad"]) {
            tritonAd = [[TritonAd alloc] initWithDict:[convertedData objectForKey:@"Ad"]];
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
