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

@import MessageUI;

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
                completion(true);
            });
            
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

#pragma mark - Layouts
- (NSArray*)typicalConstraints:(UIView *)view withTopOffset:(CGFloat)topOffset fullscreen:(BOOL)fullscreen {
    
    [view setTranslatesAutoresizingMaskIntoConstraints:NO];
    NSArray *hConstraints = [NSLayoutConstraint constraintsWithVisualFormat:@"H:|[view]|"
                                                                    options:0
                                                                    metrics:nil
                                                                      views:@{ @"view" : view }];
    
    NSArray *vConstraints = [NSLayoutConstraint constraintsWithVisualFormat:[NSString stringWithFormat:@"V:|-(%ld)-[view]-(0)-|",(long)topOffset]
                                                                    options:0
                                                                    metrics:nil
                                                                      views:@{ @"view" : view }];
    
    
    NSMutableArray *total = [NSMutableArray new];
    
    
    [total addObjectsFromArray:hConstraints];
    [total addObjectsFromArray:vConstraints];
    
    return [NSArray arrayWithArray:total];
}

- (NSArray*)sizeConstraintsForView:(UIView *)view hints:(NSDictionary*)hints {
    
    CGFloat wConstant = hints ? [hints[@"width"] floatValue] : view.frame.size.width;
    CGFloat hConstant = hints ? [hints[@"height"] floatValue] : view.frame.size.height;
    
    NSLayoutConstraint *hConstraint = [NSLayoutConstraint constraintWithItem:view
                                                                   attribute:NSLayoutAttributeHeight
                                                                   relatedBy:NSLayoutRelationEqual
                                                                      toItem:nil
                                                                   attribute:NSLayoutAttributeNotAnAttribute
                                                                  multiplier:1.0
                                                                    constant:hConstant];
    
    NSLayoutConstraint *wConstraint = [NSLayoutConstraint constraintWithItem:view
                                                                   attribute:NSLayoutAttributeWidth
                                                                   relatedBy:NSLayoutRelationEqual
                                                                      toItem:nil
                                                                   attribute:NSLayoutAttributeNotAnAttribute
                                                                  multiplier:1.0
                                                                    constant:wConstant];
    
    return @[ hConstraint, wConstraint ];
    
}

- (NSArray*)sizeConstraintsForView:(UIView *)view {
    return [self sizeConstraintsForView:view hints:nil];
}


- (NSLayoutConstraint*)snapView:(id)view toContainer:(id)container withTopOffset:(CGFloat)topOffset {
    return [self snapView:view toContainer:container withTopOffset:topOffset fullscreen:NO];
}

- (NSLayoutConstraint*)snapView:(id)view toContainer:(id)container withTopOffset:(CGFloat)topOffset fullscreen:(BOOL)fullscreen {
    UIView *v2u = nil;
    UIView *c2u = nil;
    if ( [view isKindOfClass:[UIView class]] ) {
        v2u = view;
    }
    if ( [view isKindOfClass:[UIViewController class]] ) {
        v2u = [(UIViewController*)view view];
    }
    if ( [container isKindOfClass:[UIView class]] ) {
        c2u = container;
    }
    if ( [container isKindOfClass:[UIViewController class]] ) {
        c2u = [(UIViewController*)container view];
    }
    [c2u addSubview:v2u];
    
    CGFloat expectedWidth = c2u.frame.size.width;
    CGFloat expectedHeight = c2u.frame.size.height;
    NSLog(@"Expected width : %1.1f",expectedWidth);
    NSLog(@"Expected height : %1.1f",expectedHeight);
    
    v2u.frame = CGRectMake(0.0, 0.0, expectedWidth,
                           expectedHeight);
    
    
    [v2u setTranslatesAutoresizingMaskIntoConstraints:NO];
    
    NSArray *anchors = [self typicalConstraints:v2u withTopOffset:topOffset fullscreen:fullscreen];
    
    if ( fullscreen ) {
        
        NSArray *constraints = [self sizeConstraintsForView:v2u
                                                      hints:@{ @"width" : @(expectedWidth),
                                                               @"height" : @(expectedHeight) }];
        [v2u addConstraints:constraints];
    }
    
    [c2u setTranslatesAutoresizingMaskIntoConstraints:NO];
    [c2u addConstraints:anchors];
    [c2u setNeedsUpdateConstraints];
    [c2u setNeedsLayout];
    [c2u layoutIfNeeded];
    [v2u setNeedsLayout];
    [v2u layoutIfNeeded];
    
    for ( NSLayoutConstraint *anchor in anchors ) {
        if ( anchor.firstAttribute == NSLayoutAttributeTop && anchor.secondAttribute == NSLayoutAttributeTop ) {
            return anchor;
        }
    }
    
    
    return nil;
    
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

#pragma mark - Appearance
- (void)normalizeBar {
    
    if ( self.barNormalized ) return;
    
    self.attributes = [[UINavigationBar appearance] titleTextAttributes];
    self.barNormalized = YES;
    [[UINavigationBar appearance] setBarStyle:UIBarStyleDefault];
    [[UINavigationBar appearance] setBarTintColor:[UIColor paleHorseColor]];
    [[UINavigationBar appearance] setTitleTextAttributes:@{ NSFontAttributeName : [UIFont boldSystemFontOfSize:18.0],
                                                            NSForegroundColorAttributeName : [UIColor blackColor] }];
}

- (void)treatBar {
    
    if ( !self.barNormalized ) return;
    
    self.barNormalized = NO;
    [[UINavigationBar appearance] setBarStyle:UIBarStyleDefault];
    [[UINavigationBar appearance] setBarTintColor:[UIColor kpccOrangeColor]];
    [[UINavigationBar appearance] setTitleTextAttributes:self.attributes];
    
}

@end
