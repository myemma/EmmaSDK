#import "EMMailing.h"
#import "NSObject+ObjectOrNil.h"
#import "NSNumber+ObjectIDString.h"
#import "NSString+DateParsing.h"

@implementation EMMailing

EMMailingStatus MailingStatusFromString(NSString *s) {
    if ([s isEqual:@"p"])
        return EMMailingStatusPending;
    if ([s isEqual:@"a"])
        return EMMailingStatusPaused;
    if ([s isEqual:@"s"])
        return EMMailingStatusSending;
    if ([s isEqual:@"x"])
        return EMMailingStatusCanceled;
    if ([s isEqual:@"c"])
        return EMMailingStatusComplete;
    if ([s isEqual:@"f"])
        return EMMailingStatusFailed;
    
    return EMMailingStatusAll;
}

- (id)initWithDictionary:(NSDictionary *)dict {
    if ((self = [super init])) {
        _ID = [[[dict objectForKey:@"mailing_id"] numberOrNil] objectIDStringValue];
        _recipientCount = [[[dict objectForKey:@"recipient_count"] numberOrNil] intValue];
        _name = [[[dict objectForKey:@"name"] stringOrNil] copy];
        _subject = [[[dict objectForKey:@"subject"] stringOrNil] copy];
        _sender = [[[dict objectForKey:@"sender"] stringOrNil] copy];
        _sendStarted = [[[dict objectForKey:@"send_started"] stringOrNil] parseISO8601Timestamp];
        _status = MailingStatusFromString([[dict objectForKey:@"mailing_status"] stringOrNil]);
        
        NSString *publicWebViewURLString = [[[dict objectForKey:@"public_webview_url"] stringOrNil] stringByReplacingOccurrencesOfString:@"https:" withString:@"http:"];
        
        if (publicWebViewURLString)
            _publicWebViewURL = [NSURL URLWithString:publicWebViewURLString];
    }
    return self;
}

@end
