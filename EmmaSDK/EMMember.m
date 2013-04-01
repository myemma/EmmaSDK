#import "EMMember.h"
#import "NSNumber+ObjectIDString.h"
#import "NSObject+ObjectOrNil.h"
#import "NSString+EMDateParsing.h"

NSString *EMMemberStatusToString(EMMemberStatus status) {
    NSString *result = nil;
    
    switch (status) {
        case EMMemberStatusAll:
            break;
        case EMMemberStatusActive:
            result = @"a";
            break;
        case EMMemberStatusError:
            result = @"e";
            break;
        case EMMemberStatusOptout:
            result = @"o";
            break;
        case EMMemberStatusForwarded:
            result = @"f";
            break;
    }
    
    return result;
}

EMMemberStatus EMMemberStatusFromString(NSString *memberStatusString) {
    if ([memberStatusString isEqual:@"a"] || [memberStatusString isEqual:@"active"])
        return EMMemberStatusActive;
    else if ([memberStatusString isEqual:@"e"] || [memberStatusString isEqual:@"error"])
        return EMMemberStatusError;
    else if ([memberStatusString isEqual:@"o"] || [memberStatusString isEqual:@"opt-out"])
        return EMMemberStatusOptout;
    else if ([memberStatusString isEqual:@"f"] || [memberStatusString isEqual:@"forwarded"])
        return EMMemberStatusForwarded;
    else
        return EMMemberStatusAll;
}

@implementation EMMember

- (id)initWithDictionary:(NSDictionary *)dict accountFields:(NSArray *)accountFields {
    if ((self = [super init])) {
        _ID = [[[dict objectForKey:@"member_id"] numberOrNil] objectIDStringValue];
        _email = [[dict objectForKey:@"email"] stringOrNil];
        
        // i guess if the email is invalid it will appear in this other field. that's retarded but whatever.
        if (!_email)
            _email = [[dict objectForKey:@"email_error"] stringOrNil];
        
        _memberSince = [[[dict objectForKey:@"member_since"] stringOrNil] em_parseTimestamp];
        
        NSString *memberStatusString;
        
        if ([dict.allKeys containsObject:@"member_status_id"])
            memberStatusString = [dict objectForKey:@"member_status_id"];
        else if ([dict.allKeys containsObject:@"status"])
            memberStatusString = [dict objectForKey:@"status"];
        else
            memberStatusString = nil;
        
        _status = EMMemberStatusFromString(memberStatusString);
        _fields = dict[@"fields"];
    }
    return self;
}

@end
