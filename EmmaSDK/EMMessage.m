#import "EMMessage.h"
#import "NSObject+ObjectOrNil.h"
#import "NSNumber+ObjectIDString.h"
#import "NSString+EMDateParsing.h"

@implementation EMMessage

- (id)initWithDictionary:(NSDictionary *)dict {
    if ((self = [super init])) {
        _mailingID = [[[dict objectForKey:@"mailing_id"] numberOrNil] objectIDStringValue];
        _subject = [dict objectForKey:@"subject"];
        _name = [[dict objectForKey:@"name"] copy];
        _clicked = [[[dict objectForKey:@"clicked"] stringOrNil] em_parseTimestamp];
        _delivered = [[[dict objectForKey:@"delivery_ts"] stringOrNil] em_parseTimestamp];
        _opened = [[[dict objectForKey:@"opened"] stringOrNil] em_parseTimestamp];
        _shared = [[[dict objectForKey:@"shared"] stringOrNil] em_parseTimestamp];
        _forwarded = [[[dict objectForKey:@"forwarded"] stringOrNil] em_parseTimestamp];
        _plaintext = [[dict objectForKey:@"plaintext"] stringOrNil];
        _htmlBody = [[dict objectForKey:@"html_body"] stringOrNil];
        
        NSString *deliveryType = [dict objectForKey:@"delivery_type"];
        
        if ([deliveryType isEqual:@"d"])
            _type = EMMessageDeliveryTypeDelivered;
        else if ([deliveryType isEqual:@"b"])
            _type = EMMessageDeliveryTypeHardBounce;
        else if ([deliveryType isEqual:@"s"])
            _type = EMMessageDeliveryTypeSoftBounce;
        else
            NSLog(@"-[MemberMailing initWithDictionary]: unknown delivery type '%@'", deliveryType);
    }
    return self;
}


@end
