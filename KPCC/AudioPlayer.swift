//
//  AudioPlayer.swift
//  KPCC
//
//  Created by Eric Richardson on 9/2/15.
//  Copyright © 2015 SCPR. All rights reserved.
//

import Foundation
import AVFoundation
import MobileCoreServices

//-----------

public struct AudioPlayerObserver<T> {
    var observers: [(T) -> Void] = []

    public mutating func addObserver(o:(T) -> Void) {
        observers.append(o)
    }

    func notify(obj:T) {
        for o in observers {
            o(obj)
        }
    }
}

//----------

@objc public class AudioPlayer: NSObject {
    @objc public enum AudioNetworkStatus:Int {
        case Unknown = 0, NotReachable = 1, WIFI = 2, Cellular = 3

        func toString() -> String {
            let s = ["Unknown","No Connection","WIFI","Cellular"];
            return s[self.rawValue]
        }
    }

    //----------

    @objc public class AudioEvent: NSObject {
        public var message:String
        public var time:NSDate

        init(message:String) {
            self.message = message
            self.time = NSDate()
        }
    }

    //----------

    @objc public class StreamDates: NSObject {
        var curDate:    NSDate?
        var minDate:    NSDate?
        var maxDate:    NSDate?
        var buffered:   Double?
        var curTime:    CMTime?
        var duration:   CMTime?

        convenience init(curTime:CMTime,duration:CMTime) {
            self.init(curDate:nil,minDate:nil,maxDate:nil,buffered:nil,curTime:curTime,duration:duration)
        }

        convenience init(curDate:NSDate,minDate:NSDate?,maxDate:NSDate?,buffered:Double?) {
            self.init(curDate:curDate,minDate:minDate,maxDate:maxDate,buffered:buffered,curTime:nil,duration:nil)
        }

        init(curDate:NSDate?,minDate:NSDate?,maxDate:NSDate?,buffered:Double?,curTime:CMTime?,duration:CMTime?) {
            self.curDate = curDate
            self.minDate = minDate
            self.maxDate = maxDate
            self.buffered = buffered
            self.curTime = curTime
            self.duration = duration
        }

        func hasDates() -> Bool {
            if self.curDate != nil {
                return true
            } else {
                return false
            }
        }

        func percentToDate(percent:Float64) -> NSDate? {
            if minDate == nil || maxDate == nil {
                return nil
            }

            let duration:Double = maxDate!.timeIntervalSince1970 - minDate!.timeIntervalSince1970
            let seconds:Double = duration * percent

            return minDate!.dateByAddingTimeInterval(seconds)
        }
    }

    //----------

    public typealias finishCallback = (Bool) -> Void

    //----------

    let _player: AVPlayer
    let observer: AVObserver

    var playing: Bool

    var _timeObserver: AnyObject?

    var _dateFormat: NSDateFormatter

    var currentDates: StreamDates?

    //----------

    public var oTime        = AudioPlayerObserver<StreamDates>()
//    public var oShow        = AudioPlayerObserver<Schedule.ScheduleInstance?>()
    public var oStatus      = AudioPlayerObserver<AudioStatus>()
    public var oAccessLog   = AudioPlayerObserver<AVPlayerItemAccessLogEvent>()
    public var oErrorLog    = AudioPlayerObserver<AVPlayerItemErrorLogEvent>()
    public var oEventLog    = AudioPlayerObserver<AudioEvent>()
    public var oNetwork     = AudioPlayerObserver<AudioNetworkStatus>()

//    var _currentShow: Schedule.ScheduleInstance? = nil
//    var _checkingDate: NSDate?

    var _sessionId:String?

    var _lowBandwidth:Bool = false

    var prevStatus: AudioStatus = AudioStatus.New
    var status: AudioStatus = AudioStatus.New

    var _wasInterrupted:Bool = false

    var _interactionIdx:Int = 0

    // Configurable Settings
    public var seekTolerance:Int = 5
    public var reduceBandwidthOnCellular:Bool = true

//    let _reachability = Reachability.reachabilityForInternetConnection()
    var _networkStatus: AudioNetworkStatus = .Unknown

    //var _sessions:AudioSessionTracker? = nil

    var volume:Double = 1.0;

    //----------

