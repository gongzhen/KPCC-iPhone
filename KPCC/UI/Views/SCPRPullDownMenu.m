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
#import "DesignManager.h"
#import "UXmanager.h"
#import "SCPRXFSHeaderCell.h"

#define kMenuItemKPCCLive   kMainLiveStreamTitle
#define kMenuItemPrograms   @"Programs"
#define kMenuItemShortList  @"Headlines"
#define kMenuItemAlarm      @"Wake / Sleep"
#define kMenuItemDonate     @"Donate"
#define kMenuItemSettings   @"Settings"
#define kMenuItemFeedback   @"Feedback"
#define kMenuItemProfile @"Profile"

#define kIconKPCCLive   @"antenna"
#define kIconPrograms   @"microphone"
#define kIconShortList  @"glasses"
#define kIconAlarm      @"clock"
#define kIconDonate     @"heart-plus"
#define kIconSettings   @"settings"
#define kIconFeedback   @"feedback"
#define kIconProfile    @"profile"

@implementation SCPRPullDownMenu

@synthesize menuList,
            handle,
            cellHeight,
            handleHeight,
            animationDuration,
            topMarginLandscape,
            topMarginPortrait,
            cellColor,
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
                                                                        /* TODO: When the rest of the SSO flow is complete, re-enable it in the menu
                                                                         kMenuItemProfile,*/
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
                            kMenuItemFeedback   : kIconFeedback,
                            kMenuItemProfile    : kIconProfile };

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
    cellTextColor = [UIColor whiteColor];
    cellSelectionStyle = UITableViewCellSelectionStyleDefault;
    separatorColor = [UIColor colorWithRed:222.f/255.f
                                     green:228.f/255.f
                                      blue:229.f/255.f
                                     alpha:0.3f];
    
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
    
    if ( [[NetworkManager shared] networkDown] ) {
        self.menuList.alpha = 0.4f;
        self.menuList.userInteractionEnabled = NO;
    } else {
        self.menuList.alpha = 1.0f;
        self.menuList.userInteractionEnabled = YES;
    }
    
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

- (void)primeWithType:(MenuType)type {
    self.type = type;
    tableHeight = type == MenuTypeStandard ? ([menuItems count] * cellHeight) : 3 * cellHeight;
    self.menuList.frame = CGRectMake(0, 0, self.frame.size.width, tableHeight + 20);
    [self.menuList reloadData];
}

- (UIFont*)cellFontForIndex:(NSInteger)index {
    
    if ( self.type == MenuTypeXFS ) {
        if ( [[UXmanager shared].settings userHasSelectedXFS] ) {
            if ( index == 2 ) {
                return [[DesignManager shared] proMedium:24.0f];
            } else {
                return [[DesignManager shared] proLight:24.0f];
            }
        } else {
            if ( index == 1 ) {
                return [[DesignManager shared] proMedium:24.0f];
            } else {
                return [[DesignManager shared] proLight:24.0f];
            }
        }
    }
    
    return [[DesignManager shared] proLight:24.0f];
    
}

