//
//  Report+Create.m
//  Estates Audit
//
//  Created by Colin Gormley on 13/04/2015.
//  Copyright (c) 2015 Colin Gormley. All rights reserved.
//

#import "Report+Create.h"
#import "Photo+Create.h"

#import   <UIKit/UIKit.h>

@implementation Report (Create)

+ (Report *)reportFromReportInfo:(NSDictionary *)reportDictionary
         inManangedObjectContext:(NSManagedObjectContext *)context
{
    Report *report = nil;

    NSNumber *ticketId = [reportDictionary valueForKeyPath:@"ticket_id"];

    if (ticketId) {
        NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Report"];
        request.predicate = [NSPredicate predicateWithFormat:@"ticket_id = %@", ticketId];
        
        NSError *error;
        NSArray *matches = [context executeFetchRequest:request error:&error];
        
        if (!matches || error || ([matches count] > 1 )) {
            // handle error
            NSLog(@"Something went wrong creating report : %@", ticketId);
        } else if (![matches count]) {
            //record ticketid doesn't exist for whatever reason just create a new one
            report = [Report insertNewObjectFromDict:reportDictionary inManagedContext:context];
            
        } else {
            report = [matches lastObject];

            NSArray *remoteImageUrls = [reportDictionary objectForKey:@"remoteImageUrls"];
            
            if([remoteImageUrls count] > 0){
          
                // Check if local photo
                NSArray *photoArray = [report.photos allObjects];
                if ([photoArray count] > 0){
                    // Check image name?
                    
                }else{
                    // No local photo
                    for(id imageUrl in remoteImageUrls){
                        NSLog(@"Storing remote image url: %@?", imageUrl);
                        // Store url
                        [Photo photoWithUrl:imageUrl fromReport:report inManagedObjectContext:report.managedObjectContext];
                    }
                }
            }
            
            // Check report status
            NSString *status = [reportDictionary valueForKey:@"status"];
     
            if(![report.status isEqualToString:status]){
                NSLog(@"Status updated");
                report.status = status;
               
                UILocalNotification *localNotification = [[UILocalNotification alloc] init];
                localNotification.fireDate = nil;
                localNotification.alertBody = [NSString stringWithFormat: @"Report ID %@ status changed to %@", ticketId, status];
                localNotification.timeZone = [NSTimeZone defaultTimeZone];
                localNotification.soundName = UILocalNotificationDefaultSoundName;
                localNotification.applicationIconBadgeNumber = [[UIApplication sharedApplication] applicationIconBadgeNumber] + 1;
                
                [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];
            }
            
            // Save the issueDate
            NSDate *issueDate = [reportDictionary objectForKey:@"issueDate"];
            report.issue_date = issueDate;
            
        }
    } else {
        report = [Report insertNewObjectFromDict:reportDictionary inManagedContext:context];
    }
    
    return report;
}

+(Report *)  insertNewObjectFromDict:(NSDictionary *)reportDictionary inManagedContext:(NSManagedObjectContext *)context {
    Report * report = [NSEntityDescription insertNewObjectForEntityForName:@"Report"
                                                    inManagedObjectContext:context];
    report.loc_desc = (NSString *)[reportDictionary valueForKeyPath:@"loc_desc"];
    report.desc = (NSString *)[reportDictionary valueForKeyPath:@"desc"];
    report.lon = (NSNumber *)[reportDictionary valueForKeyPath:@"lon"];
    report.lat = (NSNumber *)[reportDictionary valueForKeyPath:@"lat"];
    report.status = (NSString *)[reportDictionary valueForKeyPath:@"status"];
    report.issue_date = [NSDate date];

    
    NSNumber *ticketId = [reportDictionary valueForKeyPath:@"ticket_id"];
    if(ticketId > 0){
        report.ticket_id = ticketId;
    }else{
        // TODO - needs a more robust solution - remote chance that a ticket id could have the same id
        NSInteger rdmNumber = arc4random()%500;
        report.ticket_id = [NSNumber numberWithInt: rdmNumber];
        
    }
    
    // If the notifcation flag is set, this isn't a new local report in progress - it has come from jitBit so we show a notification
    NSNumber *notification = [reportDictionary valueForKeyPath:@"notification"];
    
    if([notification boolValue]){
        UILocalNotification *localNotification = [[UILocalNotification alloc] init];
        localNotification.fireDate = nil;
        localNotification.alertBody = [NSString stringWithFormat: @"New Report with ID %@ added", ticketId];
        localNotification.timeZone = [NSTimeZone defaultTimeZone];
        localNotification.soundName = UILocalNotificationDefaultSoundName;
        localNotification.applicationIconBadgeNumber = [[UIApplication sharedApplication] applicationIconBadgeNumber] + 1;
        
        [[UIApplication sharedApplication] scheduleLocalNotification:localNotification];

    }
    return report;
}

