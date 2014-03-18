//
//  NetworkManager.m
//  KPCC
//
//  Created by John Meeker on 3/18/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "NetworkManager.h"
#import "SBJson.h"
#import "SBJsonParser.h"

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

- (void)requestFromSCPRWithEndpoint:(NSString *)endpoint andDisplay:(id<ContentProcessor>)display flags:(NSDictionary *)flags {
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
                               if (dataString) {
                                   SBJsonParser *parser = [[SBJsonParser alloc] init];
                                   id chunk = [parser objectWithString:dataString];
                                   
                                   if (chunk) {
                                       NSDictionary *elements = @{ @"chunk" : chunk,
                                                                   @"port" : display };
                                       
                                       if ( flags && [flags count] > 0 ) {
                                           elements = @{ @"chunk" : chunk,
                                                         @"port" : display,
                                                         @"flags" : flags };
                                       }
                                       
                                       self.failoverCount = 0;
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
                               }
                           }];
}

- (void)fetchProgramInformationFor:(NSDate *)thisTime display:(id<ContentProcessor>)display {
    NSString *urlString = [NSString stringWithFormat:@"%@/schedule/at?time=%d",kServerBase,(NSInteger)[thisTime timeIntervalSince1970]];
    [self requestFromSCPRWithEndpoint:urlString
                           andDisplay:display];
}


@end
