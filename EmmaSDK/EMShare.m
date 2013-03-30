#import "EMShare.h"
#import "NSObject+ObjectOrNil.h"
#import "NSString+DateParsing.h"
#import "NSNumber+ObjectIDString.h"

@implementation EMShareSummary

- (id)initWithDictionary:(NSDictionary *)dict {
    if ((self = [super init])) {
        _network = [[dict objectForKey:@"network"] stringOrNil];
        _shareClicks = [[dict objectForKey:@"share_clicks"] intValue];
        _shareCount = [[dict objectForKey:@"share_count"] intValue];
    }
    return self;
}

@end

@implementation EMShare

- (id)initWithDictionary:(NSDictionary *)dict {
    if ((self = [super init])) {
        _timestamp = [[[dict objectForKey:@"delivery_ts"] stringOrNil] parseISO8601Timestamp];
        _network = [[dict objectForKey:@"network"] stringOrNil];
        _memberID = [[[dict objectForKey:@"member_id"] numberOrNil] objectIDStringValue];
        _shareStatus = [[dict objectForKey:@"share_status"] stringOrNil];
        _clicks = [[[dict objectForKey:@"clicks"] numberOrNil] intValue];
    }
    return self;
}

@end