+(NSArray *) allReportsInManagedObjectContext:(NSManagedObjectContext *)context {
    NSFetchRequest *request = [NSFetchRequest fetchRequestWithEntityName:@"Report"];
    
    
    NSError *error;
    NSArray *matches = [context executeFetchRequest:request error:&error];
    if(error){
        NSLog(@"%@",[error localizedDescription]);
        return [[NSArray alloc] init];
    }
    return matches;
}



+ (NSDate *)extractJitBitDate:(NSString *)jitBitDateStr
{
    NSString *pattern = @"\\d+";
    NSRange searchedRange = NSMakeRange(0, [jitBitDateStr length]);
    NSRegularExpression* regex = [NSRegularExpression regularExpressionWithPattern: pattern options:0 error:nil];
    NSArray* matches = [regex matchesInString:jitBitDateStr options:0 range: searchedRange];
    
    for (NSTextCheckingResult* match in matches) {
        
        NSString* matchText = [jitBitDateStr substringWithRange:[match range]];
        
        // Convert to seconds
        NSTimeInterval seconds = [matchText doubleValue]/1000;
        NSDate* commentDate = [NSDate dateWithTimeIntervalSince1970:seconds];
        
        // Time is 5 hours in front of GMT for some reason
        NSDate *newDate = [commentDate dateByAddingTimeInterval:-3600*5];
        
        /*NSDateFormatter *dateFormatter = [[NSDateFormatter alloc] init];
        [dateFormatter setDateFormat:@"yyyy-MM-dd HH:mm:ss zzz"];
        NSString *formatted = [dateFormatter stringFromDate:newDate];
        NSLog(@"formatted1: %@", formatted);
        
        NSString *dstring = [NSDateFormatter localizedStringFromDate:newDate
                                                           dateStyle:NSDateFormatterLongStyle
                                                           timeStyle:NSDateFormatterMediumStyle];
        NSLog(@"formatted2: %@", dstring);*/
        return newDate;
    }
    return nil;
}

+ (void)loadReportsFromJitBitDictionary:(NSDictionary *)ticketsFromJitBit
                      withCustomFields :(NSDictionary *)ticketsCustomFieldsFromJitBit
               intoManagedObjectContext:(NSManagedObjectContext *)context
{
    
    // For each ticket, add a report to Core Data
    for(id key in ticketsFromJitBit){
        
        NSDictionary *ticket = [ticketsFromJitBit objectForKey:key];
        
        if(ticket){
            
            NSString *status = [ticket valueForKey:@"Status"];
            NSString *ticketId = [ticket valueForKey:@"TicketID"];
            NSArray *remoteImages = [ticket valueForKeyPath:@"Attachments"];
            
            NSMutableArray *remoteImageUrls = [[NSMutableArray alloc] init];
            for (id attachment in remoteImages) {
                NSString *remoteUrl = [attachment valueForKeyPath:@"Url"];
                [remoteImageUrls addObject:remoteUrl];
            }
            
         
            // Create new report to add to Core Data
            NSMutableDictionary *report = [NSMutableDictionary dictionary];

            NSString *issueDateStr = [ticket valueForKey:@"IssueDate"];
            
            NSDate *issueDate;
            if(issueDateStr) {
                // Have to use reg expression to extract and then correct timezone
                issueDate = [self extractJitBitDate:issueDateStr];
                [report setObject: issueDate forKey:@"issueDate"];
            }
            
            [report setValue: status forKey:@"status"];
            [report setValue: ticketId forKey:@"ticket_id"];
            [report setObject: remoteImageUrls forKey:@"remoteImageUrls"];
            
            
            NSArray *customFields = [ticketsCustomFieldsFromJitBit valueForKey:key];
         
            
            for (id customField in customFields) {
                // do something with object
                NSNumber *fieldId = [customField valueForKey:@"FieldID"];
                NSString *value = [customField valueForKey:@"Value"];
                
                //description
                if([fieldId isEqualToNumber: @9434]){
                    if(![value isKindOfClass:[NSNull class]]){
                        [report setValue: value forKey:@"desc"];

                    }
                }
                // Location Description
                else if ([fieldId isEqualToNumber: @9435]){
                    if(![value isKindOfClass:[NSNull class]]){
                        [report setValue: value forKey:@"loc_desc"];
                        
                    }
                }
                // Location coords
                else if ([fieldId isEqualToNumber: @9450]){
                    if(![value isKindOfClass:[NSNull class]]){
                        NSArray* coords = [value componentsSeparatedByString:@" "];
                        NSNumber *lat = @([coords[0] floatValue]);
                        NSNumber *lon = @([coords[1] floatValue]);
                        [report setValue: lat forKey:@"lat"];
                        [report setValue: lon forKey:@"lon"];
                        
                    }
                }
            }
            
            // This ensures a notification will be fired
            [report setObject:[NSNumber numberWithBool:YES] forKey:@"notification"];
            
            [self reportFromReportInfo:report inManangedObjectContext:context];
        }
    }
    
    // Save just to be sure
    [context save:NULL];
}


@end
