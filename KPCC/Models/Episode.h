//
//  Episode.h
//  KPCC
//
//  Created by John Meeker on 9/18/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "EpisodeAudio.h"

@interface Episode : NSObject

-(id)initWithDict:(NSDictionary *)episodeDict;

@property(nonatomic,strong) NSString        *title;
@property(nonatomic,strong) NSString        *summary;
@property(nonatomic,strong) NSDate          *airDate;
@property(nonatomic,strong) NSString        *publicUrl;
@property(nonatomic,strong) NSArray         *assets;
@property(nonatomic,strong) EpisodeAudio    *audio;
@property(nonatomic,strong) NSDictionary    *program;
@property(nonatomic,strong) NSArray         *segments;
@property(nonatomic,strong) NSString        *teaser;

@end
