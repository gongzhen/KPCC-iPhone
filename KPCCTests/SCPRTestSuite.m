//
//  SCPRTestSuite.m
//  KPCC
//
//  Created by Ben Hochberg on 5/19/15.
//  Copyright (c) 2015 SCPR. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <XCTest/XCTest.h>
#import "AudioManager.h"
#import "SessionManager.h"
#import "UXmanager.h"
#import "SCPRMasterViewController.h"
#import "SCPROnboardingViewController.h"

@interface SCPRTestSuite : XCTestCase

@end

@implementation SCPRTestSuite

- (void)setUp {
    [super setUp];
    // Put setup code here. This method is called before the invocation of each test method in the class.
}

- (void)tearDown {
    // Put teardown code here. This method is called after the invocation of each test method in the class.
    [super tearDown];
}

- (void)testInitialAudioMode {
    // This is an example of a functional test case.
    XCTAssert([[AudioManager shared] currentAudioMode] == AudioModeNeutral, @"On launch, the initial audio mode is neutral");
}

- (void)testOnboarding {
    BOOL seenOnboarding = [[UXmanager shared].settings userHasViewedOnboarding];
    if ( seenOnboarding ) {
        NSLog(@"User has seen onboarding, test for absence...");
        XCTAssert(![[UXmanager shared] lisaPlayer] && ![[UXmanager shared] musicPlayer], @"Onboarding audio was not prepared");
    } else {
        NSLog(@"User has not seen onboarding, test for presence...");
        XCTAssert(![[UXmanager shared] onboardingCtrl] || [[[UXmanager shared] onboardingCtrl] view].alpha == 0.0f, @"Onboarding should not be displaying");
    }
}

- (void)testPerformanceExample {
    // This is an example of a performance test case.
    [self measureBlock:^{
        // Put the code you want to measure the time of here.
    }];
}

@end
