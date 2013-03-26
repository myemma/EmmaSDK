#import "EMMember.h"
#import "NSNumber+ObjectIDString.h"
#import "NSObject+ObjectOrNil.h"
#import "NSString+DateParsing.h"


NSString *EMMemberStatusGetName(EMMemberStatus status) {
    NSString *result = nil;
    
    switch (status) {
        case EMMemberStatusAll:
            result = @"All";
            break;
        case EMMemberStatusActive:
            result = @"Active";
            break;
        case EMMemberStatusError:
            result = @"Error";
            break;
        case EMMemberStatusOptout:
            result = @"Opt-out";
            break;
        case EMMemberStatusForwarded:
            result = @"Forwarded";
            break;
    }
    
    return result;
}

NSString *EMMemberStatusGetShortName(EMMemberStatus status) {
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


@implementation EMMember

//- (id)initWithDictionary:(NSDictionary *)dict accountFields:(NSArray *)accountFields {
- (id)initWithDictionary:(NSDictionary *)dict {
    if ((self = [super init])) {
        _ID = [[[dict objectForKey:@"member_id"] numberOrNil] objectIDStringValue];
        _email = [[dict objectForKey:@"email"] stringOrNil];
        
        // i guess if the email is invalid it will appear in this other field. that's retarded but whatever.
        if (!_email)
            _email = [[dict objectForKey:@"email_error"] stringOrNil];
        
//        _memberSince = [[[dict objectForKey:@"member_since"] stringOrNil] parseISO8601Timestamp];
        
        NSString *memberStatusString;
        
        if ([dict.allKeys containsObject:@"member_status_id"])
            memberStatusString = [dict objectForKey:@"member_status_id"];
        else if ([dict.allKeys containsObject:@"status"])
            memberStatusString = [dict objectForKey:@"status"];
        else
            memberStatusString = nil;
        
        if (memberStatusString) {
            if ([memberStatusString isEqual:@"a"] || [memberStatusString isEqual:@"active"])
                _status = EMMemberStatusActive;
            else if ([memberStatusString isEqual:@"e"] || [memberStatusString isEqual:@"error"])
                _status = EMMemberStatusError;
            else if ([memberStatusString isEqual:@"o"] || [memberStatusString isEqual:@"opt-out"])
                _status = EMMemberStatusOptout;
            else if ([memberStatusString isEqual:@"f"] || [memberStatusString isEqual:@"forwarded"])
                _status = EMMemberStatusForwarded;
            else
                NSLog(@"-[Member initWithDictionary:] Received unknown member status string '%@'", memberStatusString);
        }
        
        if ([[dict allKeys] containsObject:@"fields"]) {
//            NSDictionary *fieldsDict = [dict objectForKey:@"fields"];
//            self.memberFields = [EMMember memberFieldsForDictionary:fieldsDict accountFields:accountFields];
        }
    }
    return self;
}

//+ (NSArray *)memberFieldsForDictionary:(NSDictionary *)fieldsDict accountFields:(NSArray *)accountFields {
//    NSMutableArray *result = [NSMutableArray array];
//    
//    if (accountFields)
//    {
//        for (AccountField *accountField in accountFields)
//        {
//            id value = [fieldsDict objectForKey:accountField.name];
//            
//            value = [accountField coerceToModelValue:value];
//            
//            MemberField *memberField = [[[MemberField alloc] initWithFieldName:accountField.name value:value] autorelease];
//            
//            [result addObject:memberField];
//        }
//    }
//    else
//    {
//        // XXX HACK because accountFields is nil if we're not being used by the MemberController.
//        for (NSString *fieldName in [fieldsDict allKeys]) {
//            id value = [fieldsDict objectForKey:fieldName];
//            
//            // attempt to coerce to known field type if possible
//            if (accountFields) {
//                AccountField *field = [[accountFields filter:^ BOOL (id accountField) { return [((AccountField *)accountField).name isEqual:fieldName]; }] firstObject];
//                value = [field coerceToModelValue:value];
//            }
//            // if not possible, only allow NSString past.
//            else if (![value isKindOfClass:[NSString class]])
//                value = nil;
//            
//            MemberField *memberField = [[[MemberField alloc] initWithFieldName:fieldName value:value] autorelease];
//            
//            [result addObject:memberField];
//        }
//    }
//    
//    return [[result copy] autorelease];
//}


@end
