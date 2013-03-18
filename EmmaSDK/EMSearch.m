#import "EMSearch.h"
#import "NSObject+ObjectOrNil.h"
#import "NSNumber+ObjectIDString.h"

@implementation EMSearch

- (id)initWithDictionary:(NSDictionary *)dict {
    if ((self = [super init])) {
        _ID = [[[dict objectForKey:@"search_id"] numberOrNil] objectIDStringValue];
        _name = [dict objectForKey:@"name"];
        _activeCount = [[[dict objectForKey:@"active_count"] numberOrNil] intValue];
    }
    return self;
}

@end
