//
//  SCPRCompleteScheduleViewController.h
//  KPCC
//
//  Created by Ben Hochberg on 5/5/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>

@interface SCPRCompleteScheduleViewController : UIViewController<UITableViewDataSource,UITableViewDelegate>

@property (nonatomic, strong) IBOutlet UITableView *scheduleTable;
@property (nonatomic, strong) NSArray *programObjects;
@property (nonatomic, strong) NSMutableArray *todayPrograms;
@property (nonatomic, strong) NSMutableArray *tomorrowPrograms;
@property (nonatomic, copy) NSString *todayInEnglish;
@property (nonatomic, copy) NSString *tomorrowInEnglish;
@property (nonatomic, strong) NSMutableArray *headerVector;

- (void)setupSchedule;
- (NSString*)mapForWeekday:(NSInteger)weekday;

@end
