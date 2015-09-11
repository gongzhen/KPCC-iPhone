//
//  ScheduleOccurrence.swift
//  KPCC
//
//  Created by Eric Richardson on 9/1/15.
//  Copyright © 2015 SCPR. All rights reserved.
//

import Foundation
import CoreData

@objc class ScheduleOccurrence: NSManagedObject, GenericProgram {
    @NSManaged var title:String;
    @NSManaged var ends_at:NSDate;
    @NSManaged var starts_at:NSDate;
    @NSManaged var public_url:String;
    @NSManaged var program_slug:String;
    @NSManaged var soft_starts_at:NSDate;

    @objc var duration:NSTimeInterval = 0

    class func entityName() -> String {
        return "ScheduleOccurrence"
    }

    convenience init(dict:NSDictionary) {
        let context = ContentManager.shared().managedObjectContext;

        let title = dict["title"] as! String
        let ends_at = Utils.dateFromRFCString(dict["ends_at"] as! String)
        let starts_at = Utils.dateFromRFCString(dict["starts_at"] as! String)
        let soft_start = Utils.dateFromRFCString(dict["soft_starts_at"] as! String)
        let public_url = dict["public_url"] as! String
        let program_slug = (dict["program"]?["slug"] as! String)

        self.init(context:context, title:title, ends_at:ends_at, starts_at:starts_at, public_url:public_url, program_slug:program_slug, soft_starts_at:soft_start)
    }

    init(context:NSManagedObjectContext, title:String, ends_at:NSDate, starts_at:NSDate, public_url:String, program_slug:String, soft_starts_at:NSDate) {
        let entityDescription = NSEntityDescription.entityForName("ScheduleOccurrence", inManagedObjectContext: context)!

        super.init(entity:entityDescription,insertIntoManagedObjectContext:context)

        self.title = title
        self.ends_at = ends_at
        self.starts_at = starts_at
        self.public_url = public_url
        self.program_slug = program_slug
        self.soft_starts_at = soft_starts_at

        // compute duration
        self.duration = self.ends_at.timeIntervalSinceReferenceDate - self.starts_at.timeIntervalSinceReferenceDate
    }

    //----------

    @objc func containsDate(date:NSDate) -> Bool {
        if (self.starts_at.timeIntervalSinceReferenceDate - 5 <= date.timeIntervalSinceReferenceDate && self.ends_at.timeIntervalSinceReferenceDate > date.timeIntervalSinceReferenceDate) {
            return true
        } else {
            return false
        }
    }

    //----------

    func percentageToDate(var percent:Double) -> NSDate {
        if (percent > 1.0) {
            percent = 1.0
        } else if (percent < 0.0) {
            percent = 0.0
        }
        
        let duration = self.ends_at.timeIntervalSinceReferenceDate - self.starts_at.timeIntervalSinceReferenceDate
        let seconds:Double = duration * percent
        return self.starts_at.dateByAddingTimeInterval(seconds)
    }

    //----------

    func dateToPercentage(date:NSDate) -> Double {
        let duration = self.ends_at.timeIntervalSinceReferenceDate - self.starts_at.timeIntervalSinceReferenceDate
        let seconds:Double = date.timeIntervalSinceReferenceDate - self.starts_at.timeIntervalSinceReferenceDate

        let percent = seconds / duration

        if 0.0 <= percent && percent < 1.0 {
            return percent
        } else if percent > 1.0 {
            return 1.0
        } else {
            return 0.0
        }
    }
}