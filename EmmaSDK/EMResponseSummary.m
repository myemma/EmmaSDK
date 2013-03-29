#import "EMResponseSummary.h"
#import "NSObject+ObjectOrNil.h"

@implementation EMResponseSummary

- (id)initWithDictionary:(NSDictionary *)dict {
    if ((self = [super init])) {
        _sent = [[[dict objectForKey:@"sent"] numberOrNil] intValue];
        _delivered = [[[dict objectForKey:@"delivered"] numberOrNil] intValue];
        _bounced = [[[dict objectForKey:@"bounced"] numberOrNil] intValue];
        _opened = [[[dict objectForKey:@"opened"] numberOrNil] intValue];
        _clickedUnique = [[[dict objectForKey:@"clicked_unique"] numberOrNil] intValue];
        _clicked = [[[dict objectForKey:@"clicked"] numberOrNil] intValue];
        _forwarded = [[[dict objectForKey:@"forwarded"] numberOrNil] intValue];
        _optedOut = [[[dict objectForKey:@"opted_out"] numberOrNil] intValue];
        _signedUp = [[[dict objectForKey:@"signed_up"] numberOrNil] intValue];
        _shared = [[[dict objectForKey:@"shared"] numberOrNil] intValue];
        _shareClicked = [[[dict objectForKey:@"share_clicked"] numberOrNil] intValue];
        _month = [[[dict objectForKey:@"month"] numberOrNil] intValue];
        _year = [[[dict objectForKey:@"year"] numberOrNil] intValue];
        _mailings = [[[dict objectForKey:@"mailings"] numberOrNil] intValue];
        
//        sendOff = [[NSArray arrayWithObjects:
//                    [MailingResponseStat statWithTitle:@"delivered" value:delivered type:ResponseEventDelivery],
//                    [MailingResponseStat statWithTitle:@"bounced" value:bounced type:ResponseEventBounce],
//                    nil] retain];
//        
//        response = [[NSArray arrayWithObjects:
//                     [MailingResponseStat statWithTitle:@"opened" value:opened type:ResponseEventOpen],
//                     [MailingResponseStat statWithTitle:@"clicked" value:clicked type:ResponseEventClick],
//                     [MailingResponseStat statWithTitle:@"forwarded" value:forwarded type:ResponseEventForward],
//                     [MailingResponseStat statWithTitle:@"shared" value:shared type:ResponseEventShare],
//                     [MailingResponseStat statWithTitle:@"signed up" value:signedUp type:ResponseEventSignup],
//                     [MailingResponseStat statWithTitle:@"opted out" value:optedOut type:ResponseEventOptout],
//                     nil] retain];
    }
    return self;
}

@end
