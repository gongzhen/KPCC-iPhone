//
//  DesignManager.m
//  KPCC
//
//  Created by John Meeker on 9/10/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "DesignManager.h"
#import "Utils.h"
#import "AFNetworking.h"
#import "UIImageView+AFNetworking.h"
#import <POP/POP.h>
#import "SCPRAppDelegate.h"

#define kMediaServerPath @"http://media.scpr.org/iphone/program-images/"

static DesignManager *singleton = nil;


@implementation DesignManager

+ (DesignManager*)shared {
    if (!singleton) {
        @synchronized(self) {
            singleton = [[DesignManager alloc] init];
        }
    }
    return singleton;
}

/**
 * Async request to fetch image and set in image view with given program slug. Via AFNetworking.
 *
 */
- (void)loadProgramImage:(NSString *)slug andImageView:(UIImageView *)imageView completion:(void (^)(BOOL status))completion {

    if (![Utils pureNil:slug]) {

        // TODO: Account for @3x.
        NSString *slugWithScale;
        if ([Utils isRetina]) {
            slugWithScale = [NSString stringWithFormat:@"%@@2x", slug];
        } else {
            slugWithScale = slug;
        }

        NSURL *imageUrl = [NSURL URLWithString:[NSString stringWithFormat:@"%@program_tile_%@.jpg", kMediaServerPath, slugWithScale]];
        NSMutableURLRequest *request = [NSMutableURLRequest requestWithURL:imageUrl];
#ifdef TEST_PROGRAM_IMAGE
        if ( self.currentSlug ) {
            if ( SEQ(self.currentSlug,slug) ) {
                if ( !self.displayingStockPhoto ) {
                    [self loadStockPhotoToImageView:imageView];
                    return;
                }
            }
        } else {
            self.currentSlug = slug;
        }
#endif
        
        UIImageView *iv = imageView;
        [iv setImageWithURLRequest:request placeholderImage:nil success:^(NSURLRequest *request, NSHTTPURLResponse *response, UIImage *image) {
            
            self.displayingStockPhoto = NO;
            dispatch_async(dispatch_get_main_queue(), ^{
                imageView.image = image;
                imageView.alpha = 1.0;
                CATransition *transition = [CATransition animation];
                transition.duration = kFadeDuration;
                transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
                transition.type = kCATransitionFade;
                
                [imageView.layer addAnimation:transition
                                  forKey:nil];
            });
            
            

            completion(true);
        } failure:^(NSURLRequest *request, NSHTTPURLResponse *response, NSError *error) {
            [self loadStockPhotoToImageView:imageView];
            completion(true);
        }];
    } else {
        [self loadStockPhotoToImageView:imageView];
        completion(true);
    }
}

- (void)loadStockPhotoToImageView:(UIImageView *)imageView {
    
    self.displayingStockPhoto = YES;
    [imageView setImage:[UIImage imageNamed:@"program_tile_generic.jpg"]];
    imageView.alpha = 1.0;
    CATransition *transition = [CATransition animation];
    transition.duration = kFadeDuration;
    transition.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseOut];
    transition.type = kCATransitionFade;
    
    [imageView.layer addAnimation:transition
                           forKey:nil];
    
}

#pragma mark - View Factory
- (UIView*)textHeaderWithText:(NSString *)text textColor:(UIColor*)color backgroundColor:(UIColor*)backgroundColor {
    return [self textHeaderWithText:text textColor:color backgroundColor:backgroundColor divider:YES];
}

- (UIView*)textHeaderWithText:(NSString *)text textColor:(UIColor *)color backgroundColor:(UIColor *)backgroundColor divider:(BOOL)divider {
    UIView *header = [[UIView alloc] initWithFrame:CGRectMake(0.0,0.0,768.0,36.0)];
    header.backgroundColor = backgroundColor;
    UILabel *captionLabel = [[UILabel alloc] initWithFrame:CGRectMake(0.0,0.0, 768.0, 36.0)];
    captionLabel.font = [UIFont systemFontOfSize:14.0];
    captionLabel.backgroundColor = [UIColor clearColor];
    captionLabel.textColor = color;
    [captionLabel proSemiBoldFontize];
    [captionLabel setText:[NSString stringWithFormat:@"  %@",text]];
    
    [header addSubview:captionLabel];
    return header;
}

- (CGRect)screenFrame {
    SCPRAppDelegate *del = (SCPRAppDelegate*)[[UIApplication sharedApplication] delegate];
    UIWindow *window = [del window];
    return CGRectMake(0.0, 0.0, window.bounds.size.width,
                      window.bounds.size.height);
}

#pragma mark - Makeovers
- (void)sculptButton:(UIButton *)button withStyle:(SculptingStyle)style andText:(NSString *)text {
    [button setTitle:text forState:UIControlStateNormal];
    [button setTitle:text forState:UIControlStateHighlighted];
    [button.titleLabel proSemiBoldFontize];
    
    switch (style) {
        case SculptingStylePeriwinkle:
        {
            button.backgroundColor = [UIColor kpccPeriwinkleColor];
            [button setTitleColor:[UIColor whiteColor]
                         forState:UIControlStateNormal];
            [button setTitleColor:[[UIColor virtualWhiteColor] translucify:0.75]
                         forState:UIControlStateHighlighted];
            break;
        }
        case SculptingStyleClearWithBorder:
        {
            button.backgroundColor = [UIColor clearColor];
            button.layer.borderColor = [UIColor virtualWhiteColor].CGColor;
            button.layer.borderWidth = 1.0;
            [button setTitleColor:[UIColor whiteColor]
                         forState:UIControlStateNormal];
            [button setTitleColor:[[UIColor virtualWhiteColor] translucify:0.75]
                         forState:UIControlStateHighlighted];
            break;
        }
        case SculptingStyleNormal:
        default:
        {
            
            
        }
    }
}

#pragma mark - Fonts
- (UIFont*)proLight:(CGFloat)size {
    return [UIFont fontWithName:@"FreightSansProLight-Regular" size:size];
}

- (UIFont*)proMedium:(CGFloat)size {
    return [UIFont fontWithName:@"FreightSansProMedium-Regular" size:size];
}

- (UIFont*)proBook:(CGFloat)size {
    return [UIFont fontWithName:@"FreightSansProBook-Regular" size:size];
}

- (UIFont*)proBold:(CGFloat)size {
    return [UIFont fontWithName:@"FreightSansProSemibold-Regular" size:size];

}

@end
