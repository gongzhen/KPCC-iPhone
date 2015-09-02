//
//  AudioStatus.swift
//  KPCC
//
//  Created by Eric Richardson on 8/29/15.
//  Copyright © 2015 SCPR. All rights reserved.
//

import Foundation
import AVFoundation

public struct KPCCPlayerObserver<T> {
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

@objc public enum AudioStatus:Int {
    case New = 0, Stopped = 1, Playing = 2, Waiting = 3, Seeking = 4, Paused = 5, Error = 6

    func toString() -> String {
        let s = ["New","Stopped","Playing","Waiting","Seeking","Paused","Error"]
        return s[self.rawValue]
    }
}

@objc public class AVStatus: NSObject {
    public var oStatus              = KPCCPlayerObserver<AudioStatus>()

    var _prevStatus: AudioStatus    = AudioStatus.New
    var _status: AudioStatus        = AudioStatus.New

    @objc func observe(o:(AudioStatus) -> Void) -> Void {
        self.oStatus.addObserver(o)
    }

    @objc func status() -> AudioStatus {
        return self._status
    }

    @objc func toString() -> NSString {
        return self._status.toString()
    }

    @objc func setStatus(s:AudioStatus) -> Void {
        if !(self._status == s) {
            self._prevStatus = self._status
            self._status = s

            self.oStatus.notify(s)
        }
    }

    @objc func stopped() -> Bool {
        switch (self._status) {
        case .New, .Stopped, .Error:
            return true
        default:
            return false
        }
    }
}