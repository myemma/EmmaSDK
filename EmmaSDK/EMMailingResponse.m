#import "EMMailingResponse.h"
#import "NSObject+ObjectOrNil.h"

@implementation EMMailingResponse

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

#warning how do we test these?
        _sendOff = [NSArray arrayWithObjects:
                    [EMMailingResponseStat statWithTitle:@"delivered" value:_delivered type:EMResponseEventDelivery],
                    [EMMailingResponseStat statWithTitle:@"bounced" value:_bounced type:EMResponseEventBounce],
                    nil];
        
        _response = [NSArray arrayWithObjects:
                     [EMMailingResponseStat statWithTitle:@"opened" value:_opened type:EMResponseEventOpen],
                     [EMMailingResponseStat statWithTitle:@"clicked" value:_clicked type:EMResponseEventClick],
                     [EMMailingResponseStat statWithTitle:@"forwarded" value:_forwarded type:EMResponseEventForward],
                     [EMMailingResponseStat statWithTitle:@"shared" value:_shared type:EMResponseEventShare],
                     [EMMailingResponseStat statWithTitle:@"signed up" value:_signedUp type:EMResponseEventSignup],
                     [EMMailingResponseStat statWithTitle:@"opted out" value:_optedOut type:EMResponseEventOptout],
                     nil];
    }
    return self;
}

@end

@implementation EMMailingResponseStat

+ (EMMailingResponseStat *)statWithTitle:(NSString *)title value:(NSUInteger)value type:(EMResponseEventType)type {
    EMMailingResponseStat *result = [[EMMailingResponseStat alloc] init];
    result.title = title;
    result.value = value;
    result.type = type;
    return result;
}

@end
