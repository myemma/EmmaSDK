#import "EMTrigger.h"
#import "NSObject+ObjectOrNil.h"
#import "NSNumber+ObjectIDString.h"

@implementation EMTrigger

- (NSArray *)objectIDArray:(id)value {
    return [[value arrayOrNil].rac_sequence map:^id(NSNumber *groupID) {
        return [[groupID numberOrNil] objectIDStringValue];
    }].array;
}

- (id)initWithDictionary:(NSDictionary *)dictionary {
    if (self = [super init]) {
        _triggerID = [[dictionary[@"trigger_id"] numberOrNil] objectIDStringValue];
        _name = [dictionary[@"name"] stringOrNil];
        _parentMailingID = [[dictionary[@"parent_mailing_id"] numberOrNil] objectIDStringValue];
        _fieldID = [[dictionary[@"field_id"] numberOrNil] objectIDStringValue];
        _groupIDs = [self objectIDArray:dictionary[@"groups"]];
        _linkIDs = [self objectIDArray:dictionary[@"links"]];
        _signupFormIDs = [self objectIDArray:dictionary[@"signups"]];
        _surveyIDs = [self objectIDArray:dictionary[@"surveys"]];
        _pushOffset = [dictionary[@"push_offset"] stringOrNil];
        _disabled = [[dictionary[@"is_disabled"] numberOrNil] boolValue];
    }
    return self;
}

@end
