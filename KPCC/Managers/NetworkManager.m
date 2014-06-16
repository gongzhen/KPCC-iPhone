//
//  NetworkManager.m
//  KPCC
//
//  Created by John Meeker on 3/18/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "NetworkManager.h"

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

- (void)requestFromSCPRWithEndpoint:(NSString *)endpoint andDisplay:(id<ContentProcessor>)display {
    [self requestFromSCPRWithEndpoint:endpoint andDisplay:display flags:nil];
}

- (void)requestFromSCPRWithEndpoint:(NSString *)endpoint andDisplay:(id<ContentProcessor>)display flags:(NSDictionary *)flags {

    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    [manager GET:endpoint parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        if (responseObject) {
            NSDictionary *elements = @{ @"chunk" : responseObject,
                                        @"port" : display };
            
            if ( flags && [flags count] > 0 ) {
                elements = @{ @"chunk" : responseObject,
                              @"port" : display,
                              @"flags" : flags };
            }
            
            self.failoverCount = 0;
            dispatch_async(dispatch_get_main_queue(), ^{
                [self processResponseData:elements];
            });

        } else {
            
            if ( self.failoverCount < kFailoverThreshold ) {
                self.failoverCount++;
                [self requestFromSCPRWithEndpoint:endpoint
                                       andDisplay:display
                                            flags:flags];
                return;
            } else {
                self.failoverCount = 0;
            }
        }
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
    }];
}

- (void)fetchProgramInformationFor:(NSDate *)thisTime display:(id<ContentProcessor>)display {
    NSString *urlString = [NSString stringWithFormat:@"%@/schedule/at?time=%d",kServerBase,(int)[thisTime timeIntervalSince1970]];
    [self requestFromSCPRWithEndpoint:urlString
                           andDisplay:display];
}

- (void)processResponseData:(NSDictionary *)content {
    
    NSDictionary *flags = @{};
    if ([content objectForKey:@"flags"]) {
        flags = [content objectForKey:@"flags"];
    }
    
    id<ContentProcessor> display = [content objectForKey:@"port"];
    id data = [content objectForKey:@"chunk"];
    
    if (data == [NSNull null]) {
        [display handleProcessedContent:@[] flags:flags];
        return;
    }
    
    if ([data isKindOfClass:[NSDictionary class]]) {
        [display handleProcessedContent:@[data] flags:flags];
    } else {
        [display handleProcessedContent:data flags:flags];
    }
}

@end
