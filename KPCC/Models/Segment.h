//
//  Segment.h
//  KPCC
//
//  Created by John Meeker on 9/22/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EpisodeAudio.h"
#import "Utils.h"

@interface Segment : NSObject

-(id)initWithDict:(NSDictionary *)dict;

@property(nonatomic,strong) NSNumber        *segmentId;
@property(nonatomic,strong) NSString        *title;
@property(nonatomic,strong) NSDate          *publishedAt;
@property(nonatomic,strong) NSString        *byline;
@property(nonatomic,strong) NSString        *teaser;
@property(nonatomic,strong) NSString        *permalink;
@property(nonatomic,strong) NSString        *publicUrl;
@property(nonatomic,strong) EpisodeAudio    *audio;
@property(nonatomic,strong) NSString        *programName;

@end
