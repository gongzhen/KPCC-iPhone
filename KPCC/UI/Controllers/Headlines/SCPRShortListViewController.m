//
//  SCPRShortListViewController.m
//  KPCC
//
//  Created by Ben Hochberg on 10/27/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "SCPRShortListViewController.h"
#import <pop/POP.h>
#import "DesignManager.h"
#import "SCPRNavigationController.h"
#import "SCPRAppDelegate.h"
#import "SCPRSpinnerViewController.h"
#import "NetworkManager.h"
#import "SessionManager.h"
#import "AnalyticsManager.h"

@import MessageUI;

@interface SCPRShortListViewController ()

- (void)extractTitleFromString:(NSString*)fullHTML completed:(BlockWithObject)completed;

@end

static NSString *kShortListMenuURL = @"http://www.scpr.org/short-list/latest#no-prelims";

@implementation SCPRShortListViewController

- (void)viewDidLoad {
    [super viewDidLoad];
    
    [[SessionManager shared] resetCache];
    
    self.secondaryLoadingLocks = [NSMutableArray new];
    
    SCPRAppDelegate *del = (SCPRAppDelegate*)[UIApplication sharedApplication].delegate;
    SCPRNavigationController *navigation = [del masterNavigationController];
    CGFloat nbHeight = navigation.navigationBar.frame.size.height;
    
    self.view.frame = [[DesignManager shared] screenFrame];
    
    self.mainScrollView = [[UIScrollView alloc] initWithFrame:CGRectMake(0.0, 0.0, self.view.frame.size.width,
                                                                 self.view.frame.size.height)];
    
    self.detailWebView = [[UIWebView alloc] initWithFrame:CGRectMake(self.view.frame.size.width,
                                                                     64.0, self.view.frame.size.width,
                                                                     self.view.frame.size.height-nbHeight)];
    self.slWebView = [[UIWebView alloc] initWithFrame:CGRectMake(0.0,
                                                                 64.0,
                                                                 self.view.frame.size.width,
                                                                 self.view.frame.size.height-nbHeight)];
    [self.view addSubview:self.mainScrollView];
    
    self.mainScrollView.contentSize = CGSizeMake(2*self.mainScrollView.frame.size.width,
                                                 self.mainScrollView.frame.size.height);
    [self.mainScrollView addSubview:self.slWebView];
    [self.mainScrollView addSubview:self.detailWebView];
    [self.mainScrollView sendSubviewToBack:self.slWebView];
    [self.mainScrollView sendSubviewToBack:self.detailWebView];
    
    self.mainScrollView.scrollEnabled = NO;
    
    NSURLRequest *rq = [[NSURLRequest alloc] initWithURL:[NSURL URLWithString:kShortListMenuURL]];
    //self.slWebView.transform = CGAffineTransformMakeScale(0.1, 0.1);
    self.slWebView.layer.opacity = 0.0f;
    
    //self.detailWebView.transform = CGAffineTransformMakeScale(0.1, 0.1);
    
    self.slWebView.delegate = self;
    self.detailWebView.delegate = self;
    self.cachedParentTitle = self.navigationItem.title;
    self.navigationItem.title = @"Headlines";
    self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAction target:self action:@selector(share)];
    self.currentObjectURL = kShortListMenuURL;

    [[AnalyticsManager shared] logEvent:@"userIsViewingHeadlines" withParameters:nil timed:YES];

	[SCPRSpinnerViewController spinInCenterOfViewController:self appeared:^{
        [[SessionManager shared] setUserIsViewingHeadlines:YES];
#ifdef USE_API
        [[NetworkManager shared] fetchEditions:^(id object) {
            
            NSAssert([object isKindOfClass:[NSArray class]],@"Expecting an array here");
            NSArray *editions = (NSArray*)object;
            if ( [editions count] > 0 ) {
                NSDictionary *lead = editions[0];
                self.abstracts = lead[@"abstracts"];
            }
            
        }];
#endif
        [self.slWebView loadRequest:rq];
    }];
    
}

- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
    [[DesignManager shared] treatBar];
    [[AnalyticsManager shared] screen:@"headlinesView"];
}

- (void)willMoveToParentViewController:(UIViewController *)parent {
   /* self.navigationItem.title = self.cachedParentTitle;
    [self.slWebView loadHTMLString:@"" baseURL:nil];
    [[SessionManager shared] setUserIsViewingHeadlines:NO];
    [[AnalyticsManager shared] trackHeadlinesDismissal];*/
}

- (void)share {
    if (self.currentObjectURL) {
        UIActivityViewController *activities = [[UIActivityViewController alloc] initWithActivityItems:@[ self.currentObjectURL ] applicationActivities:nil];
        [self presentViewController:activities
                           animated:YES
                         completion:^{
                             [[DesignManager shared] normalizeBar];
                         }];
    }
}

