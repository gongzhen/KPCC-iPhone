//
//  SCPRHomeViewController.swift
//  KPCC
//
//  Created by John Meeker on 6/3/14.
//  Copyright (c) 2014 SCPR. All rights reserved.
//

import Foundation
import UIKit


class SCPRHomeViewController: UIViewController, AudioManagerDelegate, ContentProcessor {
    
    @IBOutlet var programTitleLabel : UILabel!
    @IBOutlet var programTimeLabel : UILabel!
    @IBOutlet var timeLabel: UILabel!
    @IBOutlet var streamerStatusLabel : UILabel!
    @IBOutlet var streamerUrlLabel : UILabel!
    @IBOutlet var streamIndicatedBitrateLabel : UILabel!
    @IBOutlet var maxObservedBitrateLabel : UILabel!
    @IBOutlet var minObservedBitrateLabel : UILabel!
    @IBOutlet var actionButton : UIButton!
    @IBOutlet var stopButton : UIButton!
    @IBOutlet var userReportButton : UIButton!
    @IBOutlet var audioSlider : UISlider!
    @IBOutlet var backToProgramStartButton : UIButton!
    @IBOutlet var forwardToLiveButton : UIButton!
    @IBOutlet var forwardSeekButton : UIButton!
    @IBOutlet var backwardSeekButton : UIButton!
    var currentProgramTitle : String = ""
    var currentProgram : Program!
    @IBAction func buttonTapped(button: AnyObject) {
        if button as NSObject == actionButton {
            playOrPauseTapped()
        }
        if button as NSObject == stopButton {
            stopTapped()
        }
        if button as NSObject == userReportButton {
            userReportTapped()
        }
        if button as NSObject == backToProgramStartButton {
            backToProgramStartTapped()
        }
        if button as NSObject == forwardToLiveButton {
            forwardToLiveTapped()
        }
        if button as NSObject == forwardSeekButton {
            forwardSeekTapped()
        }
        if button as NSObject == backwardSeekButton {
            backwardSeekTapped()
        }
    }
    
    @IBAction func handleViewTap() {
        self.dismissViewControllerAnimated(true, nil)
    }
    
    required init(coder aDecoder: NSCoder) { super.init(coder: aDecoder) }
    
    // For beta
    var timer = NSTimer()

    override func canBecomeFirstResponder() -> Bool {
        return true
    }
    
    override func remoteControlReceivedWithEvent(event: UIEvent)  {
        // Handle remote audio control events.
        if (event.type == UIEventType.RemoteControl) {
            if (event.subtype == UIEventSubtype.RemoteControlPlay ||
                event.subtype == UIEventSubtype.RemoteControlPause ||
                event.subtype == UIEventSubtype.RemoteControlTogglePlayPause) {
                    playOrPauseTapped()
            }
            if (event.subtype == UIEventSubtype.RemoteControlNextTrack) {
                forwardSeekTapped()
            }
            if (event.subtype == UIEventSubtype.RemoteControlPreviousTrack) {
                backwardSeekTapped()
            }
        }
    }
    
    override func viewDidAppear(animated: Bool) {
        super.viewDidDisappear(animated);
        
        // Set the current view to recieve events from the AudioManagerDelegate.
        AudioManager.shared().delegate = self
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        //self.navigationItem.title = "KPCC"

        // Fetch program info and update audio control state.
        updateDataForUI()
        
        // Once the view has loaded then we can register to begin recieving system audio controls.
        UIApplication.sharedApplication().beginReceivingRemoteControlEvents()
        becomeFirstResponder()
        
        // Observe when the application becomes active again, and update UI if need-be.
        NSNotificationCenter.defaultCenter().addObserver(self, selector:"updateDataForUI", name: UIApplicationWillEnterForegroundNotification, object: nil)
        
        // For beta
        timer = NSTimer(timeInterval: 1.0, target: self, selector: "tick", userInfo: nil, repeats: true)
        NSRunLoop.currentRunLoop().addTimer(timer, forMode: NSRunLoopCommonModes)
        
        // Experiment with CoreData fetch
        var program = Program.fetchObjectFromContext(ContentManager.shared().managedObjectContext)
        if ((program) != nil) {
            updateUIWithProgram(program)
        }
        
        
        //audioSlider.addTarget(self, action:"updateSlider", forControlEvents: UIControlEvents.ValueChanged)
    }
    