    init(player:AVPlayer) {
        self.playing = false

        self._dateFormat = NSDateFormatter()
        self._dateFormat.dateFormat = "hh:mm:ss a"

        self._player = player
        self.observer = AVObserver(player:player)

        super.init()

        // set up an observer for player / item status
        self.observer.setCallback() { status,msg,obj in
            self._handleObservation(status, msg:msg, obj:obj)
        }

        // ios9 adds a feature to limit paused buffering
        if #available(iOS 9.0, *) {
            self._player.currentItem?.canUseNetworkResourcesForLiveStreamingWhilePaused = false
        }

        // should we be limiting bandwidth?
        if #available(iOS 8.0, *) {
            if self.reduceBandwidthOnCellular && self._networkStatus == .Cellular {
                self._emitEvent("Turning on bandwidth limiter for new player")
                self._player.currentItem?.preferredPeakBitRate = 1000
            }
        }

        self._setStatus(.New)

        self._getReadyPlayer() {cold in
            // observe time every second
            self._player.addPeriodicTimeObserverForInterval(CMTimeMake(1,1), queue: nil,
                usingBlock: {(time:CMTime) in
                    if self.status == .Seeking {
                        // we don't want to update anything mid-seek
                        return
                    }

                    let curDate = self._player.currentItem!.currentDate()

                    var buffered: Double? = nil

                    if !self._player.currentItem!.loadedTimeRanges.isEmpty {
                        let loaded_range = self._player.currentItem!.loadedTimeRanges[0].CMTimeRangeValue
                        buffered = CMTimeGetSeconds(CMTimeSubtract(CMTimeRangeGetEnd(loaded_range), time))
                    }

                    if curDate != nil {
                        // This should be a stream session, with dates

                        var seek_range: CMTimeRange
                        var minDate: NSDate? = nil
                        var maxDate: NSDate? = nil

                        if !self._player.currentItem!.seekableTimeRanges.isEmpty {
                            seek_range = self._player.currentItem!.seekableTimeRanges[0].CMTimeRangeValue

                            // these calculations assume no discontinuities in the playlist data
                            // FIXME: We really want to get these from the playlist... There has to be a way to get there
                            minDate = NSDate(timeInterval: -1 * (CMTimeGetSeconds(time) - CMTimeGetSeconds(seek_range.start)), sinceDate:curDate!)
                            maxDate = NSDate(timeInterval: CMTimeGetSeconds(CMTimeRangeGetEnd(seek_range)) - CMTimeGetSeconds(time), sinceDate:curDate!)
                        }

                        let dates = StreamDates(curDate: curDate!, minDate: minDate, maxDate: maxDate, buffered:buffered)

                        self.currentDates = dates

                        self.oTime.notify(dates)
                    } else {
                        // This is likely to be on-demand

                        let duration = self.duration()

                        let dates = StreamDates(curTime:time, duration:duration)

                        self.oTime.notify(dates)
                    }
            })
        }
    }

    //----------

    private func _handleObservation(status:AVObserver.Statuses,msg:String,obj:AnyObject?) {
        switch status {
        case .PlayerFailed:
            self._emitEvent("Player failed with error: \(msg)")
            self.stop()
        case .ItemFailed:
            self._emitEvent("Item failed with error: \(msg)")
            self.stop()
        case .Stalled:
            if self.currentDates!.hasDates() {
                self._emitEvent("Playback stalled at \(self._dateFormat.stringFromDate(self.currentDates!.curDate!)).")
            } else {
                self._emitEvent("ONDEMAND AUDIO STALL?")
            }

            // stash our stall position and interaction index, so that we can
            // try to resume in the same spot when we see connectivity return
            let stallIdx = self._interactionIdx
            let stallPosition = self.currentDates?.curDate

            // FIXME: Are the other methods we should be using to try and claw back from a stall?
            self.observer.once(.LikelyToKeepUp) { msg,obj in
                // if there's been a user interaction in the meantime, we do a no-op
                if stallIdx == self._interactionIdx {
                    self._emitEvent("trying to resume playback at stall position.")
                    if stallPosition != nil {
                        self._seekToDate(stallPosition!,useTime:true)
                    } else {
                        self._player.play()
                    }
                }
            }
        case .AccessLog:
            let log = obj as! AVPlayerItemAccessLogEvent
            self._emitEvent("New access log entry: indicated:\(log.indicatedBitrate) -- switch:\(log.switchBitrate) -- stalls: \(log.numberOfStalls) -- durationListened: \(log.durationWatched)")

            self.oAccessLog.notify(log)
        case .ErrorLog:
            let log = obj as! AVPlayerItemErrorLogEvent
            self._emitEvent("New error log entry \(log.errorStatusCode): \(log.errorComment)")

            self.oErrorLog.notify(log)
        case .Playing:
            // we're hitting play as part of our seek operations, so don't
            // pass on that status yet if .Seeking
            if self.status != .Seeking {
                self._setStatus(.Playing)
            }
            // self._setStatus(.Playing)
        case .Paused:
            // we pause as part of seeking, so don't pass on that status
            if self.status != .Seeking {
                self._setStatus(.Paused)
            }
        case .LikelyToKeepUp:
            NSLog("playback should keep up")
        case .UnlikelyToKeepUp:
            NSLog("playback unlikely to keep up")
        case .TimeJump:
            NSLog("Player reports that time jumped.")

            let lastRecordedTime:String

            if self.currentDates != nil && self.currentDates!.hasDates() {
                lastRecordedTime = self._dateFormat.stringFromDate(self.currentDates!.curDate!)
            } else {
                lastRecordedTime = "Unknown"
            }

            let newDate:String
            if let curDate = self._player.currentItem?.currentDate() {
                newDate = self._dateFormat.stringFromDate(curDate)
            } else {
                newDate = "Unknown"
            }

            self._emitEvent("Time jump! Last recorded time: \(lastRecordedTime). New time: \(newDate)")
        default:
            true
        }
    }

    //----------

    private func setNetworkStatus() {
//        var s:NetworkStatus

//        switch self._reachability!.currentReachabilityStatus {
//        case .ReachableViaWiFi:
//            NSLog("Reach is WIFI")
//
//            s = .WIFI
//        case .ReachableViaWWAN:
//            NSLog("Reach is cellular")
//            s = .Cellular
//        case .NotReachable:
//            NSLog("Reach is unreachable")
//            s = .NotReachable
//        }
//
//        if s != self._networkStatus {
//            self._networkStatus = s
//            self._emitEvent("Network status is now \(s.toString())")
//            self.oNetwork.notify(s)
//        }
    }

    //----------

    private func getPlayer() -> AVPlayer {
        return self._player
    }

    //----------

    public func bufferedSecs() -> Double? {
        if ( self._player.currentItem?.loadedTimeRanges.count > 0 ) {
            let loaded_range = self._player.currentItem!.loadedTimeRanges[0].CMTimeRangeValue
            let buffered = CMTimeGetSeconds(CMTimeSubtract(CMTimeRangeGetEnd(loaded_range), self._player.currentTime()))

            return buffered
        } else {
            return nil
        }
    }

    //----------

    private func _emitEvent(msg:String) -> Void {
        let event = AudioEvent(message: msg)
        self.oEventLog.notify(event)
    }

    //----------

    private func _setStatus(s:AudioStatus) -> Void {
        if !(self.status == s) {
            self.prevStatus = self.status
            self.status = s

            self._emitEvent("Player status is now \(s.toString())")
            self.oStatus.notify(s)
        }
    }

    //----------

    public func getAccessLog() -> AVPlayerItemAccessLog? {
        return self._player.currentItem?.accessLog()
    }

    //----------

    public func getErrorLog() -> AVPlayerItemErrorLog? {
        return self._player.currentItem?.errorLog()
    }

    //----------

    public func observeStatus(o:(AudioStatus) -> Void) -> Void {
        self.oStatus.addObserver(o)
    }

    //----------

    public func observeTime(o:(StreamDates) -> Void) -> Void {
        self.oTime.addObserver(o)
    }

    public func observeEvents(o:(AudioEvent) -> Void) -> Void {
        self.oEventLog.addObserver(o)
    }

    //----------

    public func play() -> Bool{
        self._interactionIdx++
        self._setStatus(.Waiting)
        self.getPlayer().play()
        return true
    }

    //----------

    public func pause() -> Bool {
        self._interactionIdx++
        self._setStatus(.Waiting)
        self.getPlayer().pause()
        return true
    }

    //----------

    public func stop() -> Bool {
        // tear down player and observer
        self.pause()
        self.observer.stop()

        self.currentDates = nil
        self._setStatus(AudioStatus.Stopped)

        return true
    }

    //----------

    public func currentTime() -> CMTime {
        return self._player.currentTime()
    }

    //----------

    public func currentDate() -> NSDate? {
        return self.currentDates?.curDate
    }

    public func duration() -> CMTime {
        return self._player.currentItem!.asset.duration
    }

    //----------

    private func _getReadyPlayer(c:finishCallback) -> Void {
        if ( self._player.status == AVPlayerStatus.Failed || self._player.currentItem?.status == AVPlayerItemStatus.Failed) {
            self._emitEvent("_getReadyPlayer instead found a failed player/item.");
            return;
        }

        if ( self._player.status == AVPlayerStatus.ReadyToPlay && self._player.currentItem?.status == AVPlayerItemStatus.ReadyToPlay) {
            // ready...
            self._emitEvent("_getReadyPlayer Item was already ready.")
            c(false)
        } else {
            // is the player ready?
            if ( self._player.status == AVPlayerStatus.ReadyToPlay) {
                // yes... so we need to wait for the item
                self._emitEvent("_getReadyPlayer Item not ready. Waiting.")
                self.observer.once(.ItemReady) { msg,obj in
                    self._emitEvent("_getReadyPlayer Item is now ready.")
                    c(true)
                }
            } else {
                // no... wait for the player
                self._emitEvent("_getReadyPlayer Player not ready. Waiting.")
                self.observer.once(.PlayerReady) { msg,obj in
                    self._emitEvent("_getReadyPlayer Player is now ready.")
                    self._getReadyPlayer(c)
                }
            }
        }
    }

    //----------

    public func seekByInterval(interval:NSTimeInterval,completion:finishCallback? = nil) -> Void {
        self._emitEvent("seekByInterval called for \(interval)")

        // get a seek sequence number
        let seek_id = ++self._interactionIdx

        self._getReadyPlayer() { cold in
            if (self._interactionIdx != seek_id) {
                self._emitEvent("seekByInterval interrupted.")
                completion?(false)
                return;
            }

            self._setStatus(.Seeking)

            // we need to start playing before any seek operations
            // FIXME: Add volume management?
            if self._player.rate != 1.0 {
                self._emitEvent("seekByInterval Hitting play before seeking")
                self._player.play()
            }

            let seek_time = CMTimeAdd(self._player.currentItem!.currentTime(), CMTimeMakeWithSeconds(interval, 10))
            self._player.currentItem!.seekToTime(seek_time, toleranceBefore:kCMTimeZero, toleranceAfter:kCMTimeZero) {finished in
                self._setStatus(.Playing)
                completion?(finished)
//                self._emitEvent("seekByInterval landed \(self._dateFormat.stringFromDate(self._player.currentItem!.currentDate()!))")
            }

        }
    }

    //----------

    // FIXME: I thought I should just be able to call _seekToDate directly 
    // with this signature?
    public func seekToDate(date:NSDate, completion:finishCallback? = nil) -> Void {
        self._seekToDate(date, completion:completion);
    }

    public func _seekToDate(date: NSDate,retries:Int = 2,useTime:Bool = false,completion:finishCallback? = nil) -> Void {
        let fsig = "seekToDate (" + ( useTime ? "time" : "date" ) + ") "

        // do we think we can do this?
        // FIXME: check currentDates if we have them
        self._emitEvent(fsig + "called for \(self._dateFormat.stringFromDate(date))")

        // get a seek sequence number
        let seek_id = ++self._interactionIdx

        self._getReadyPlayer() { cold in
            if (self._interactionIdx != seek_id) {
                self._emitEvent(fsig+"seek interrupted.")
                completion?(false)
                return;
            }

            self._setStatus(.Seeking)

            // we need to start playing before any seek operations
            // FIXME: Add volume management?
            if self._player.rate != 1.0 {
                self._emitEvent(fsig+"Hitting play before seeking")
                self._player.play()
            }

            let playFunc = { () -> Void in
                // we're already "playing". Just change our status
                // FIXME: Add volume management?
                self._setStatus(.Playing)
            }

            // Set up common code for testing our landing position
            let testLanding = { (finished:Bool) -> Void in

                if finished {
                    // how close did we get?
                    let landed = self._player.currentItem!.currentDate()!

                    self._emitEvent(fsig+"landed at \(self._dateFormat.stringFromDate(landed))")

                    if abs( Int(date.timeIntervalSinceReferenceDate - landed.timeIntervalSinceReferenceDate) ) <= self.seekTolerance {
                        // success! start playing
                        self._emitEvent(fsig+"hitting play")
                        playFunc()

                        completion?(true)
                    } else {
                        // not quite... try again, as long as we have retries
                        if self._interactionIdx == seek_id {
                            switch retries {
                            case 0:
                                self._emitEvent("seekToDate ran out of retries. Playing from here.")
                                playFunc()
                                completion?(true)
                            case 1:
                                // last try always uses time
                                self._seekToDate(date, retries: retries-1, useTime:true, completion:completion)
                            default:
                                self._seekToDate(date, retries: retries-1, completion:completion)
                            }
                        }
                    }
                } else {
                    self._emitEvent(fsig+"did not finish.")

                    // if we get here, but our seek_id is still the current one, we should retry. If
                    // id has changed, there's another seek operation started and we should stop
                    if self._interactionIdx == seek_id {
                        switch retries {
                        case 0:
                            self._emitEvent("seekToDate is out of retries")
                            completion?(false)

                        case 1:
                            self._seekToDate(date, retries: retries-1, useTime:true, completion:completion)
                        default:
                            self._seekToDate(date, retries: retries-1, completion:completion)
                        }
                    } else {
                        completion?(false)
                    }
                }
            }

            // SEEK!

            // how far are we trying to go?
            let offsetSeconds = date.timeIntervalSinceReferenceDate - self._player.currentItem!.currentDate()!.timeIntervalSinceReferenceDate

            // we'll cheat and use time for short seeks, which seem to
            // sometimes leave seekToDate stuck playing a loop
            // also, a cold seek with seekToDate never works, so start with seekToTime

            if (cold || useTime || abs(offsetSeconds) < 60) {
                let seek_time = CMTimeAdd(self._player.currentItem!.currentTime(), CMTimeMakeWithSeconds(offsetSeconds, 10))
                self._emitEvent(fsig+"seeking \(offsetSeconds) seconds.")
                self._player.currentItem!.seekToTime(seek_time, toleranceBefore:kCMTimeZero, toleranceAfter:kCMTimeZero, completionHandler:testLanding)
            } else {
                // use seekToDate
                self._player.currentItem!.seekToDate(date, completionHandler:testLanding)
            }
        }
    }

    //----------

    public func seekToPercent(percent: Float64,completion:finishCallback? = nil) -> Bool {
        let str_per = String(format:"%2f", percent)
        self._emitEvent("seekToPercent called for \(str_per)")

        if (self._player.currentItem?.duration > kCMTimeZero) {
            // this is an on-demand file, so just seek using the percentage
            let dur = self._player.currentItem!.duration
            let seek_time = CMTimeMultiplyByFloat64(dur, percent)

            self._seekToTime(seek_time,completion:completion)
            return true

        } else {
            // convert percent into a date and then just call seekToDate
            if self.currentDates != nil {
                let date = self.currentDates!.percentToDate(percent)

                if date != nil {
                    self.seekToDate(date!,completion:completion)
                    return true
                } else {
                    return false
                }
            } else {
                return false
            }

        }
    }

    //----------

    private func _seekToTime(time:CMTime,completion:finishCallback?) -> Void {
        self._emitEvent("_seekToTime called for \(time)")

        let seek_id = ++self._interactionIdx

        self._getReadyPlayer() { cold in
            if (self._interactionIdx != seek_id) {
                self._emitEvent("_seekToTime: seek interrupted.")
                completion?(false)
                return;
            }

            if self._player.rate != 1.0 {
                self._player.play()
            }

            self._player.currentItem!.seekToTime(time) { finished in
                completion?(finished)
            }
        }
    }

    //----------

    public func seekToLive(completion:finishCallback?) -> Void {
        self._emitEvent("seekToLive called")
        self._seekToTime(kCMTimePositiveInfinity) { finished in
            self._emitEvent("_seekToTime landed at \(self._dateFormat.stringFromDate(self._player.currentItem!.currentDate()!))")
            completion?(finished)
        }
    }

    //----------
}