#pragma mark - UIWebView
- (void)webViewDidFinishLoad:(UIWebView *)webView {
    if ( webView == self.slWebView ) {
        [SCPRSpinnerViewController finishSpinning];

		if (!self.initialLoad) {
            self.initialLoad = YES;
            [UIView animateWithDuration:0.55 animations:^{
                [self.slWebView.layer setOpacity:1.0];
            } completion:^(BOOL finished) {
            }];
        }
    }

	if (webView == self.detailWebView) {
        if (self.popping) {
            self.popping = NO;
            self.detailInitialLoad = NO;
            return;
        }

        if (!self.detailInitialLoad) {
            self.detailInitialLoad = YES;
            [SCPRSpinnerViewController finishSpinning];

            [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
                self.mainScrollView.contentOffset = CGPointMake(self.mainScrollView.frame.size.width, self.mainScrollView.contentOffset.y);
            } completion:^(BOOL finished) {
                NSString *jsonString = [self.detailWebView stringByEvaluatingJavaScriptFromString:@"document.getElementsByTagName('head')[0].innerHTML;"];
                
                [self extractTitleFromString:jsonString completed:^(id object) {
                    
                    [SCPRSpinnerViewController finishSpinning];
                    
                    NSLog(@"Title : %@",(NSString*)object);
                    self.cachedTitle = self.navigationItem.title;
                    self.navigationItem.title = (NSString*)object;
                    
                    SCPRAppDelegate *del = (SCPRAppDelegate*)[UIApplication sharedApplication].delegate;
                    SCPRNavigationController *navigation = [del masterNavigationController];
                    
                    [navigation applyCustomLeftBarItem:CustomLeftBarItemPop proxyDelegate:self];
                    
                    self.pushing = NO;
                }];
            }];
        }
    }
}

- (BOOL)webView:(UIWebView *)webView shouldStartLoadWithRequest:(NSURLRequest *)request navigationType:(UIWebViewNavigationType)navigationType {
    NSString *str = [[request URL] absoluteString];
    if ( webView == self.slWebView ) {
        if ( self.initialLoad ) {
			if ( navigationType != UIWebViewNavigationTypeLinkClicked ) {
				return YES;
			}

			if ([str rangeOfString:@"http"].location != NSNotFound) {
                NSLog(@"Headlines electing to load : %@",str);
                
                if (!self.pushing) {
                    [SCPRSpinnerViewController spinInCenterOfViewController:self appeared:^{
                        self.detailWebView.delegate = self;
                        self.currentObjectURL = str;
                        self.pushing = YES;
//                        self.navigationItem.leftBarButtonItem.enabled = NO;
//						self.navigationController.interactivePopGestureRecognizer.enabled = NO;
                        self.detailInitialLoad = NO;
                        [self.detailWebView loadRequest:request];
					}];
                }

				return NO;
            }

			if ([str rangeOfString:@"about:blank"].location != NSNotFound) {
                return YES;
            }
            
            return YES;
        }
    }

	if (webView == self.detailWebView) {
        if ( [str rangeOfString:@"share?obj_key"].location != NSNotFound ||
            [str rangeOfString:@"tweet?url"].location != NSNotFound ||
            [str rangeOfString:@"/sharer.php?"].location != NSNotFound ) {
            [[[UIAlertView alloc] initWithTitle:@"Share from the App!" message:@"If you'd like to share this item, use the share button in the upper right corner" delegate:nil cancelButtonTitle:@"Will Do!" otherButtonTitles:nil] show];

			return NO;
        } else {
//            if (self.loadingTimer) {
//                if ( [self.loadingTimer isValid] ) {
//                    [self.loadingTimer invalidate];
//                }
//                self.loadingTimer = nil;
//            }
//
//            self.loadingTimer = [NSTimer scheduledTimerWithTimeInterval:0.25 target:self selector:@selector(unlockBackButton) userInfo:nil repeats:NO];

            if ( navigationType != UIWebViewNavigationTypeLinkClicked ) {
                return YES;
            }
            
            [[UIApplication sharedApplication] openURL:[request URL]];
            return NO;
        }
    }

	return YES;
}

- (void)webView:(UIWebView *)webView didFailLoadWithError:(NSError *)error {
    NSLog(@"Headlines failed : %@",[error userInfo]);
}

- (void)unlockBackButton {
//    self.navigationItem.leftBarButtonItem.enabled = YES;
//	self.navigationController.interactivePopGestureRecognizer.enabled = YES;
}

