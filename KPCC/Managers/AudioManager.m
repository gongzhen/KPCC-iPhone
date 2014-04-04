//
//  AudioManager.m
//  KPCC
//
//  Created by John Meeker on 3/6/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

#import "AudioManager.h"
#import "NetworkManager.h"
#import "AnalyticsManager.h"

static AudioManager *singleton = nil;

@implementation AudioManager

+ (AudioManager*)shared {
    if ( !singleton ) {
        @synchronized(self) {
            singleton = [[AudioManager alloc] init];
            [singleton buildStreamer];
        }
    }
    
    return singleton;
}

- (void)buildStreamer {
    self.audioPlayer = [[STKAudioPlayer alloc]init];
    self.audioPlayer.delegate = self;
    self.audioPlayer.meteringEnabled = YES;
}

- (NSString *)liveStreamURL {
    long currentTimeSeconds = [[NSDate date] timeIntervalSince1970];
    
    NSLog(@"currentTimeSeconds - LiveStreamThreshold: %ld", (currentTimeSeconds - kLiveStreamPreRollThreshold));
    NSLog(@"Current lastPreRoll time: %ld", self.lastPreRoll);

    if (self.lastPreRoll < (currentTimeSeconds - kLiveStreamPreRollThreshold + 5000)) {

        //self.lastPreRoll = [[NSDate date] timeIntervalSince1970];
        NSLog(@"liveStreamURL returning WITH preroll");

        return kLiveStreamAACURL;
    } else {
        return kLiveStreamAACNoPreRollURL;
        NSLog(@"liveStreamURL returning NO preroll");
    }
}

- (void)startStream {
    self.audioDataSource = [STKAudioPlayer dataSourceFromURL:[NSURL URLWithString:[self liveStreamURL]]];

    if ([[self liveStreamURL] isEqualToString:kLiveStreamAACURL]) {
        NSLog(@"Setting lastPreRoll to now");
        self.lastPreRoll = [[NSDate date] timeIntervalSince1970];
    }

    [self.audioPlayer playDataSource:self.audioDataSource];
}

- (void)stopStream {
    [self.audioPlayer stop];
}

- (BOOL)isStreamPlaying {
    if (self.audioPlayer && self.audioPlayer.state == STKAudioPlayerStatePlaying) {
        return YES;
    } else {
        return NO;
    }
}


#pragma mark - Error Logging

- (void)analyzeStreamError:(NSString *)comments {
    
    NSURL *liveURL = [NSURL URLWithString:kLiveStreamURL];
    NetworkHealth netHealth = [[NetworkManager shared] checkNetworkHealth:[liveURL host]];

    switch (netHealth) {
        case NetworkHealthAllOK:
            if (![self isStreamPlaying] && self.audioPlayer.state != STKAudioPlayerStateBuffering) {
                [[AnalyticsManager shared] failStream:StreamStateUnknown comments:comments];
            }
            break;
            
        case NetworkHealthNetworkDown:
            [[AnalyticsManager shared] failStream:StreamStateLostConnectivity comments:comments];
            break;
        
        case NetworkHealthServerDown:
            [[AnalyticsManager shared] failStream:StreamStateServerFail comments:comments];
            break;
            
        default:
            [[AnalyticsManager shared] failStream:StreamStateUnknown comments:comments];
            break;
    }
}

#pragma mark - STKAudioPlayerDelegate protocol implementation

- (void)audioPlayer:(STKAudioPlayer *)audioPlayer stateChanged:(STKAudioPlayerState)state previousState:(STKAudioPlayerState)previousState {
    SCPRDebugLog();
    
    /*if (state == STKAudioPlayerStateBuffering && previousState == STKAudioPlayerStatePlaying) {
        // TODO: WIP -- hacky way to restart stream without preroll after recovering from a drop.
        NSLog(@"Restart stream manually");
        [self startStream];
    }*/
}

- (void)audioPlayer:(STKAudioPlayer*)audioPlayer unexpectedError:(STKAudioPlayerErrorCode)errorCode {
    SCPRDebugLog();
    
    NSString *errorCodeString;
    switch (errorCode) {
        case STKAudioPlayerErrorAudioSystemError:
            errorCodeString = @"STKAudioPlayerErrorAudioSystemError";
            break;

        case STKAudioPlayerErrorCodecError:
            errorCodeString = @"STKAudioPlayerErrorCodecError";
            break;

        case STKAudioPlayerErrorDataNotFound:
            errorCodeString = @"STKAudioPlayerErrorDataNotFound";
            break;

        case STKAudioPlayerErrorDataSource:
            errorCodeString = @"STKAudioPlayerErrorDataSource";
            break;

        case STKAudioPlayerErrorStreamParseBytesFailed:
            errorCodeString = @"STKAudioPlayerErrorStreamParseBytesFailed";
            break;

        case STKAudioPlayerErrorOther:
            errorCodeString = @"STKAudioPlayerErrorOther";
            break;

        case STKAudioPlayerErrorNone:
            errorCodeString = @"STKAudioPlayerErrorNone";
            break;

        default:
            errorCodeString = @"STKAudioPlayerErrorUnknownCode";
            break;
    }
    
    [self analyzeStreamError:errorCodeString];
}

- (void)audioPlayer:(STKAudioPlayer *)audioPlayer didStartPlayingQueueItemId:(NSObject *)queueItemId {
    SCPRDebugLog();

    [[AnalyticsManager shared] logEvent:@"streamStartedPlaying" withParameters:nil];
}
- (void)audioPlayer:(STKAudioPlayer *)audioPlayer logInfo:(NSString *)line {
    SCPRDebugLog();

    [[AnalyticsManager shared] logEvent:@"audioPlayerLogItem" withParameters:@{@"event": line}];
}

- (void)audioPlayer:(STKAudioPlayer *)audioPlayer didFinishBufferingSourceWithQueueItemId:(NSObject *)queueItemId {
    SCPRDebugLog();
}
- (void)audioPlayer:(STKAudioPlayer *)audioPlayer didFinishPlayingQueueItemId:(NSObject *)queueItemId withReason:(STKAudioPlayerStopReason)stopReason andProgress:(double)progress andDuration:(double)duration {
    SCPRDebugLog();
}

#pragma mark - STKDataSourceDelegate protocol implementation

-(void) dataSourceDataAvailable:(STKDataSource*)dataSource {
    SCPRDebugLog();
}

-(void) dataSourceErrorOccured:(STKDataSource*)dataSource {
    SCPRDebugLog();
}

-(void) dataSourceEof:(STKDataSource*)dataSource {
    SCPRDebugLog();
}

@end
