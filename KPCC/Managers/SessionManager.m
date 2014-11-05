//
//  SessionManager.m
//  KPCC
//
//  Created by Ben Hochberg on 11/4/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SessionManager.h"
#import "AudioManager.h"

static long kStreamBufferLimit = 4*60*60;

@implementation SessionManager

+ (SessionManager*)shared {
    static SessionManager *mgr = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        mgr = [[SessionManager alloc] init];
    });
    return mgr;
}

#pragma mark - Program
- (void)fetchProgramAtDate:(NSDate *)date completed:(CompletionBlockWithValue)completed {
    
    self.lastProgramUpdate = date;
    NSString *urlString = [NSString stringWithFormat:@"%@/schedule/at?time=%d",kServerBase,(int)[date timeIntervalSince1970]];
    AFHTTPRequestOperationManager *manager = [AFHTTPRequestOperationManager manager];
    manager.responseSerializer = [AFJSONResponseSerializer serializerWithReadingOptions: NSJSONReadingMutableContainers];
    [manager GET:urlString parameters:nil success:^(AFHTTPRequestOperation *operation, id responseObject) {
        
        if ([responseObject objectForKey:@"meta"] && [[[[responseObject objectForKey:@"meta"] objectForKey:@"status"] objectForKey:@"code"] intValue] == 200) {
            
            NSArray *keys = [responseObject allKeys];
            NSString *responseKey = nil;
            for (NSString *key in keys) {
                if (![key isEqualToString:@"meta"]) {
                    responseKey = key;
                    break;
                }
            }
            
            if ( responseKey ) {
                
                NSDictionary *response = (NSDictionary*)responseObject;
                NSDictionary *programDict = (NSDictionary*)response[responseKey];
                if (!programDict) {
                    dispatch_async(dispatch_get_main_queue(), ^{
                        completed(nil);
                    });
                    return;
                }
                
                // Create Program and insert into managed object context
                if (programDict) {
                    Program *programObj = [Program insertProgramWithDictionary:programDict inManagedObjectContext:[[ContentManager shared] managedObjectContext]];
                    dispatch_async(dispatch_get_main_queue(), ^{
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
                
            }
        } else {
            dispatch_async(dispatch_get_main_queue(), ^{
                completed(nil);
                [self armProgramUpdater];
            });
        }
        
    } failure:^(AFHTTPRequestOperation *operation, NSError *error) {
        NSLog(@"Error: %@", error);
        completed(nil);
        [self armProgramUpdater];
    }];
}

- (void)fetchCurrentProgram:(CompletionBlockWithValue)completed {
    [self fetchProgramAtDate:[NSDate date] completed:completed];
}



- (void)armProgramUpdater {
    [self disarmProgramUpdater];
    
    if ( [self ignoreProgramUpdating] ) return;
    
    NSInteger unit = NSYearCalendarUnit|NSMonthCalendarUnit|NSDayCalendarUnit|NSHourCalendarUnit|NSMinuteCalendarUnit|NSSecondCalendarUnit;
    NSDate *now = [NSDate date];
    NSDateComponents *components = [[NSCalendar currentCalendar] components:unit
                                                                   fromDate:now];
    
    NSDate *then = nil;
    NSInteger minute = [components minute];
    NSInteger minDiff = 0;
    if ( minute < 30 ) {
        minDiff = 30 - minute;
    } else {
        minDiff = 60 - minute;
    }
    
    then = [NSDate dateWithTimeInterval:minDiff*60+20
                              sinceDate:now];
    NSDateComponents *cleanedComps = [[NSCalendar currentCalendar] components:unit
                                                                     fromDate:then];
    [cleanedComps setSecond:0];
    then = [[NSCalendar currentCalendar] dateFromComponents:cleanedComps];
    
    NSTimeInterval nowTI = [now timeIntervalSince1970];
    NSTimeInterval thenTI = [then timeIntervalSince1970];
    if ( abs(thenTI - nowTI) < 60 ) {
        then = [NSDate dateWithTimeInterval:30*60
                                  sinceDate:then];
    }
    
    if ( [self useLocalNotifications] ) {
        UILocalNotification *localNote = [[UILocalNotification alloc] init];
        localNote.fireDate = then;
        localNote.alertBody = kUpdateProgramKey;
        [[UIApplication sharedApplication] scheduleLocalNotification:localNote];
    } else {
        
        NSTimeInterval sinceNow = [then timeIntervalSince1970] - [now timeIntervalSince1970];
        self.programUpdateTimer = [NSTimer scheduledTimerWithTimeInterval:sinceNow
                                                                   target:self
                                                                 selector:@selector(processTimer:)
                                                                 userInfo:nil
                                                                  repeats:NO];
#ifdef DEBUG
        NSLog(@"Program will check itself again at : %@",[then prettyTimeString]);
#endif
        
    }
    
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
    return (
            [[AudioManager shared] status] == StreamStatusPaused  ||
            [[AudioManager shared] currentAudioMode] == AudioModeOnDemand
            );
}

#pragma mark - State handling
- (void)setSessionLeftDate:(NSDate *)sessionLeftDate {
    _sessionLeftDate = sessionLeftDate;
    if ( [[AudioManager shared] status] == StreamStatusPaused ) {
        [self setSessionEndedWhilePaused:YES];
    } else {
        [self setSessionEndedWhilePaused:NO];
    }
}

- (void)setSessionReturnedDate:(NSDate *)sessionReturnedDate {
    _sessionReturnedDate = sessionReturnedDate;
    [self setSessionEndedWhilePaused:NO];
    [self handleSessionReactivation];
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
                
        }];
    } else {
        if ( ![self sessionEndedWhilePaused] ) {
            [self fetchCurrentProgram:^(id returnedObject) {
                
            }];
        }
    }
}



@end
