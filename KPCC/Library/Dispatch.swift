//
//  Dispatch.swift
//  KPCC
//
//  Created by Fuller, Christopher on 6/7/16.
//  Copyright © 2016 Southern California Public Radio. All rights reserved.
//

import Foundation

typealias Block = () -> Void
typealias CompletionBlock = (Bool) -> Void

struct Dispatch {

    private var predicate: dispatch_once_t = 0

}

extension Dispatch {

    enum QueueType {

        case Main
        case Global(QualityOfService)

        enum QualityOfService {
            case UserInteractive
            case UserInitiated
            case Utility
            case Background
        }

        var queue: dispatch_queue_t {
            switch self {
            case .Main:
                return dispatch_get_main_queue()
            case let .Global(qos):
                switch qos {
                case .UserInteractive:
                    return dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0)
                case .UserInitiated:
                    return dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0)
                case .Utility:
                    return dispatch_get_global_queue(QOS_CLASS_UTILITY, 0)
                case .Background:
                    return dispatch_get_global_queue(QOS_CLASS_BACKGROUND, 0)
                }
            }
        }

    }

}

extension Dispatch {

    static func async(queueType queueType: QueueType = .Main, delay: Double? = nil, block: Block) {
        async(queue: queueType.queue, delay: delay, block: block)
    }

    static func async(queue queue: dispatch_queue_t, delay: Double? = nil, block: Block) {
        if let delay = delay where delay > 0.0 {
            let when = dispatch_time(DISPATCH_TIME_NOW, Int64(delay * Double(NSEC_PER_SEC)))
            dispatch_after(when, queue, block)
        }
        else {
            dispatch_async(queue, block)
        }
    }

}

extension Dispatch {

    mutating func once(block: Block) {
        dispatch_once(&predicate, block)
    }

}
