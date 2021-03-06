#import "EMShare.h"
#import "NSObject+ObjectOrNil.h"
#import "NSString+EMDateParsing.h"
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
        _timestamp = [[[dict objectForKey:@"timestamp"] stringOrNil] em_parseTimestamp];
        _network = [[dict objectForKey:@"network"] stringOrNil];
        _memberID = [[[dict objectForKey:@"member_id"] numberOrNil] objectIDStringValue];
        _shareStatus = [[dict objectForKey:@"share_status"] stringOrNil];
        _clicks = [[[dict objectForKey:@"clicks"] numberOrNil] intValue];
    }
    return self;
}

@end
