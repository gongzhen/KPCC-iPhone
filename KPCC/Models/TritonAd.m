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

- (instancetype)initWithDict:(NSDictionary *)dictionary {
    if ((self = [super init])) {

        if (dictionary[@"_id"]) {
            self.adId = dictionary[@"_id"];
        }

        if (dictionary[@"InLine"]) {
            NSDictionary *inlineDict = [[NSDictionary alloc] initWithDictionary:dictionary[@"InLine"]];

            // Impression URL
            if (inlineDict[@"Impression"] && inlineDict[@"Impression"][@"__text"]) {
                self.impressionUrl = inlineDict[@"Impression"][@"__text"];
            }

            // Ad assets
            if (inlineDict[@"Creatives"] && inlineDict[@"Creatives"][@"Creative"]) {
                NSArray *creatives = inlineDict[@"Creatives"][@"Creative"];
                if (creatives && [creatives count] > 0) {

                    // Audio component
                    NSDictionary *firstCreative = creatives[0];
                    if (firstCreative[@"Linear"]) {
                        NSDictionary *audioAsset = firstCreative[@"Linear"];

                        // File duration
                        if (audioAsset[@"Duration"]) {
                            NSArray* tokens = [audioAsset[@"Duration"] componentsSeparatedByString:@":"];
                            double lengthInSeconds = 0;
                            for (int i = 0 ; i != tokens.count ; i++) {
                                lengthInSeconds = 60 *lengthInSeconds + [tokens[i] doubleValue];
                            }
                            self.audioCreativeDuration = @(lengthInSeconds);
                        }

                        // Audio file url
                        if (audioAsset[@"MediaFiles"] && audioAsset[@"MediaFiles"][@"MediaFile"]) {
                            NSDictionary *audioFile = audioAsset[@"MediaFiles"][@"MediaFile"];
                            if (audioFile[@"__text"]) {
                                self.audioCreativeUrl = audioFile[@"__text"];
                            }
                        }
                    }

                    // Image component
                    if (creatives[1]) {
                        NSDictionary *secondCreative = creatives[1];
                        if (secondCreative[@"CompanionAds"][@"Companion"]) {
                            NSArray *imageAssets = secondCreative[@"CompanionAds"][@"Companion"];
                            NSDictionary *staticResource;

                            for (NSDictionary *imgAsset in imageAssets) {
                                if (imgAsset[@"StaticResource"]) {
                                    staticResource = imgAsset;
                                    break;
                                }
                            }

                            if (staticResource) {
                                
                                // Clickthrough
                                if ( staticResource[@"CompanionClickThrough"] ) {
                                    self.clickthroughUrl = staticResource[@"CompanionClickThrough"];
                                }
                                
                                // Image file url
                                if (staticResource[@"StaticResource"][@"__text"]) {
                                    self.imageCreativeUrl = staticResource[@"StaticResource"][@"__text"];
                                }

                                // Image dimensions
                                if (staticResource[@"_height"]) {
                                    self.imageCreativeHeight = @([staticResource[@"_height"] doubleValue]);
                                }
                                if (staticResource[@"_width"]) {
                                    self.imageCreativeWidth = @([staticResource[@"_width"] doubleValue]);
                                }

                                // URL for tracking clicks?
                                if (staticResource[@"TrackingEvents"] && staticResource[@"TrackingEvents"][@"Tracking"]) {
                                    if (staticResource[@"TrackingEvents"][@"Tracking"][@"__text"]) {
                                        self.creativeTrackingUrl = staticResource[@"TrackingEvents"][@"Tracking"][@"__text"];
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
    return self;
}

@end
