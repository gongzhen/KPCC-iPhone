//
//  SCPRCompleteScheduleViewController.m
//  KPCC
//
//  Created by Ben Hochberg on 5/5/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import "SCPRCompleteScheduleViewController.h"
#import "NetworkManager.h"
#import "SessionManager.h"
#import "SCPRScheduleHeaderViewController.h"
#import "SCPRScheduleTableViewCell.h"

@interface SCPRCompleteScheduleViewController ()

@end

@implementation SCPRCompleteScheduleViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    self.view.backgroundColor = [UIColor clearColor];
    self.scheduleTable.backgroundColor = [UIColor clearColor];
    self.scheduleTable.separatorColor = [UIColor clearColor];
    
    // Do any additional setup after loading the view from its nib.
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

- (void)setupSchedule {
    
    [[SessionManager shared] fetchScheduleForTodayAndTomorrow:^(id returnedObject) {
        
        if ( returnedObject ) {
            
            NSDate *now = [[SessionManager shared] vNow];
            NSDateComponents *comps = [[NSCalendar currentCalendar] components:NSCalendarUnitDay|NSCalendarUnitWeekday|NSCalendarUnitWeekOfMonth|NSCalendarUnitMonth|NSCalendarUnitYear
                                                                      fromDate:now];
            NSInteger weekday = [comps weekday]; // In the U.S. Sunday == 1 not 0.... like the *entire rest of the world*
            self.todayInEnglish = @"TODAY";
            
            NSInteger tomorrowWeekday = [comps weekday]+1;
            if ( tomorrowWeekday > 7 ) {
                tomorrowWeekday = 1;
            }
            
            NSLog(@"Date Components : %@",[comps description]);
            
            self.programObjects = returnedObject;
            self.todayPrograms = [NSMutableArray new];
            self.tomorrowPrograms = [NSMutableArray new];
            
            for ( unsigned i = 0; i < self.programObjects.count; i++ ) {
                NSDictionary *program = self.programObjects[i];
                NSString *dateStr = program[@"starts_at"];
                NSDate *date = [Utils dateFromRFCString:dateStr];
                NSDateComponents *localComps = [[NSCalendar currentCalendar] components:NSCalendarUnitDay|NSCalendarUnitWeekday|NSCalendarUnitWeekOfMonth|NSCalendarUnitMonth|NSCalendarUnitYear
                                                                          fromDate:date];
                if ( [localComps weekday] == weekday ) {
                    [self.todayPrograms addObject:program];
                } else {
                    [self.tomorrowPrograms addObject:program];
                }
            }
            
            self.headerVector = [NSMutableArray new];
            if ( self.todayPrograms.count > 0 ) {
                SCPRScheduleHeaderViewController *header1 = [[SCPRScheduleHeaderViewController alloc] initWithNibName:@"SCPRScheduleHeaderViewController"
                                                                                                               bundle:nil];
                header1.view.frame = header1.view.frame;
                [header1 setupWithText:self.todayInEnglish];
                [self.headerVector addObject:header1];
            }
            
            if ( self.tomorrowPrograms.count > 0 ) {
                self.tomorrowInEnglish = [self mapForWeekday:tomorrowWeekday];
                SCPRScheduleHeaderViewController *header2 = [[SCPRScheduleHeaderViewController alloc] initWithNibName:@"SCPRScheduleHeaderViewController"
                                                                                                               bundle:nil];
                header2.view.frame = header2.view.frame;
                [header2 setupWithText:self.tomorrowInEnglish];
                [self.headerVector addObject:header2];
            }
            
            self.scheduleTable.dataSource = self;
            self.scheduleTable.delegate = self;
            [self.scheduleTable reloadData];
            
        }
        
    }];
    
}

- (NSString*)mapForWeekday:(NSInteger)weekday {
    
    NSString *english = @"";
    switch (weekday) {
        case 1:
            english = @"SUNDAY";
            break;
        case 2:
            english = @"MONDAY";
            break;
        case 3:
            english = @"TUESDAY";
            break;
        case 4:
            english = @"WEDNESDAY";
            break;
        case 5:
            english = @"THURSDAY";
            break;
        case 6:
            english = @"FRIDAY";
            break;
        case 7:
            english = @"SATURDAY";
            break;
        default:
            break;
    }
    
    return english;
}

#pragma mark - UITableView
- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    if ( [self.todayPrograms count] > 0 && [self.tomorrowPrograms count] > 0 ) {
        return 2;
    }
    
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section {
    if ( section == 0 ) {
        if ( [self.todayPrograms count] > 0 ) {
            return self.todayPrograms.count;
        }
        
        return self.tomorrowPrograms.count;
    }
    if ( section == 1 ) {
        return self.tomorrowPrograms.count;
    }
    
    return 0;
}

- (UITableViewCell*)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath {
    
    SCPRScheduleTableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:[SCPRScheduleTableViewCell rui]];
    if ( !cell ) {
        NSArray *objects = [[NSBundle mainBundle] loadNibNamed:@"SCPRScheduleTableViewCell"
                                                         owner:nil
                                                       options:nil];
        cell = objects[0];
    }
    
    NSArray *arrayToUse = nil;
    if ( indexPath.section == 0 ) {
        if ( self.todayPrograms.count > 0 ) {
            arrayToUse = self.todayPrograms;
        } else {
            arrayToUse = self.tomorrowPrograms;
        }
    } else if ( indexPath.section == 1 ) {
        arrayToUse = self.tomorrowPrograms;
    }
    
    NSDictionary *program = arrayToUse[indexPath.row];
    [cell setupWithProgram:program];
    
    return cell;
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath {
    return 45.0f;
}

- (UIView*)tableView:(UITableView *)tableView viewForHeaderInSection:(NSInteger)section {
    SCPRScheduleHeaderViewController *hvc = self.headerVector[section];
    return hvc.view;
}

- (CGFloat)tableView:(UITableView *)tableView heightForHeaderInSection:(NSInteger)section {
    return 31.0f;
}

/*
#pragma mark - Navigation

// In a storyboard-based application, you will often want to do a little preparation before navigation
- (void)prepareForSegue:(UIStoryboardSegue *)segue sender:(id)sender {
    // Get the new view controller using [segue destinationViewController].
    // Pass the selected object to the new view controller.
}
*/

@end
