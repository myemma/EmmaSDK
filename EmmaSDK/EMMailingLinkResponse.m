#import "EMMailingLinkResponse.h"
#import "NSObject+ObjectOrNil.h"
#import "NSNumber+ObjectIDString.h"

@implementation EMMailingLinkResponse

- (id)initWithDictionary:(NSDictionary *)dictionary {
    if ((self = [super init])) {
        _ID = [[[dictionary objectForKey:@"link_id"] numberOrNil] objectIDStringValue];
        _name = [[[dictionary objectForKey:@"link_name"] stringOrNil] copy];
        _target = [NSURL URLWithString:[[dictionary objectForKey:@"link_target"] stringOrNil]];
        _clicks = [[[dictionary objectForKey:@"total_clicks"] numberOrNil] intValue];
        _uniqueClicks = [[[dictionary objectForKey:@"unique_clicks"] numberOrNil] intValue];
        _plaintext = [[[dictionary objectForKey:@"plaintext"] numberOrNil] boolValue];
        _linkOrder = [[[dictionary objectForKey:@"link_order"] numberOrNil] intValue];
    }
    return self;
}

@end
