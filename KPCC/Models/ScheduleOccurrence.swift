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

    private static let entityName = "ScheduleOccurrence"

    @NSManaged var title:String;
    @NSManaged var ends_at:NSDate;
    @NSManaged var starts_at:NSDate;
    @NSManaged var soft_starts_at:NSDate;
    @NSManaged var public_url:String;
    @NSManaged var program_slug:String;

    @objc var duration:NSTimeInterval = 0

    static func newScheduleOccurrence(context context: NSManagedObjectContext, dictionary: NSDictionary) -> ScheduleOccurrence? {

        guard let
            title = dictionary["title"] as? String,
            ends_at = dictionary["ends_at"] as? String,
            starts_at = dictionary["starts_at"] as? String,
            soft_starts_at = dictionary["soft_starts_at"] as? String,
            public_url = dictionary["public_url"] as? String,
            program_slug = dictionary["program"]?["slug"] as? String
            else {
                return nil
        }

        guard let
            ends_at_date = Utils.dateFromRFCString(ends_at),
            starts_at_date = Utils.dateFromRFCString(starts_at),
            soft_starts_at_date = Utils.dateFromRFCString(soft_starts_at)
            else {
                return nil
        }

        return newScheduleOccurrence(
            context: context,
            title: title,
            ends_at: ends_at_date,
            starts_at: starts_at_date,
            soft_starts_at: soft_starts_at_date,
            public_url: public_url,
            program_slug: program_slug
        )

    }

    static func newScheduleOccurrence(context context: NSManagedObjectContext, title: String, ends_at: NSDate, starts_at: NSDate, soft_starts_at: NSDate, public_url: String, program_slug: String) -> ScheduleOccurrence? {

        let object = NSEntityDescription.insertNewObjectForEntityForName(
            entityName,
            inManagedObjectContext: context
        )

        guard let scheduleOccurrence = object as? ScheduleOccurrence else {
            return nil
        }

        scheduleOccurrence.title = title
        scheduleOccurrence.ends_at = ends_at
        scheduleOccurrence.starts_at = starts_at
        scheduleOccurrence.soft_starts_at = soft_starts_at
        scheduleOccurrence.public_url = public_url
        scheduleOccurrence.program_slug = program_slug

        // compute duration
        scheduleOccurrence.duration = scheduleOccurrence.ends_at.timeIntervalSinceDate(scheduleOccurrence.starts_at)

        return scheduleOccurrence

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

    func percentageToDate(percent: Double) -> NSDate {
        let duration = self.ends_at.timeIntervalSinceReferenceDate - self.starts_at.timeIntervalSinceReferenceDate
        let seconds: Double = duration * clamp(0.0, percent, 1.0)
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