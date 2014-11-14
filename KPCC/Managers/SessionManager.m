//
//  SessionManager.m
//  KPCC
//
//  Created by Ben Hochberg on 11/4/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SessionManager.h"
#import "AudioManager.h"
#import "NetworkManager.h"

static long kStreamBufferLimit = 4*60*60;

@implementation SessionManager

+ (SessionManager*)shared {
    static SessionManager *mgr = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mgr = [[SessionManager alloc] init];
#ifdef TESTING_PROGRAM_CHANGE
        mgr.initialProgramRequested = 0;
#endif
    });
    return mgr;
}

#pragma mark - Program
- (void)fetchProgramAtDate:(NSDate *)date completed:(CompletionBlockWithValue)completed {
    
#ifdef TESTING_PROGRAM_CHANGE
    Program *p = [self fakeProgram];
    self.currentProgram = p;
    [[NSNotificationCenter defaultCenter] postNotificationName:@"program_has_changed"
                                                        object:nil
                                                      userInfo:nil];
    
    completed(p);
    

    
    [self armProgramUpdater];
    return;
#endif
    
    NSString *urlString = [NSString stringWithFormat:@"%@/schedule/at?time=%d",kServerBase,(int)[date timeIntervalSince1970]];
    [[NetworkManager shared] requestFromSCPRWithEndpoint:urlString completion:^(id returnedObject) {
        // Create Program and insert into managed object context
        if ( returnedObject ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                Program *programObj = [Program insertProgramWithDictionary:returnedObject inManagedObjectContext:[[ContentManager shared] managedObjectContext]];
            
                [[ContentManager shared] saveContext];
                
                BOOL touch = NO;
                if ( self.currentProgram ) {
                    if ( !SEQ(self.currentProgram.program_slug,
                              programObj.program_slug) ) {
                        touch = YES;
                    }
                } else if ( programObj ) {
                    touch = YES;
                }
                
#ifdef TEST_PROGRAM_IMAGE
                touch = YES;
#endif
                self.currentProgram = programObj;
                if ( touch ) {
                    [[NSNotificationCenter defaultCenter] postNotificationName:@"program_has_changed"
                                                                        object:nil
                                                                      userInfo:nil];
                }
                completed(programObj);
                
                [self armProgramUpdater];
                
            });
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                completed(nil);
                [self armProgramUpdater];
            });
        }
    }];
    
}

- (void)fetchCurrentProgram:(CompletionBlockWithValue)completed {
    
    NSDate *d2u = [NSDate date];
    if ( [self sessionIsBehindLive] ) {
        d2u = [[AudioManager shared].audioPlayer.currentItem currentDate];
    }
    [self fetchProgramAtDate:d2u completed:completed];
}

- (void)armProgramUpdater {
    [self disarmProgramUpdater];
    
    if ( [self ignoreProgramUpdating] ) return;
    
#ifndef TESTING_PROGRAM_CHANGE
    NSInteger unit = NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit|NSHourCalendarUnit|NSMinuteCalendarUnit|NSSecondCalendarUnit;
    NSDate *now = [NSDate date];
    
    
    NSDate *fakeNow = nil;
    BOOL cookDate = NO;
    Program *cp = [self currentProgram];
    if ( [self sessionIsBehindLive] ) {
        fakeNow = [[AudioManager shared].audioPlayer.currentItem currentDate];
        cookDate = YES;
    }
    
    NSDate *nowToUse = cookDate ? cp.soft_starts_at : now;
    NSDateComponents *components = [[NSCalendar currentCalendar] components:unit
                                                                   fromDate:nowToUse];
    
    NSDate *then = nil;
    NSInteger minute = [components minute];
    NSInteger minDiff = 0;
    if ( minute < 30 ) {
        minDiff = 30 - minute;
    } else {
        minDiff = 60 - minute;
    }
    
    then = [NSDate dateWithTimeInterval:minDiff*60
                              sinceDate:now];

    NSDateComponents *cleanedComps = [[NSCalendar currentCalendar] components:unit
                                                                     fromDate:then];
    [cleanedComps setSecond:10];
    then = [[NSCalendar currentCalendar] dateFromComponents:cleanedComps];
    
    NSTimeInterval nowTI = [now timeIntervalSince1970];
    NSTimeInterval thenTI = [then timeIntervalSince1970];
    if ( abs(thenTI - nowTI) < 60 ) {
        then = [NSDate dateWithTimeInterval:30*60
                                  sinceDate:then];
    }
    
#ifdef TEST_PROGRAM_IMAGE
    then = [NSDate dateWithTimeInterval:30 sinceDate:now];
#endif
    NSTimeInterval sinceNow = [then timeIntervalSince1970] - [now timeIntervalSince1970];
    
    if ( [self useLocalNotifications] ) {
        UILocalNotification *localNote = [[UILocalNotification alloc] init];
        localNote.fireDate = then;
        localNote.alertBody = kUpdateProgramKey;
        [[UIApplication sharedApplication] scheduleLocalNotification:localNote];
    } else {
        

        self.programUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:sinceNow
                                                                   target:self
                                                                 selector:@selector(processTimer:)
                                                                 userInfo:nil
                                                                  repeats:NO];
#ifdef DEBUG
        NSLog(@"Program will check itself again at : %@",[then prettyTimeString]);
#endif
        
    }
#else
    NSDate *threeMinutesFromNow = [[NSDate date] dateByAddingTimeInterval:96];
    NSLog(@"Program will check itself again at : %@",[threeMinutesFromNow prettyTimeString]);
    self.programUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:abs([threeMinutesFromNow timeIntervalSinceNow])
                                                               target:self
                                                             selector:@selector(processTimer:)
                                                             userInfo:nil
                                                              repeats:NO];
    
