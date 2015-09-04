//
//  NowPlayingManager.swift
//  KPCC
//
//  Created by Eric Richardson on 9/3/15.
//  Copyright © 2015 SCPR. All rights reserved.
//

import Foundation
import MediaPlayer

@objc public class NowPlayingManager: NSObject {
    var _audio:AudioChunk? = nil
    var _player:AudioPlayer? = nil
    let _status:AVStatus

    var _isPlaying:Bool = false
    var _playhead:Double?

    //----------

    init(status:AVStatus) {
        self._status = status

        super.init()

        self._status.observe() { s in
            let isP = s == .Playing ? true : false

            if (self._isPlaying != isP) {
                self._isPlaying = isP
                self._update()
            }
        }
    }

    //----------

    func setAudio(a:AudioChunk?) -> Void {
        self._audio = a
        self._update()
    }

    //----------

    func setPlayer(p:AudioPlayer?) -> Void {
        self._player = p

        p?.observeTime() { dates in
            if self._audio != nil {
                let playhead:Double
                if dates.hasDates() {
                    // live stream... compare curDate to the audioTimestamp in 
                    // the AudioChunk to get seconds elapsed
                    playhead = dates.curDate!.timeIntervalSinceReferenceDate - self._audio!.audioTimeStamp.timeIntervalSinceReferenceDate

                } else {
                    // on-demand. curTime and duration are all we need
                    playhead = CMTimeGetSeconds(dates.curTime!)
                }

                if (self._playhead == nil || abs(playhead - self._playhead!) > 10) {
                    self._playhead = playhead
                    self._update()
                } else {
                    self._playhead = playhead
                }
            }
        }
    }

    //----------

    private func _update() -> Void {
        if (self._audio != nil) {
            MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = [
                MPMediaItemPropertyTitle:                       self._audio!.audioTitle,
                MPMediaItemPropertyArtist:                      self._audio!.programTitle,
                MPNowPlayingInfoPropertyPlaybackRate:           self._isPlaying ? 1.0 : 0.0,
                MPMediaItemPropertyPlaybackDuration:            self._audio!.audioDuration,
                MPNowPlayingInfoPropertyElapsedPlaybackTime:    (self._playhead != nil) ? self._playhead! : 0.0,
            ]

        } else {
            MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = [
                MPMediaItemPropertyTitle:                       "89.3 KPCC",
                MPMediaItemPropertyArtist:                      "",
                MPNowPlayingInfoPropertyPlaybackRate:           self._isPlaying ? 1.0 : 0.0,
//                MPMediaItemPropertyPlaybackDuration:            nil,
//                MPNowPlayingInfoPropertyElapsedPlaybackTime:    nil,
            ]
        }

    }
}