//
//  TritonAd.m
//  KPCC
//
//  Created by John Meeker on 10/21/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "TritonAd.h"

@implementation TritonAd

- (instancetype)initWithDictionary:(NSDictionary *)dictionary
{
    self = [super init];

    if (self) {

        if (! [dictionary[@"_id"] isKindOfClass:[NSString class]]) {
            return nil;
        }

        if (! [dictionary[@"InLine"] isKindOfClass:[NSDictionary class]]) {
            return nil;
        }

        _adId = dictionary[@"_id"];

        NSDictionary *inlineDict = dictionary[@"InLine"];

        if ([inlineDict[@"Impression"] isKindOfClass:[NSDictionary class]]) {
            if ([inlineDict[@"Impression"][@"__text"] isKindOfClass:[NSString class]]) {
                _impressionUrl = inlineDict[@"Impression"][@"__text"];
            }
        }

        if ((! _adId.length) || (! _impressionUrl.length)) {
            return nil;
        }

        if ([inlineDict[@"Creatives"] isKindOfClass:[NSDictionary class]]) {
            if ([inlineDict[@"Creatives"][@"Creative"] isKindOfClass:[NSArray class]]) {
                [self parseCreatives:inlineDict[@"Creatives"][@"Creative"]];
            }
        }

    }

    return self;
}

- (void)parseCreatives:(NSArray *)creatives
{
    if ([creatives.firstObject isKindOfClass:[NSDictionary class]]) {

        NSDictionary *firstCreative = creatives.firstObject;

        if ([firstCreative[@"Linear"] isKindOfClass:[NSDictionary class]]) {

            NSDictionary *audioCreative = firstCreative[@"Linear"];

            if ([audioCreative[@"MediaFiles"] isKindOfClass:[NSDictionary class]]) {
                if ([audioCreative[@"MediaFiles"][@"MediaFile"] isKindOfClass:[NSDictionary class]]) {
                    if ([audioCreative[@"MediaFiles"][@"MediaFile"][@"__text"] isKindOfClass:[NSString class]]) {
                        _audioCreativeUrl = audioCreative[@"MediaFiles"][@"MediaFile"][@"__text"];
                    }
                }
            }

            if ([audioCreative[@"Duration"] isKindOfClass:[NSString class]]) {
                NSArray *components = [audioCreative[@"Duration"] componentsSeparatedByString:@":"];
                if (components.count == 3) {
                    double duration = 0.0;
                    for (NSString *component in components) {
                        duration = (duration * 60.0) + component.doubleValue;
                    }
                    _audioCreativeDuration = @(duration);
                }
            }

        }

        if ([creatives[1] isKindOfClass:[NSDictionary class]]) {

            NSDictionary *secondCreative = creatives[1];

            if ([secondCreative[@"CompanionAds"] isKindOfClass:[NSDictionary class]]) {

                if ([secondCreative[@"CompanionAds"][@"Companion"] isKindOfClass:[NSArray class]]) {

                    NSDictionary *companionCreative;

                    for (id companion in secondCreative[@"CompanionAds"][@"Companion"]) {
                        if ([companion isKindOfClass:[NSDictionary class]]) {
                            if ([companion[@"StaticResource"] isKindOfClass:[NSDictionary class]]) {
                                companionCreative = companion;
                                break;
                            }
                        }
                    }

                    if (companionCreative) {

                        if ([companionCreative[@"StaticResource"][@"__text"] isKindOfClass:[NSString class]]) {
                            _imageCreativeUrl = companionCreative[@"StaticResource"][@"__text"];
                        }

                        if ([companionCreative[@"_width"] isKindOfClass:[NSString class]]) {
                            _imageCreativeWidth = @([companionCreative[@"_width"] doubleValue]);
                        }

                        if ([companionCreative[@"_height"] isKindOfClass:[NSString class]]) {
                            _imageCreativeHeight = @([companionCreative[@"_height"] doubleValue]);
                        }

                        if ([companionCreative[@"TrackingEvents"] isKindOfClass:[NSDictionary class]]) {
                            if ([companionCreative[@"TrackingEvents"][@"Tracking"] isKindOfClass:[NSDictionary class]]) {
                                if ([companionCreative[@"TrackingEvents"][@"Tracking"][@"__text"] isKindOfClass:[NSString class]]) {
                                    _creativeTrackingUrl = companionCreative[@"TrackingEvents"][@"Tracking"][@"__text"];
                                }
                            }
                        }
                        
                        if ([companionCreative[@"CompanionClickThrough"] isKindOfClass:[NSString class]]) {
                            _clickthroughUrl = companionCreative[@"CompanionClickThrough"];
                        }
                        
                    }
                    
                }
                
            }
            
        }
        
    }
}

@end
