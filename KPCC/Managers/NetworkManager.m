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

- (void)trueFail {
    self.timeDropped = [NSDate date];
    self.networkDown = YES;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"network-status-fail"
                                                        object:nil];
}

- (void)requestFromSCPRWithEndpoint:(NSString *)endpoint completion:(CompletionBlockWithValue)completion {
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.responseSerializer = [AFJSONResponseSerializer serializerWithReadingOptions: NSJSONReadingMutableContainers];
    [manager GET:endpoint parameters:nil progress:nil success:^(NSURLSessionTask *task, id responseObject) {
        
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
        
    } failure:^(NSURLSessionTask *operation, NSError *error) {
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
    AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
    manager.responseSerializer = [AFHTTPResponseSerializer serializer];

    ASIdentifierManager *identifierManager = [ASIdentifierManager sharedManager];
    NSString *uuid = identifierManager.isAdvertisingTrackingEnabled ? identifierManager.advertisingIdentifier.UUIDString : @"";

    NSDictionary *globalConfig = [Utils globalConfig];
    NSString *endpoint = [NSString stringWithFormat:globalConfig[@"AdServer"][@"Preroll"], uuid];

    [manager GET:endpoint parameters:nil progress:nil success:^(NSURLSessionTask *task, id responseObject) {
        NSDictionary *convertedData = [NSDictionary dictionaryWithXMLData:responseObject];
        NSLog(@"convertedData %@", convertedData);
        AudioAd *audioAd;
        if ([convertedData[@"Ad"] isKindOfClass:[NSDictionary class]]) {
            audioAd = [[AudioAd alloc] initWithDictionary:convertedData[@"Ad"]];
        }
        completion(audioAd);
    } failure:^(NSURLSessionTask *operation, NSError *error) {
        NSLog(@"failure? %@", error);
        completion(nil);
    }];
}

- (void)pingAudioAdUrl:(NSString*)url completion:(void (^)(BOOL success))completion
{
    if (url && !SEQ(url,@"")) {
        AFHTTPSessionManager *manager = [AFHTTPSessionManager manager];
        manager.responseSerializer = [AFHTTPResponseSerializer serializer];
        [manager GET:url parameters:nil progress:nil success:^(NSURLSessionTask *task, id responseObject) {
            completion(YES);
        } failure:^(NSURLSessionTask *operation, NSError *error) {
            NSLog(@"Touching Audio Ad URL Failure? %@", error);
            completion(NO);
        }];
    } else {
        NSLog(@"Touching Audio Ad URL: No URL");
    }
}

- (NSString*)serverBase {
    NSDictionary *globalConfig = [Utils globalConfig];
    return globalConfig[@"SCPR"][@"api"];
}

@end
