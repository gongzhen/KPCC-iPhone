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
    
    @IBOutlet var programTitleLabel : UILabel
    @IBOutlet var streamerStatusLabel : UILabel
    @IBOutlet var streamerUrlLabel : UILabel
    @IBOutlet var streamIndicatedBitrateLabel : UILabel
    @IBOutlet var maxObservedBitrateLabel : UILabel
    @IBOutlet var minObservedBitrateLabel : UILabel
    @IBOutlet var actionButton : UIButton
    var currentProgramTitle : String = ""
    @IBAction func buttonTapped(button: AnyObject) {
        if button as NSObject == actionButton {
            playOrPauseTapped()
        }
    }
    
    override func canBecomeFirstResponder() -> Bool {
        return true
    }
    
    override func remoteControlReceivedWithEvent(event: UIEvent!)  {
        // Handle remote audio control events.
        if (event.type == UIEventType.RemoteControl) {
            if (event.subtype == UIEventSubtype.RemoteControlPlay ||
                event.subtype == UIEventSubtype.RemoteControlPause ||
                event.subtype == UIEventSubtype.RemoteControlTogglePlayPause) {
                    playOrPauseTapped()
            }
        }
    }
    
    override func observeValueForKeyPath(keyPath: String!, ofObject object: AnyObject!, change: NSDictionary!, context: CMutableVoidPointer) {
        if keyPath == "rate" {
            updateControlsAndUI()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.navigationItem.title = "KPCC"
        
        // Fetch program info and update audio control state.
        updateDataForUI()
        
        // Once the view has loaded then we can register to begin recieving system audio controls.
        UIApplication.sharedApplication().beginReceivingRemoteControlEvents()
        becomeFirstResponder()
        
        // Observe when the application becomes active again, and update UI if need-be.
        NSNotificationCenter.defaultCenter().addObserver(self, selector:"updateDataForUI", name: UIApplicationWillEnterForegroundNotification, object: nil)
        
        // Add observer to AVPlayer "rate" object
        AudioManager.shared().audioPlayer.addObserver(self, forKeyPath: "rate", options: NSKeyValueObservingOptions.Old|NSKeyValueObservingOptions.New, context: nil)
        
        // Set the current view to recieve events from the AudioManagerDelegate.
        AudioManager.shared().delegate = self
        
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
        
        if AudioManager.shared().audioPlayer {
            streamerStatusLabel.text = AudioManager.shared().isStreamPlaying() ? "playing" : "not playing"
        }
        
        streamerUrlLabel.text = AudioManager.shared().liveStreamURL()
        streamIndicatedBitrateLabel.text = String(CFloat(AudioManager.shared().indicatedBitrate()))
        maxObservedBitrateLabel.text = String(CFloat(AudioManager.shared().observedMaxBitrate()))
        minObservedBitrateLabel.text = String(CFloat(AudioManager.shared().observedMinBitrate()))
    }
    
    func playOrPauseTapped() -> Void {
        if !AudioManager.shared().isStreamPlaying() {
            if AudioManager.shared().isStreamBuffering() {
                stopAllAudio()
                JDStatusBarNotification.dismiss()
            } else {
                playStream()
            }
        } else {
            stopStream()
        }
    }
    
    func playStream() -> Void {
        AudioManager.shared().startStream()
        updateNowPlayingInfoWithProgram(currentProgramTitle)
    }
    
    func stopStream() -> Void {
        AudioManager.shared().stopStream()
    }
    
    func stopAllAudio() -> Void {
        AudioManager.shared().stopAllAudio()
    }
    
    func updateNowPlayingInfoWithProgram(program: String!) {
        if program {
            //MPNowPlayingInfoCenter.defaultCenter().setValue(MPMediaItemPropertyArtist, forKey: "89.3 KPCC")
            //MPNowPlayingInfoCenter.defaultCenter().setValue(MPMediaItemPropertyTitle, forKey: program)
        }
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
    }
    
    // ContentProcessor
    func handleProcessedContent(content: NSArray, flags: NSDictionary) -> Void {
        if content.count == 0 {
            return;
        }
        
        if let title = content.objectAtIndex(0).objectForKey("title") as? NSString {
            currentProgramTitle = title
            programTitleLabel.text = currentProgramTitle
            updateNowPlayingInfoWithProgram(currentProgramTitle)
        }
    }

}