#pragma mark - MenuButtonDelegate
- (void)popPressed {
	if (self.pushing) {
		return;
	}

    [self.detailWebView stopLoading];
    self.detailWebView.delegate = nil;

//	if (self.loadingTimer) {
//        if ([self.loadingTimer isValid]) {
//            [self.loadingTimer invalidate];
//        }
//        self.loadingTimer = nil;
//    }

    self.popping = YES;
    SCPRAppDelegate *del = (SCPRAppDelegate*)[UIApplication sharedApplication].delegate;
    SCPRNavigationController *navigation = [del masterNavigationController];
    [navigation restoreLeftBarItem:self];
    self.navigationItem.title = self.cachedTitle;

    [UIView animateWithDuration:0.25 delay:0.0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        self.mainScrollView.contentOffset = CGPointMake(0.0, self.mainScrollView.contentOffset.y);
    } completion:^(BOOL finished) {
        self.currentObjectURL = kShortListMenuURL;
        [self.detailWebView loadHTMLString:@"" baseURL:nil];
//        self.navigationItem.leftBarButtonItem.enabled = YES;
//		self.navigationController.interactivePopGestureRecognizer.enabled = YES;
        self.pushing = NO;
        self.popping = NO;

    }];
}

- (void)backPressed {
    // Should not be called
}

- (void)menuPressed {
    // Should not be called
}

- (void)dealloc {
    self.slWebView.delegate = nil;
    [self.slWebView loadHTMLString:@"" baseURL:nil];

    [[SessionManager shared] setUserIsViewingHeadlines:NO];
    [[AnalyticsManager shared] trackHeadlinesDismissal];
    
}


#pragma mark - Utilities
- (void)extractTitleFromString:(NSString *)fullHTML completed:(BlockWithObject)completed {
    
    NSError *error = nil;
    
    NSRegularExpression *regex = [NSRegularExpression
                                  regularExpressionWithPattern:@"<title>.*</title>"
                                  options:NSRegularExpressionCaseInsensitive|NSRegularExpressionDotMatchesLineSeparators
                                  error:&error];
    
    __block NSString *title = @"";
    __block BOOL matched = NO;

	NSString *(^replaceEntities)(NSString*) = ^(NSString *inputString) {
		NSArray *entityItems = @[
								 @[@"&amp;", @"&"],
								 @[@"&lt;", @"<"],
								 @[@"&gt;", @">"],
								 @[@"&bull;", @"•"],
								 @[@"&deg;", @"°"],
								 @[@"&copy;", @"©"],
								 @[@"&reg;", @"®"],
								 @[@"&mdash;", @"—"],
								 @[@"&ndash;", @"–"],
								 @[@"&nbsp;", @" "],
								 @[@"&ldquo;", @"“"],
								 @[@"&rdguo;", @"”"],
								 @[@"&lsquo;", @"‘"],
								 @[@"&rsquo;", @"’"],
								 @[@"&hellip;", @"…"]
								 ];
		
		for (NSArray *entityItem in entityItems) {
			inputString = [inputString stringByReplacingOccurrencesOfString:entityItem[0] withString:entityItem[1]];
		}

		return inputString;
	};

	[regex enumerateMatchesInString:fullHTML options:0 range:NSMakeRange(0, [fullHTML length]) usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop) {
        
        title = [fullHTML substringWithRange:[match rangeAtIndex:0]];
        title = [title substringToIndex:[title rangeOfString:@"</title>"].location];
        title = [title substringFromIndex:[title rangeOfString:@"<title>"].location + [@"<title>" length]];

        *stop = YES;
        matched = YES;
		
		title = replaceEntities(title);

        if ( completed ) {
            dispatch_async(dispatch_get_main_queue(), ^{
                completed(title);
            });
        }
        
    }];
    
    if ( !matched ) {
        NSRegularExpression *regex = [NSRegularExpression
                                      regularExpressionWithPattern:@"<h1 class=\"story-headline\">.*?</a>"
                                      options:NSRegularExpressionCaseInsensitive|NSRegularExpressionDotMatchesLineSeparators
                                      error:&error];
        
        [regex enumerateMatchesInString:fullHTML options:0 range:NSMakeRange(0, [fullHTML length]) usingBlock:^(NSTextCheckingResult *match, NSMatchingFlags flags, BOOL *stop) {
            
            title = [fullHTML substringWithRange:[match rangeAtIndex:0]];
            title = [title substringToIndex:[title rangeOfString:@"</a>"].location];
            title = [title substringFromIndex:[title rangeOfString:@"<a href"].location + [@"<a href" length]];
            title = [title substringFromIndex:[title rangeOfString:@">"].location+1];
            
            *stop = YES;
            matched = YES;

			title = replaceEntities(title);

            if ( completed ) {
                dispatch_async(dispatch_get_main_queue(), ^{
                    completed(title);
                });
            }
            
        }];
    }


    
}

- (void)findConcreteObjecrBasedOnUrl:(NSString *)url completion:(BlockWithObject)completion {

}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
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
