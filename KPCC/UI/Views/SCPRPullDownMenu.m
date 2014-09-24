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
#define kMenuItemShortList  @"The Short List"
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

- (id)init {
    self = [super init];

    NSOrderedSet* orderedItems = [NSOrderedSet orderedSetWithObjects:   kMenuItemKPCCLive,
                                                                        kMenuItemPrograms,
                                                                        //kMenuItemShortList,
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

    for (NSString *menuItem in orderedItems) {
        [self insertButton:menuItem];
    }

    [menuList setScrollEnabled:NO];

    return self;
}

- (void)insertButton:(NSString *)title {
    [super insertButton:title];
}

- (SCPRMenuCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {

    SCPRMenuCell *cell = [tableView dequeueReusableCellWithIdentifier:@"menuListCell"];
    if (cell == nil) {
        cell = [[SCPRMenuCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:@"menuListCell"];
    }

    cell.backgroundColor = [super cellColor];

    UIView *cellSelectedBackgroundView = [[UIView alloc] initWithFrame:cell.frame];
    cellSelectedBackgroundView.backgroundColor = [super cellSelectedColor];
    cellSelectedBackgroundView.alpha = 0.7f;
    cell.selectedBackgroundView = cellSelectedBackgroundView;
    cell.selectionStyle = [super cellSelectionStyle];

    [cell.menuItemLabel setTextColor:[super cellTextColor]];
    cell.menuItemLabel.font = [super cellFont];
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
        cell.iconImageView.frame = CGRectMake(cell.iconImageView.frame.origin.x, [super cellHeight]/2 - iconImg.size.height/2,
                                     iconImg.size.width, iconImg.size.height);
    }

    return cell;
}

-(void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath{

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

@end
