#import "EMTrigger.h"
#import "NSObject+ObjectOrNil.h"
#import "NSNumber+ObjectIDString.h"

EMTriggerEventType EMTriggerEventTypeFromString(NSString *s) {
    if (!s)
        return EMTriggerEventUnknown;
    
    return [@{
             @"s": @(EMTriggerEventSignup),
             @"c": @(EMTriggerEventClick),
             @"u": @(EMTriggerEventSurvey),
             @"d": @(EMTriggerEventDate),
             @"r": @(EMTriggerEventRecurringDate)
            }[s] intValue];
}

NSString *EMTriggerEventTypeToString(EMTriggerEventType eventType) {
    if (eventType == EMTriggerEventUnknown)
        return @"";
    
    return @{
            @(EMTriggerEventSignup): @"s",
            @(EMTriggerEventClick): @"c",
            @(EMTriggerEventSurvey): @"u",
            @(EMTriggerEventDate): @"d",
            @(EMTriggerEventRecurringDate): @"r",
            }[@(eventType)];
}

@implementation EMTrigger

- (NSArray *)objectIDStringArrayFromNumberArray:(id)value {
    return [[value arrayOrNil].rac_sequence map:^id(NSNumber *groupID) {
        return [[groupID numberOrNil] objectIDStringValue];
    }].array;
}

- (NSArray *)numberArayFromObjectIDStringArray:(NSArray *)objectIDs {
    return [objectIDs.rac_sequence map:^id(id value) {
        return [NSNumber numberWithObjectIDString:value];
    }].array;
}

- (id)initWithDictionary:(NSDictionary *)dictionary {
    if (self = [super init]) {
        _triggerID = [[dictionary[@"trigger_id"] numberOrNil] objectIDStringValue];
        _name = [dictionary[@"name"] stringOrNil];
        _parentMailingID = [[dictionary[@"parent_mailing_id"] numberOrNil] objectIDStringValue];
        _fieldID = [[dictionary[@"field_id"] numberOrNil] objectIDStringValue];
        _groupIDs = [self objectIDStringArrayFromNumberArray:dictionary[@"groups"]];
        _linkIDs = [self objectIDStringArrayFromNumberArray:dictionary[@"links"]];
        _signupFormIDs = [self objectIDStringArrayFromNumberArray:dictionary[@"signups"]];
        _surveyIDs = [self objectIDStringArrayFromNumberArray:dictionary[@"surveys"]];
        _pushOffset = [dictionary[@"push_offset"] stringOrNil];
        _disabled = [[dictionary[@"is_disabled"] numberOrNil] boolValue];
        _eventType = EMTriggerEventTypeFromString([dictionary[@"event_type"] stringOrNil]);
    }
    return self;
}

- (NSDictionary *)dictionaryRepresentation {
    return @{
        @"name": ObjectOrNull(_name),
        @"parent_mailing_id": [NSNumber numberWithObjectIDString:ObjectOrNull(_parentMailingID)],
        @"field_id": [NSNumber numberWithObjectIDString:ObjectOrNull(_fieldID)],
        @"groups": ObjectOrNull([self numberArayFromObjectIDStringArray:_groupIDs]),
        @"links": ObjectOrNull([self numberArayFromObjectIDStringArray:_linkIDs]),
        @"signups": ObjectOrNull([self numberArayFromObjectIDStringArray:_signupFormIDs]),
        @"surveys": ObjectOrNull([self numberArayFromObjectIDStringArray:_surveyIDs]),
        @"push_offset": ObjectOrNull(_pushOffset),
        @"is_disabled": @(_disabled),
        @"event_type": EMTriggerEventTypeToString(_eventType)
     };
}

@end
