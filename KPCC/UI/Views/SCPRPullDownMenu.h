//
//  SCPRPullDownMenu.h
//  KPCC
//
//  Created by John Meeker on 9/12/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>

@protocol SCPRMenuDelegate
    -(void)menuItemSelected:(NSIndexPath *)indexPath;
    -(void)pullDownAnimated:(BOOL)open;
@end

@interface SCPRPullDownMenu : UIView<UITableViewDataSource, UITableViewDelegate> {

    UITableView *menuList;
    NSMutableArray *menuItems;
    NSDictionary *menuItemsDictionary;

    UIView *handle;
    UIView *masterView;
    UIPanGestureRecognizer *navigationDragGestureRecognizer;
    UIPanGestureRecognizer *handleDragGestureRecognizer;
    UINavigationController *masterNavigationController;
    UIDeviceOrientation currentOrientation;

    float topMargin;
    float tableHeight;
}

@property (nonatomic, assign) id<SCPRMenuDelegate> delegate;
@property (nonatomic, retain) UITableView *menuList;
@property (nonatomic, retain) UIView *handle;

/* Appearance Properties */
@property (nonatomic) float handleHeight;
@property (nonatomic) float animationDuration;
@property (nonatomic) float topMarginPortrait;
@property (nonatomic) float topMarginLandscape;
@property (nonatomic) UIColor *cellColor;
@property (nonatomic) UIColor *cellSelectedColor;
@property (nonatomic) UIColor *cellTextColor;
@property (nonatomic) UITableViewCellSelectionStyle cellSelectionStyle;
@property (nonatomic) UIFont *cellFont;
@property (nonatomic) UIColor *separatorColor;
@property (nonatomic) float cellHeight;
@property (nonatomic) BOOL fullyOpen;

- (instancetype)initWithView:(UIView *)view;
- (void)insertButton:(NSString *)title;
- (void)loadMenu;
- (void)animateDropDown;
- (void)openDropDown:(BOOL)animated;
- (void)closeDropDown:(BOOL)animated;
- (void)lightUpCellWithIndex:(NSInteger)index;

@end
