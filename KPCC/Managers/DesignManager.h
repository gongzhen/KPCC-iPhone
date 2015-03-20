//
//  DesignManager.h
//  KPCC
//
//  Created by John Meeker on 9/10/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <Foundation/Foundation.h>


typedef NS_ENUM(NSInteger, SculptingStyle) {
    SculptingStyleNormal = 0,
    SculptingStylePeriwinkle,
    SculptingStyleClearWithBorder
};


@interface DesignManager : NSObject

+ (DesignManager*)shared;

- (void)loadProgramImage:(NSString *)slug andImageView:(UIImageView *)imageView completion:(void (^)(BOOL status))completion;
@property (NS_NONATOMIC_IOSONLY, readonly) CGRect screenFrame;
- (void)loadStockPhotoToImageView:(UIImageView*)imageView;
- (UIView*)textHeaderWithText:(NSString *)text textColor:(UIColor*)color backgroundColor:(UIColor*)backgroundColor;
- (UIView*)textHeaderWithText:(NSString *)text textColor:(UIColor *)color backgroundColor:(UIColor *)backgroundColor divider:(BOOL)divider;
- (void)sculptButton:(UIButton*)button withStyle:(SculptingStyle)style andText:(NSString*)text;

// Layouts
- (NSArray*)typicalConstraints:(UIView *)view withTopOffset:(CGFloat)topOffset fullscreen:(BOOL)fullscreen;
- (NSArray*)sizeConstraintsForView:(UIView *)view;
- (NSArray*)sizeConstraintsForView:(UIView *)view hints:(NSDictionary*)hints;

- (NSLayoutConstraint*)snapView:(id)view toContainer:(id)container withTopOffset:(CGFloat)topOffset;
- (NSLayoutConstraint*)snapView:(id)view toContainer:(id)container withTopOffset:(CGFloat)topOffset fullscreen:(BOOL)fullscreen;

// Fonts
- (UIFont*)proBook:(CGFloat)size;
- (UIFont*)proBold:(CGFloat)size;
- (UIFont*)proLight:(CGFloat)size;
- (UIFont*)proMedium:(CGFloat)size;

- (void)normalizeBar;
- (void)treatBar;
- (void)fauxHideNavigationBar:(UIViewController*)root;
- (void)fauxRevealNavigationBar;

@property BOOL displayingStockPhoto;
@property BOOL barNormalized;
@property BOOL protectBlurredImage;

@property (nonatomic, strong) UIImage *currentBlurredImage;
@property (nonatomic, strong) UIImage *currentBlurredLiveImage;
@property (nonatomic, strong) NSDictionary *attributes;
@property (nonatomic, strong) UIView *navbarMask;

@property (nonatomic, weak) UINavigationBar *hiddenNavBar;

#ifdef TEST_PROGRAM_IMAGE
@property (nonatomic,strong) NSString *currentSlug;
#endif

@end
