//
//  EpisodeAudio.h
//  KPCC
//
//  Created by John Meeker on 9/18/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface EpisodeAudio : NSObject

- (instancetype)init __unavailable;
- (instancetype)initWithDict:(NSDictionary *)dict NS_DESIGNATED_INITIALIZER;

@property(nonatomic,strong) NSNumber    *audioId;
@property(nonatomic,strong) NSString    *audDescription;
@property(nonatomic,strong) NSString    *url;
@property(nonatomic,strong) NSString    *byline;
@property(nonatomic,strong) NSDate      *uploadedAt;
@property(nonatomic,strong) NSNumber    *position;
@property(nonatomic,strong) NSNumber    *duration;
@property(nonatomic,strong) NSNumber    *filesize;

@end