    // For beta to update UI
    func tick() -> Void {
        streamIndicatedBitrateLabel.text = NSString.stringWithString("\(AudioManager.shared().indicatedBitrate())")
        maxObservedBitrateLabel.text = NSString.stringWithString("\(AudioManager.shared().observedMaxBitrate())")
        minObservedBitrateLabel.text = NSString.stringWithString("\(AudioManager.shared().observedMinBitrate())")
    }
    
    func userReportTapped() -> Void {
        let viewController = SCPRUserReportViewController(nibName: "SCPRUserReportViewController", bundle: nil)
        self.presentViewController(viewController, animated: true, completion: nil)
    }
    
    func receivePlayerStateNotification() -> Void {
        updateControlsAndUI()
    }
    
    func updateDataForUI() -> Void {
        NetworkManager.shared().fetchProgramInformationFor(NSDate.date(), display: self)
        updateControlsAndUI()
    }
    
    func updateControlsAndUI() -> Void {
        if AudioManager.shared().isStreamPlaying() || AudioManager.shared().isStreamBuffering() {
            actionButton.setImage(UIImage(named: "pauseButton"), forState: UIControlState.Normal)
        } else {
            actionButton.setImage(UIImage(named: "playButton"), forState: UIControlState.Normal)
        }
        
        if (AudioManager.shared().audioPlayer != nil) {
            streamerStatusLabel.text = AudioManager.shared().isStreamPlaying() ? "playing" : "not playing"
        }
        
        streamerUrlLabel.text = AudioManager.shared().liveStreamURL()
        streamIndicatedBitrateLabel.text = NSString.stringWithString("\(AudioManager.shared().indicatedBitrate())")
        maxObservedBitrateLabel.text = NSString.stringWithString("\(AudioManager.shared().observedMaxBitrate())")
        minObservedBitrateLabel.text = NSString.stringWithString("\(AudioManager.shared().observedMinBitrate())")
    }
    
    // Time shifting
    func updateSlider() -> Void {
        //AudioManager.shared().seekToPercent(audioSlider.value)
    }
    
    func backToProgramStartTapped() -> Void {
        if let programStartTime = currentProgram!.starts_at {
            AudioManager.shared().seekToDate(programStartTime)
        }
    }
    
    func forwardToLiveTapped() -> Void {
        AudioManager.shared().forwardSeekLive()
    }

    func forwardSeekTapped() -> Void {
        AudioManager.shared().forwardSeekThirtySeconds()
    }
    
    func backwardSeekTapped() -> Void {
        AudioManager.shared().backwardSeekThirtySeconds()
    }

    func playOrPauseTapped() -> Void {
        if !AudioManager.shared().isStreamPlaying() {
            if AudioManager.shared().isStreamBuffering() {
                AudioManager.shared().stopAllAudio()
                JDStatusBarNotification.dismiss()
            } else {
                playStream()
            }
        } else {
            pauseStream()
        }
        updateNowPlayingInfoWithProgram(currentProgram)
    }
    
    func stopTapped() -> Void {
        AudioManager.shared().stopAllAudio()
        updateNowPlayingInfoWithProgram(currentProgram)
    }
    
    func playStream() -> Void {
        AudioManager.shared().startStream()
    }
    
    func pauseStream() -> Void {
        AudioManager.shared().pauseStream()
    }
    
    func updateUIWithProgram(program : Program?) {
        if (program == nil) {
            return
        }
        
        if let title = program?.title {
            currentProgramTitle = title
            programTitleLabel.text = currentProgramTitle
        }
        
        // Set program runtime label.
        if let startsAtDate = program?.starts_at {
            var timeString = prettyStringFromRFCDate(startsAtDate)
            if let endsAtDate = program?.ends_at {
                timeString = timeString + " - " + prettyStringFromRFCDate(endsAtDate)
            }
            
            programTimeLabel.text = timeString
        }
        
        updateNowPlayingInfoWithProgram(program!)
    }
    
    func updateNowPlayingInfoWithProgram(program : Program?) {
        if (program == nil) {
            return
        }
        
        var nowPlayingInfo = NSMutableDictionary(dictionary: MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo)
        nowPlayingInfo.setObject("89.3 KPCC", forKey: MPMediaItemPropertyArtist)
        nowPlayingInfo.setObject(AudioManager.shared().isStreamPlaying() ? 1.0 : 0.0, forKey: MPNowPlayingInfoPropertyPlaybackRate)
        
        if let title = program?.title {
            nowPlayingInfo.setObject(title, forKey: MPMediaItemPropertyTitle)
        }
        
        /* Remove playback duration for now.
        if AudioManager.shared().isStreamPlaying() {
            if let programEndTime = program!.ends_at {
                nowPlayingInfo.setObject(programEndTime.timeIntervalSinceDate(AudioManager.shared().audioPlayer.currentItem.currentDate()), forKey: MPMediaItemPropertyPlaybackDuration)
            }
        }*/
        
        MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = nowPlayingInfo
    }
    
