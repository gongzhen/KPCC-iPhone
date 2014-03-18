//
//  NetworkManager.m
//  KPCC
//
//  Created by John Meeker on 3/18/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "NetworkManager.h"

@implementation NetworkManager

- (NetworkHealth)checkNetworkHealth:(NSString *)server {
    if ([self.networkHealthReachability isReachable]) {
        if ( server ) {
            Reachability *serverReach = [Reachability reachabilityWithHostname:server];
            if ( [serverReach isReachable] ) {
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

- (void)requestFromSCPRWithEndpoint:(NSString *)endpoint andDisplay:(id<ContentProcessor>)display {
    [self requestFromSCPRWithEndpoint:endpoint andDisplay:display flags:nil];
}

- (void)requestFromKPCCWithEndpoint:(NSString *)endpoint andDisplay:(id<ContentProcessor>)display flags:(NSDictionary *)flags {
    NSURL *url = [NSURL URLWithString:endpoint];
    NSURLRequest *request = [NSURLRequest requestWithURL:url];
    
    NSOperationQueue *queue = [[NSOperationQueue alloc] init];;
    
    [NSURLConnection sendAsynchronousRequest:request
                                       queue:queue
                           completionHandler:^(NSURLResponse *r, NSData *d, NSError *e) {
                               
                               if (e) {
                                   return;
                               }
                               
                               NSString *dataString = [[NSString alloc] initWithData:d
                                                                            encoding:NSUTF8StringEncoding];
                               if ( dataString ) {
                                   id chunk = [dataString JSONValue];
                                   if ( chunk ) {
                                       
                                       NSDictionary *elements = @{ @"chunk" : chunk,
                                                                   @"port" : display };
                                       
                                       if ( flags && [flags count] > 0 ) {
                                           elements = @{ @"chunk" : chunk,
                                                         @"port" : display,
                                                         @"flags" : flags };
                                       }
                                       
                                       self.failoverCount = 0;
                                       dispatch_async(dispatch_get_main_queue(), ^{
                                           
                                           if ( [flags objectForKey:@"events"] ) {
                                               [self processEventsData:elements];
                                           } else {
                                               [self processContentData:elements];
                                           }
                                       });
                                       
                                       
                                   } else {
                                       
                                       if ( self.failoverCount < kFailoverThreshold ) {
                                           self.failoverCount++;
                                           [self requestFromKPCCWithEndpoint:endpoint
                                                                  andDisplay:display
                                                                       flags:flags];
                                           return;
                                       } else {
                                           self.failoverCount = 0;
                                       }
                                       
                                       [[AnalyticsManager shared] failureFetchingContent:endpoint];
                                   }
                               } else {
                                   [[AnalyticsManager shared] failureFetchingContent:endpoint];
                               }
                               
                           }];
}


@end
