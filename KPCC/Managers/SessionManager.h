//
//  SessionManager.h
//  KPCC
//
//  Created by Ben Hochberg on 11/4/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Utils.h"
#import "Program.h"


@interface SessionManager : NSObject

+ (SessionManager*)shared;

@property (nonatomic, copy) NSDate *sessionLeftDate;
@property (nonatomic, copy) NSDate *sessionReturnedDate;
@property (nonatomic, copy) NSDate *lastProgramUpdate;
@property (nonatomic, strong) NSTimer *programUpdateTimer;
@property BOOL useLocalNotifications;
@property BOOL sessionEndedWhilePaused;

@property (nonatomic, strong) Program *currentProgram;

- (void)fetchCurrentProgram:(CompletionBlockWithValue)completed;
- (void)fetchProgramAtDate:(NSDate*)date completed:(CompletionBlockWithValue)completed;

- (void)armProgramUpdater;
- (void)disarmProgramUpdater;

- (void)processNotification:(UILocalNotification*)programUpdate;
- (BOOL)ignoreProgramUpdating;

- (void)handleSessionReactivation;

@end
