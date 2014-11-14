//
//  FeedbackManager.h
//  KPCC
//
//  Created by Ben on 7/30/13.
//  Copyright (c) 2013 scpr. All rights reserved.
//

#import <Foundation/Foundation.h>

#define kDeskTimestampYield @"||_DESK_DATE_YIELD_||"
#define kDeskBodyYield @"||_DESK_BODY_YIELD_||"
#define kDeskEmailYield @"||_DESK_EMAIL_YIELD_||"
#define kDeskSubjectYield @"||_DESK_SUBJECT_YIELD_||"
#define kDeskPriorityYield @"||_DESK_PRIORITY_YIELD_||"
#define kDeskCustomerYield @"||_DESK_CUSTOMER_YIELD_||"
#define kDeskCustomerEmailYield @"||_DESK_CUSTOMER_EMAIL_YIELD_||"
#define kDeskCustomerFirstNameYield @"||_DESK_CUSTOMER_FIRST_NAME_YIELD_||"
#define kDeskCustomerLastNameYield @"||_DESK_CUSTOMER_LAST_NAME_YIELD_||"

@interface FeedbackManager : NSObject

+ (FeedbackManager*)shared;
- (void)authWithDesk;
- (void)validateCustomer:(NSDictionary*)meta;
- (void)postFeedback:(NSDictionary*)meta customer_id:(NSString*)string;
- (void)enumerateCustomers;
- (void)fail;

@end
