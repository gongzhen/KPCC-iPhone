//
//  TritonAd.h
//  KPCC
//
//  Created by John Meeker on 10/21/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TritonAd : NSObject

- (instancetype)initWithDictionary:(NSDictionary *)dictionary;

@property (strong, nonatomic) NSArray *impressionUrls;
@property (strong, nonatomic) NSString *audioCreativeUrl;
@property (strong, nonatomic) NSNumber *audioCreativeDuration;
@property (strong, nonatomic) NSString *imageCreativeUrl;
@property (strong, nonatomic) NSString *clickthroughUrl;
@property (strong, nonatomic) NSString *creativeTrackingUrl;

@end
