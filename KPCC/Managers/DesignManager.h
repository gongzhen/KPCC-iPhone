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

#define kGlobalSpinnerTag 29384
#define WSPIN [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhite]

@interface DesignManager : NSObject

+ (DesignManager*)shared;

- (NSString*)mainLiveStreamTitle;

- (void)loadProgramImage:(NSString *)slug andImageView:(UIImageView *)imageView completion:(void (^)(BOOL status))completion;
@property (NS_NONATOMIC_IOSONLY, readonly) CGRect screenFrame;
- (void)loadStockPhotoToImageView:(UIImageView*)imageView;
- (UIView*)textHeaderWithText:(NSString *)text textColor:(UIColor*)color backgroundColor:(UIColor*)backgroundColor;
- (UIView*)textHeaderWithText:(NSString *)text textColor:(UIColor *)color backgroundColor:(UIColor *)backgroundColor divider:(BOOL)divider;
- (void)sculptButton:(UIButton*)button withStyle:(SculptingStyle)style andText:(NSString*)text;
- (void)sculptButton:(UIButton*)button withStyle:(SculptingStyle)style andText:(NSString*)text iconName:(NSString*)iconName;

- (NSAttributedString*)standardTimeFormatWithString:(NSString*)timeString attributes:(NSDictionary*)attributes;

// Layouts
- (NSArray*)typicalConstraints:(UIView *)view withTopOffset:(CGFloat)topOffset fullscreen:(BOOL)fullscreen;
- (NSDictionary*)sizeConstraintsForView:(UIView *)view;
- (NSDictionary*)sizeConstraintsForView:(UIView *)view hints:(NSDictionary*)hints;
- (NSDictionary*)centeredConstraintsForView:(UIView *)view withinParent:(UIView*)parent;

- (NSLayoutConstraint*)snapView:(id)view toContainer:(id)container withTopOffset:(CGFloat)topOffset;
- (NSLayoutConstraint*)snapView:(id)view toContainer:(id)container withTopOffset:(CGFloat)topOffset fullscreen:(BOOL)fullscreen;

// Fonts
- (UIFont*)proBook:(CGFloat)size;
- (UIFont*)proBold:(CGFloat)size;
- (UIFont*)proLight:(CGFloat)size;
- (UIFont*)proMedium:(CGFloat)size;
- (UIFont*)proBookItalic:(CGFloat)size;

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
@property (nonatomic, weak) UIView *hiddenAccessory;
@property (nonatomic, weak) UINavigationBar *hiddenNavBar;

- (void)switchAccessoryForSpinner:(UIActivityIndicatorView *)spinner toReplace:(UIView *)toReplace callback:(CompletionBlock)callback;

#ifdef TEST_PROGRAM_IMAGE
@property (nonatomic,strong) NSString *currentSlug;
#endif

@end
