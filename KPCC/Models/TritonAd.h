//
//  TritonAd.h
//  KPCC
//
//  Created by John Meeker on 10/21/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface TritonAd : NSObject

- (id)initWithDict:(NSDictionary *)dictionary;

@property (nonatomic,strong) NSString *adId;
@property (nonatomic,strong) NSString *impressionUrl;
@property (nonatomic,strong) NSString *audioCreativeUrl;
@property (nonatomic,strong) NSNumber *audioCreativeDuration;
@property (nonatomic,strong) NSString *imageCreativeUrl;
@property (nonatomic,strong) NSNumber *imageCreativeHeight;
@property (nonatomic,strong) NSNumber *imageCreativeWidth;
@property (nonatomic,strong) NSString *creativeTrackingUrl;

@end