#endif
    
}

- (void)disarmProgramUpdater {
    if ( [self useLocalNotifications] ) {
        [[UIApplication sharedApplication] cancelAllLocalNotifications];
    } else {
        if ( self.programUpdateTimer ) {
            if ( [self.programUpdateTimer isValid] ) {
                [self.programUpdateTimer invalidate];
            }
            self.programUpdateTimer = nil;
        }
    }
}

- (BOOL)ignoreProgramUpdating {
    
    if ( [self sessionIsExpired] ) return NO;
    if (
            /*[[AudioManager shared] status] == StreamStatusPaused  ||*/
            [[AudioManager shared] currentAudioMode] == AudioModeOnDemand
        
        )
    {
        return YES;
    }
   
    return NO;
    
}

#ifdef TESTING_PROGRAM_CHANGE
- (Program*)fakeProgram {
    if ( self.initialProgramRequested >= 2 ) {
        Program *p = [Program insertNewObjectIntoContext:nil];
        p.soft_starts_at = [[NSDate date] dateByAddingTimeInterval:(60*4)];
        p.starts_at = [[NSDate date] dateByAddingTimeInterval:(60*3)];
        p.ends_at = [[NSDate date] dateByAddingTimeInterval:(60*10)];
        p.title = @"Next Program";
        p.program_slug = [NSString stringWithFormat:@"%ld",(long)arc4random() % 10000];
        return p;
    }
    
    self.initialProgramRequested++;
    if ( !self.fakeCurrent ) {
        self.fakeCurrent = [Program insertNewObjectIntoContext:nil];
        Program *p = self.fakeCurrent;
        p.soft_starts_at = [[NSDate date] dateByAddingTimeInterval:-120];
        p.starts_at = [[NSDate date] dateByAddingTimeInterval:-1*(120)];
        p.ends_at = [[NSDate date] dateByAddingTimeInterval:(60*1)];
        p.title = @"Current Program";
    }

    NSLog(@"Times a fake thing was requested : %d",self.initialProgramRequested);
    return self.fakeCurrent;
    
}
#endif

#pragma mark - State handling
- (BOOL)sessionIsBehindLive {
    
    NSDate *currentDate = [[AudioManager shared].audioPlayer.currentItem currentDate];
    NSDate *live = [[AudioManager shared] maxSeekableDate];
    
    if ( abs([live timeIntervalSince1970] - [currentDate timeIntervalSince1970]) > 120 ) {
        return YES;
    }
    
    return NO;
}

- (BOOL)sessionIsExpired {
    
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) return NO;
    
    if ( [self sessionPausedDate] ) {
        NSDate *spd = [[SessionManager shared] sessionPausedDate];
        if ( [[NSDate date] timeIntervalSinceDate:spd] > kStreamBufferLimit ) {
            return YES;
        }
    }
    
    return NO;
}

- (BOOL)sessionIsInRecess {
    
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) return NO;
    Program *cp = self.currentProgram;
    NSDate *soft = cp.soft_starts_at;
    NSDate *hard = cp.starts_at;
    NSDate *now = [NSDate date];
    if ( [self sessionIsBehindLive] ) {
        now = [[AudioManager shared].audioPlayer.currentItem currentDate];
    }
    
    NSTimeInterval softTI = [soft timeIntervalSince1970];
    NSTimeInterval hardTI = [hard timeIntervalSince1970];
    NSTimeInterval nowTI = [now timeIntervalSince1970];
    if ( nowTI >= hardTI && nowTI <= softTI ) {
        return YES;
    }
    
    return NO;
    
}

- (void)invalidateSession {
    if ( [[AudioManager shared] currentAudioMode] == AudioModeOnDemand ) return;
    [self armProgramUpdater];
}

- (void)setSessionLeftDate:(NSDate *)sessionLeftDate {
    _sessionLeftDate = sessionLeftDate;
}

- (void)setSessionReturnedDate:(NSDate *)sessionReturnedDate {
    _sessionReturnedDate = sessionReturnedDate;
    if ( sessionReturnedDate ) {
        [self handleSessionReactivation];
    }
}

- (void)processNotification:(UILocalNotification*)programUpdate {
    
    if ( [self ignoreProgramUpdating] ) return;
    
    if ( SEQ([programUpdate alertBody],kUpdateProgramKey) ) {
        [self fetchCurrentProgram:^(id returnedObject) {
            
        }];
    }
}

- (void)processTimer:(NSTimer*)timer {
    
    if ( [self ignoreProgramUpdating] ) return;
    
    [self fetchCurrentProgram:^(id returnedObject) {
        
    }];
}

- (void)handleSessionReactivation {
    if ( !self.sessionLeftDate || !self.sessionReturnedDate ) return;
    long tiBetween = [[self sessionReturnedDate] timeIntervalSince1970] - [[self sessionLeftDate] timeIntervalSince1970];
    if ( tiBetween > kStreamBufferLimit ) {
        [[AudioManager shared] stopStream];
        [self fetchCurrentProgram:^(id returnedObject) {
            self.sessionReturnedDate = nil;
        }];
    } else {
        if ( [[AudioManager shared] status] != StreamStatusPaused ) {
            if ( [self sessionIsBehindLive] ) {
                [self fetchProgramAtDate:[[AudioManager shared].audioPlayer.currentItem currentDate] completed:^(id returnedObject) {
                    self.sessionReturnedDate = nil;
                }];
            } else {
                [self fetchCurrentProgram:^(id returnedObject) {
                    self.sessionReturnedDate = nil;
                }];
            }
        }
    }
}



@end
