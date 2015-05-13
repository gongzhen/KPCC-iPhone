//
//  SCPRPullDownMenu.m
//  KPCC
//
//  Created by John Meeker on 9/12/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRPullDownMenu.h"
#import "SCPRMenuCell.h"
#import "UIColor+UICustom.h"
#import "AnalyticsManager.h"
#import "NetworkManager.h"

#define kMenuItemKPCCLive   @"KPCC Live"
#define kMenuItemPrograms   @"Programs"
#define kMenuItemShortList  @"Headlines"
#define kMenuItemAlarm      @"Wake / Sleep"
#define kMenuItemDonate     @"Donate"
#define kMenuItemSettings   @"Settings"
#define kMenuItemFeedback   @"Feedback"

#define kIconKPCCLive   @"antenna"
#define kIconPrograms   @"microphone"
#define kIconShortList  @"glasses"
#define kIconAlarm      @"clock"
#define kIconDonate     @"heart-plus"
#define kIconSettings   @"settings"
#define kIconFeedback   @"feedback"

@implementation SCPRPullDownMenu

@synthesize menuList,
            handle,
            cellHeight,
            handleHeight,
            animationDuration,
            topMarginLandscape,
            topMarginPortrait,
            cellColor,
            cellFont,
            cellTextColor,
            cellSelectedColor,
            cellSelectionStyle,
            separatorColor,
            fullyOpen,
            delegate;

- (instancetype)init {
    self = [super init];

    NSOrderedSet* orderedItems = [NSOrderedSet orderedSetWithObjects:   kMenuItemKPCCLive,
                                                                        kMenuItemPrograms,
                                                                        kMenuItemShortList,
                                                                        kMenuItemAlarm,
                                                                        kMenuItemDonate,
                                                                        kMenuItemFeedback,
                                                                        //
                                                                        //kMenuItemSettings,
                                                                        nil];

    menuItemsDictionary = @{kMenuItemKPCCLive   : kIconKPCCLive,
                            kMenuItemPrograms   : kIconPrograms,
                            kMenuItemShortList  : kIconShortList,
                            kMenuItemAlarm      : kIconAlarm,
                            kMenuItemDonate     : kIconDonate,
                            kMenuItemSettings   : kIconSettings,
                            kMenuItemFeedback   : kIconFeedback };

    menuItems = [[NSMutableArray alloc] init];
    for (NSString *menuItem in orderedItems) {
        [self insertButton:menuItem];
    }

    // Setting defaults
    cellHeight = 62.0f;
    handleHeight = 0.f;
    animationDuration = 0.3f;
    topMarginPortrait = 100;
    topMarginLandscape = 0;
    cellColor = [UIColor clearColor];
    cellSelectedColor = [[UIColor virtualWhiteColor] translucify:0.2];
    cellFont = [UIFont fontWithName:@"FreightSansProLight-Regular" size:24.0f];
    cellTextColor = [UIColor whiteColor];
    cellSelectionStyle = UITableViewCellSelectionStyleDefault;
    separatorColor = [UIColor colorWithRed:222.f/255.f green:228.f/255.f blue:229.f/255.f alpha:0.3f];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refresh)
                                                 name:@"network-status-good"
                                               object:nil];
    
    [[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(refresh)
                                                 name:@"network-status-fail"
                                               object:nil];

    [menuList setScrollEnabled:NO];

    return self;
}

- (instancetype)initWithView:(UIView *)view {
    self = [self init];

    if (self)
    {
        topMargin = 0;
        masterView = view;
    }

    return self;
}

- (void)refresh {
    [self.menuList reloadData];
}

- (void)lightUpCellWithIndex:(NSInteger)index {
    [self.menuList selectRowAtIndexPath:[NSIndexPath indexPathForItem:index inSection:0]
                               animated:YES
                         scrollPosition:UITableViewScrollPositionNone];
}

- (void)clearMenu {
    for ( unsigned i = 0; i < [menuItems count]; i++ ) {
        [self.menuList deselectRowAtIndexPath:[NSIndexPath indexPathForItem:i
                                                                  inSection:0]
                                     animated:YES];
    }
}

- (void)loadMenu {
    tableHeight = ([menuItems count] * cellHeight);

    [self updateValues];

    [self setFrame:CGRectMake(0, -tableHeight, 320, tableHeight)];
    [self setTag:893];

    fullyOpen = NO;

    menuList = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, tableHeight + 20)];
    [menuList setRowHeight:cellHeight];
    [menuList setDataSource:self];
    [menuList setDelegate:self];
    [menuList setBackgroundColor:[UIColor clearColor]];
    [menuList setSeparatorColor:separatorColor];

    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.frame.size.width, 20)];
    [menuList setTableHeaderView:headerView];
    [self addSubview:menuList];
}

- (void)insertButton:(NSString *)title {
    [menuItems addObject:title];
}


# pragma mark - TableView delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self.delegate menuItemSelected:indexPath];
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    return [menuItems count];
}

