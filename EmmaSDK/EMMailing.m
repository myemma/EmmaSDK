#import "EMMailing.h"
#import "NSObject+ObjectOrNil.h"
#import "NSNumber+ObjectIDString.h"
#import "NSString+DateParsing.h"

NSString *EMMailingStatusToString(EMMailingStatus status) {
    
    if (status == EMMailingStatusAll)
        return @"p,a,s,x,c,f";
    
    NSMutableArray *results = [NSMutableArray array];
    
    if ((status & EMMailingStatusPending) > 0)
        [results addObject:@"p"];
    
    if ((status & EMMailingStatusPaused) > 0)
        [results addObject:@"a"];
    
    if ((status & EMMailingStatusSending) > 0)
        [results addObject:@"s"];
    
    if ((status & EMMailingStatusCanceled) > 0)
        [results addObject:@"x"];
    
    if ((status & EMMailingStatusComplete) > 0)
        [results addObject:@"c"];
    
    if ((status & EMMailingStatusFailed) > 0)
        [results addObject:@"f"];
    
    return [results componentsJoinedByString:@","];
}

EMMailingStatus EMMailingStatusFromString(NSString *s) {
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

@implementation EMMailing

- (id)initWithDictionary:(NSDictionary *)dict {
    if ((self = [super init])) {
        _ID = [[[dict objectForKey:@"mailing_id"] numberOrNil] objectIDStringValue];
        _recipientCount = [[[dict objectForKey:@"recipient_count"] numberOrNil] intValue];
        _name = [[[dict objectForKey:@"name"] stringOrNil] copy];
        _subject = [[[dict objectForKey:@"subject"] stringOrNil] copy];
        _sender = [[[dict objectForKey:@"sender"] stringOrNil] copy];
        _sendStarted = [[[dict objectForKey:@"send_started"] stringOrNil] parseISO8601Timestamp];
        _status = EMMailingStatusFromString([[dict objectForKey:@"mailing_status"] stringOrNil]);
        
        NSString *publicWebViewURLString = [[[dict objectForKey:@"public_webview_url"] stringOrNil] stringByReplacingOccurrencesOfString:@"https:" withString:@"http:"];
        
        if (publicWebViewURLString)
            _publicWebViewURL = [NSURL URLWithString:publicWebViewURLString];
    }
    return self;
}

@end