    // AudioManagerDelegate
    func handleUIForFailedConnection() -> Void {
        JDStatusBarNotification.showWithStatus("Oh No! The connection is bad.", styleName: JDStatusBarStyleWarning)
    }
    
    func handleUIForFailedStream() -> Void {
        JDStatusBarNotification.showWithStatus("Oh No! Our stream has lost power.", styleName: JDStatusBarStyleError)
    }
    
    func handleUIForRecoveredStream() -> Void {
        JDStatusBarNotification.showWithStatus("And we're back!", dismissAfter:4.0, styleName: JDStatusBarStyleSuccess)
        playStream()
        updateControlsAndUI()
    }
    
    func onTimeChange() -> Void {
        timeLabel.text = AudioManager.shared().currentDateTimeString()
    }
    
    func onRateChange() -> Void {
        updateControlsAndUI()
    }
    
    // ContentProcessor
    func handleProcessedContent(content: NSArray, flags: NSDictionary) -> Void {
        if content.count == 0 {
            return;
        }
        
        // Create Program and insert into managed object context
        let program = content.objectAtIndex(0) as NSDictionary
        var newProgram = Program.insertNewObjectIntoContext(ContentManager.shared().managedObjectContext)
        
        if let title = program.objectForKey("title") as? NSString {
            newProgram.title = title
            currentProgramTitle = title
            programTitleLabel.text = currentProgramTitle
        }
        
        
        // Set program runtime label.
        if let startsAt = program.objectForKey("starts_at") as? NSString {
            var startTime = dateFromRFCString(startsAt)
            newProgram.starts_at = startTime

            var timeString = prettyStringFromRFCDateString(startsAt)

            if let endsAt = program.objectForKey("ends_at") as? NSString {
                var endTime = dateFromRFCString(endsAt)
                newProgram.ends_at = endTime
                
                timeString = timeString + " - " + prettyStringFromRFCDateString(endsAt)
                
                MPNowPlayingInfoCenter.defaultCenter().nowPlayingInfo = [MPMediaItemPropertyPlaybackDuration : endTime.timeIntervalSinceDate(startTime)]
            }

            programTimeLabel.text = timeString
        }
        
        currentProgram = newProgram
        updateNowPlayingInfoWithProgram(currentProgram)
        
        // Save the Program to persistant storage.
        ContentManager.shared().saveContext()
    }
    
    // Date helper functions
    func dateFromRFCString(dateString: NSString) -> NSDate {
        if (dateString == NSNull()) {
            return NSDate.date();
        }
        
        var rfc3339DateFormatter = NSDateFormatter()
        rfc3339DateFormatter.dateFormat = "yyyy-MM-dd'T'HHmmssZZZ"
        rfc3339DateFormatter.timeZone = NSTimeZone(forSecondsFromGMT: 0)
        
        var fixedDateString = dateString.stringByReplacingOccurrencesOfString(":", withString: "")
        
        // Convert the RFC 3339 date time string to an NSDate.
        var date = rfc3339DateFormatter.dateFromString(fixedDateString)
        if (date == nil) {
            rfc3339DateFormatter.dateFormat = "yyyy-MM-dd'T'HHmmss.000ZZZ"
            return rfc3339DateFormatter.dateFromString(fixedDateString)!
        }
        return date!;
    }
    
    func prettyStringFromRFCDateString(rawDate: NSString) -> NSString {
        let date = dateFromRFCString(rawDate)
        var outputFormatter = NSDateFormatter()
        outputFormatter.dateFormat = "h:mm a"
        outputFormatter.timeZone = NSTimeZone(forSecondsFromGMT: NSTimeZone.localTimeZone().secondsFromGMT)
        var dateString = outputFormatter.stringFromDate(date)
        return dateString
    }
    
    func prettyStringFromRFCDate(date: NSDate) -> NSString {
        var outputFormatter = NSDateFormatter()
        outputFormatter.dateFormat = "h:mm a"
        outputFormatter.timeZone = NSTimeZone(forSecondsFromGMT: NSTimeZone.localTimeZone().secondsFromGMT)
        var dateString = outputFormatter.stringFromDate(date)
        return dateString
    }
 
}