- (SCPRMenuCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    SCPRMenuCell *cell = [tableView dequeueReusableCellWithIdentifier:@"menuListCell"];
    if (cell == nil) {
        cell = [[SCPRMenuCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"menuListCell"];
    }

    cell.backgroundColor = cellColor;

    UIView *cellSelectedBackgroundView = [[UIView alloc] initWithFrame:cell.frame];
    cellSelectedBackgroundView.backgroundColor = [self cellSelectedColor];
    cellSelectedBackgroundView.alpha = 0.7f;
    cell.selectedBackgroundView = cellSelectedBackgroundView;
    cell.selectionStyle = [self cellSelectionStyle];

    [cell.menuItemLabel setTextColor:[self cellTextColor]];
    cell.menuItemLabel.font = [self cellFont];
    [cell.menuItemLabel setText:menuItems[indexPath.item]];

    BOOL chevronStatus = NO;
    if ( [menuItems[indexPath.item] isEqualToString:kMenuItemKPCCLive]) {
        chevronStatus = YES;
    }

    [cell.rightChevronImageView setHidden:chevronStatus];
    
    NSString *iconNamed = menuItemsDictionary[menuItems[indexPath.item]];
    if (iconNamed) {
        UIImage *iconImg = [UIImage imageNamed:[NSString stringWithFormat:@"menu-%@", iconNamed]];
        [cell.iconImageView setImage:iconImg];
        cell.iconImageView.frame = CGRectMake(8.0, 8.0,
                                              44.0,
                                              44.0);
        
        cell.iconImageView.contentMode = UIViewContentModeCenter;
    }

#ifndef DISABLE_INTERRUPT
    if ( [[NetworkManager shared] networkDown] ) {
        cell.menuItemLabel.alpha = 0.35;
        cell.iconImageView.alpha = 0.35;
        cell.userInteractionEnabled = NO;
        [cell.rightChevronImageView setHidden:YES];
    } else {
        cell.menuItemLabel.alpha = 1.0f;
        cell.iconImageView.alpha = 1.0f;
        cell.userInteractionEnabled = YES;
        [cell.rightChevronImageView setHidden:chevronStatus];
    }
#endif
    
    return cell;
}

-(void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath {

    if ([tableView respondsToSelector:@selector(setSeparatorInset:)]) {
        [tableView setSeparatorInset:UIEdgeInsetsMake(0, 8, 0, 8)];
    }

    if ([tableView respondsToSelector:@selector(setLayoutMargins:)]) {
        [tableView setLayoutMargins:UIEdgeInsetsMake(0, 8, 0, 8)];
    }

    if ([cell respondsToSelector:@selector(setLayoutMargins:)]) {
        [cell setLayoutMargins:UIEdgeInsetsMake(0, 8, 0, 8)];
    }
}


# pragma mark - Menu open and close

- (void)animateDropDown {

    [UIView animateWithDuration: animationDuration
                          delay: 0.0
                        options: UIViewAnimationOptionCurveEaseOut
                     animations:^{
                         if (fullyOpen)
                         {
                             self.center = CGPointMake(self.frame.size.width / 2, -((self.frame.size.height / 2) + topMargin));
                             fullyOpen = NO;
                         }
                         else
                         {
                             self.center = CGPointMake(self.frame.size.width / 2, ((self.frame.size.height / 2) + topMargin));
                             fullyOpen = YES;
                         }
                     }
                     completion:^(BOOL finished){
                         [delegate pullDownAnimated:fullyOpen];
                     }];
}

- (void)openDropDown:(BOOL)animated {
    
    [[AnalyticsManager shared] logEvent:@"menuOpened"
                         withParameters:@{}];
    
    if (animated)
    {
        [UIView animateWithDuration: animationDuration
                              delay: 0.0
                            options: UIViewAnimationOptionCurveEaseOut
                         animations:^{
                             if (!fullyOpen)
                             {
                                 self.center = CGPointMake(self.frame.size.width / 2, (/*(self.frame.size.height / 2) +*/ topMargin + (([menuItems count]*3.0) * [menuItems count])));
                                 fullyOpen = YES;
                             }
                         }
                         completion:^(BOOL finished){
                             [delegate pullDownAnimated:fullyOpen];
                         }];
    }
    else
    {
        if (!fullyOpen)
        {
            self.center = CGPointMake(self.frame.size.width / 2, (/*(self.frame.size.height / 2) +*/ topMargin));
            fullyOpen = YES;
        }
    }
}

- (void)closeDropDown:(BOOL)animated {

    [[AnalyticsManager shared] logEvent:@"menuClosed"
                         withParameters:@{}];
    
    if (animated)
    {
        [UIView animateWithDuration: animationDuration
                              delay: 0.0
                            options: UIViewAnimationOptionCurveEaseOut
                         animations:^{
                             if (fullyOpen)
                             {
                                 self.center = CGPointMake(self.frame.size.width / 2, -((self.frame.size.height / 2) + topMargin - 20.0));
                                 fullyOpen = NO;
                             }
                         }
                         completion:^(BOOL finished){
                             [delegate pullDownAnimated:fullyOpen];
                         }];
    }
    else
    {
        if (fullyOpen)
        {
            self.center = CGPointMake(self.frame.size.width / 2, -((self.frame.size.height / 2) + topMargin));
            fullyOpen = NO;
        }
    }
}

- (void)updateValues {
    topMargin = 0;

    BOOL isStatusBarShowing = ![[UIApplication sharedApplication] isStatusBarHidden];

    if (UIInterfaceOrientationIsLandscape(self.window.rootViewController.interfaceOrientation)) {
        if (isStatusBarShowing) { topMargin = [UIApplication.sharedApplication statusBarFrame].size.width; }
        topMargin += topMarginLandscape;
    }
    else
    {
        if (isStatusBarShowing) { topMargin = [UIApplication.sharedApplication statusBarFrame].size.height; }
        topMargin += (/*([menuItems count] * cellHeight) +*/ topMarginPortrait);
    }

    if (masterNavigationController != nil)
    {
        topMargin += masterNavigationController.navigationBar.frame.size.height;
    }
}

@end