# pragma mark - TableView delegate
- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath {
    
    [tableView deselectRowAtIndexPath:indexPath animated:YES];
    [self.delegate menuItemSelected:indexPath];
    [self.menuList reloadData];
    
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if ( self.type == MenuTypeStandard ) {
        return [menuItems count];
    } else if ( self.type == MenuTypeXFS ) {
        return 3;
    }
    
    return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

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
    cell.menuItemLabel.font = [self cellFontForIndex:indexPath.row];
    cell.parentMenuTable = self;
    
    if ( self.type == MenuTypeStandard ) {
        
        [cell.menuItemLabel setText:menuItems[indexPath.item]];
    
        BOOL chevronStatus = NO;
        if ( [menuItems[indexPath.item] isEqualToString:kMenuItemKPCCLive]) {
            chevronStatus = YES;
        }

        [cell.rightChevronImageView setHidden:chevronStatus];
        
        NSString *iconNamed = menuItemsDictionary[menuItems[indexPath.item]];
        if (iconNamed) {
            UIImage *iconImg = [UIImage imageNamed:[NSString stringWithFormat:@"menu-%@", iconNamed]];
            [cell shiftForIconWithImage:iconImg];
        }

        /*
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
#endif*/
        
    }
    if ( self.type == MenuTypeXFS ) {
        if ( indexPath.row == 0 ) {
            NSArray *objects = [[NSBundle mainBundle] loadNibNamed:@"SCPRXFSHeaderCell"
                                                             owner:nil
                                                           options:nil];
            SCPRXFSHeaderCell *header = (SCPRXFSHeaderCell*)objects[0];
            [header setSelectionStyle:UITableViewCellSelectionStyleNone];
            [header prep];
            return header;
        } else {
            
            cell.selectionStyle = UITableViewCellSelectionStyleNone;
            cell.rightChevronImageView.hidden = YES;
            UIImage *sa = [UIImage imageNamed:@"stream-antenna.png"];
            if ( indexPath.row == 1 ) {
                cell.menuItemLabel.text = @"KPCC Live";
                if ( [[UXmanager shared].settings userHasSelectedXFS] ) {
                    [cell unshiftForIcon];
                } else {
                    [cell shiftForIconWithImage:sa];
                }
            } else {
                cell.menuItemLabel.text = @"KPCC Plus";
                if ( ![[UXmanager shared].settings userHasSelectedXFS] ) {
                    [cell unshiftForIcon];
                } else {
                    [cell shiftForIconWithImage:sa];
                }
            }
        }
    }
    
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
    
    if ( self.type == MenuTypeStandard ) {
       /* [[AnalyticsManager shared] logEvent:@"menuOpened"
                             withParameters:@{}];*/
    }
    
    if (animated)
    {
        [UIView animateWithDuration: animationDuration
                              delay: 0.0
                            options: UIViewAnimationOptionCurveEaseOut
                         animations:^{
                             if (!fullyOpen)
                             {
//                                 NSInteger numberToUse = self.type == MenuTypeStandard ? [menuItems count] : 6;
                                 self.frame = CGRectMake(0.0f,40.0f,self.frame.size.width,self.frame.size.height);
                                 fullyOpen = YES;
                             }
                         }
                         completion:^(BOOL finished){
                             if ( self.type == MenuTypeStandard ) {
                                 [delegate pullDownAnimated:fullyOpen];
                             }
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

    if ( self.type == MenuTypeStandard ) {
        /*[[AnalyticsManager shared] logEvent:@"menuClosed"
                         withParameters:@{}];*/
    }
    
    if (animated)
    {
        [UIView animateWithDuration: animationDuration
                              delay: 0.0
                            options: UIViewAnimationOptionCurveEaseOut
                         animations:^{
                             if (fullyOpen)
                             {
                                 self.frame = CGRectMake(0.0f, -1.0*self.frame.size.height-40.0f,
                                                         self.frame.size.width,
                                                         self.frame.size.height);
                                 fullyOpen = NO;
                             }
                         }
                         completion:^(BOOL finished){
                             self.alpha = 0.0f;
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

//    if (UIInterfaceOrientationIsLandscape(self.window.rootViewController.interfaceOrientation)) {
//        if (isStatusBarShowing) { topMargin = [UIApplication.sharedApplication statusBarFrame].size.width; }
//        topMargin += topMarginLandscape;
//    }
//    else
//    {
        if (isStatusBarShowing) { topMargin = [UIApplication.sharedApplication statusBarFrame].size.height; }
        topMargin += (/*([menuItems count] * cellHeight) +*/ topMarginPortrait);
//    }

    if (masterNavigationController != nil)
    {
        topMargin += masterNavigationController.navigationBar.frame.size.height;
    }
}

@end
