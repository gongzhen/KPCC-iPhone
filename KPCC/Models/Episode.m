//
//  Episode.m
//  KPCC
//
//  Created by John Meeker on 9/18/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "Episode.h"
#import "Utils.h"

@implementation Episode

-(id)initWithDict:(NSDictionary *)episodeDict {
    if((self = [super init])) {
        self.title      = episodeDict[@"title"];
        self.summary    = episodeDict[@"summary"];
        self.airDate    = [Utils dateFromRFCString:episodeDict[@"air_date"]];
        self.publicUrl  = episodeDict[@"public_url"];
//        self.assets     = episodeDict[@"assets"];
//        self.audio      = episodeDict[@"audio"];
//        self.program    = episodeDict[@"program"];
//        self.segments   = episodeDict[@"segments"];
        self.teaser     = episodeDict[@"teaser"];
    }
    return self;
}

@end
