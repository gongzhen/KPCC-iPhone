//
//  TritonAd.h
//  KPCC
//
//  Created by John Meeker on 10/21/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TritonAd : NSObject

- (instancetype)initWithDictionary:(NSDictionary *)dictionary NS_DESIGNATED_INITIALIZER;

@property (strong, nonatomic) NSString *adId;
@property (strong, nonatomic) NSString *impressionUrl;
@property (strong, nonatomic) NSString *audioCreativeUrl;
@property (strong, nonatomic) NSNumber *audioCreativeDuration;
@property (strong, nonatomic) NSString *imageCreativeUrl;
@property (strong, nonatomic) NSNumber *imageCreativeWidth;
@property (strong, nonatomic) NSNumber *imageCreativeHeight;
@property (strong, nonatomic) NSString *creativeTrackingUrl;
@property (strong, nonatomic) NSString *clickthroughUrl;

@end
