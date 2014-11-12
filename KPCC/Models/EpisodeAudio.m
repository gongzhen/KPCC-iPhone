//
//  EpisodeAudio.m
//  KPCC
//
//  Created by John Meeker on 9/18/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "EpisodeAudio.h"
#import "Utils.h"

@implementation EpisodeAudio

-(id)initWithDict:(NSDictionary *)dict {
    if((self = [super init])) {
        self.audDescription     = dict[@"description"];
        self.url                = dict[@"url"];
        self.byline             = dict[@"byline"];
        self.uploadedAt         = [Utils dateFromRFCString:dict[@"uploaded_at"]];

        if (dict[@"id"] != nil) {
//            self.audioId = [NSNumber numberWithInteger:[dict[@"id"] integerValue]];
        }

        if (dict[@"position"] != nil) {
//            self.position = [NSNumber numberWithInteger:[dict[@"position"] integerValue]];
        }

        if (dict[@"duration"] != nil && dict[@"duration"] != [NSNull null]) {
            self.duration = [NSNumber numberWithInteger:[dict[@"duration"] integerValue]];
        }

//        self.filesize           = [NSNumber numberWithInteger:[dict[@"filesize"] integerValue]];
    }
    return self;
}

@end
