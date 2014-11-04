//
//  SCPRPullDownMenu.m
//  KPCC
//
//  Created by John Meeker on 9/12/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRPullDownMenu.h"
#import "SCPRMenuCell.h"

#define kMenuItemKPCCLive   @"KPCC Live"
#define kMenuItemPrograms   @"Programs"
#define kMenuItemShortList  @"Headlines"
#define kMenuItemAlarm      @"Alarm Clock"
#define kMenuItemDonate     @"Donate"
#define kMenuItemSettings   @"Settings"

#define kIconKPCCLive   @"antenna"
#define kIconPrograms   @"microphone"
#define kIconShortList  @"glasses"
#define kIconAlarm      @"clock"
#define kIconDonate     @"heart-plus"
#define kIconSettings   @"settings"


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

- (id)init {
    self = [super init];

    NSOrderedSet* orderedItems = [NSOrderedSet orderedSetWithObjects:   kMenuItemKPCCLive,
                                                                        kMenuItemPrograms,
                                                                        kMenuItemShortList,
                                                                        //kMenuItemAlarm,
                                                                        //kMenuItemDonate,
                                                                        //kMenuItemSettings,
                                                                        nil];

    menuItemsDictionary = @{kMenuItemKPCCLive   : kIconKPCCLive,
                            kMenuItemPrograms   : kIconPrograms,
                            kMenuItemShortList  : kIconShortList,
                            kMenuItemAlarm      : kIconAlarm,
                            kMenuItemDonate     : kIconDonate,
                            kMenuItemSettings   : kIconSettings };

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
    cellSelectedColor = [UIColor lightGrayColor];
    cellFont = [UIFont fontWithName:@"FreightSansProLight-Regular" size:24.0f];
    cellTextColor = [UIColor whiteColor];
    cellSelectionStyle = UITableViewCellSelectionStyleDefault;
    separatorColor = [UIColor colorWithRed:222.f/255.f green:228.f/255.f blue:229.f/255.f alpha:0.3f];

    [menuList setScrollEnabled:NO];

    return self;
}

- (id)initWithView:(UIView *)view {
    self = [self init];

    if (self)
    {
        topMargin = 0;
        masterView = view;
    }

    return self;
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
    [cell.menuItemLabel setText:[menuItems objectAtIndex:indexPath.item]];

    if ([[menuItems objectAtIndex:indexPath.item] isEqualToString:kMenuItemKPCCLive]) {
        [cell.rightChevronImageView setHidden:YES];
    } else {
        [cell.rightChevronImageView setHidden:NO];
    }

    NSString *iconNamed = [menuItemsDictionary objectForKey:[menuItems objectAtIndex:indexPath.item]];
    if (iconNamed) {
        UIImage *iconImg = [UIImage imageNamed:[NSString stringWithFormat:@"menu-%@", iconNamed]];
        [cell.iconImageView setImage:iconImg];
        cell.iconImageView.frame = CGRectMake(cell.iconImageView.frame.origin.x, [self cellHeight]/2 - iconImg.size.height/2,
                                     iconImg.size.width, iconImg.size.height);
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
    if (animated)
    {
        [UIView animateWithDuration: animationDuration
                              delay: 0.0
                            options: UIViewAnimationOptionCurveEaseOut
                         animations:^{
                             if (!fullyOpen)
                             {
                                 self.center = CGPointMake(self.frame.size.width / 2, (/*(self.frame.size.height / 2) +*/ topMargin + 20.0));
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
