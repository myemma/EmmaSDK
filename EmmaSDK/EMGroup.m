#import "EMGroup.h"
#import "NSObject+ObjectOrNil.h"
#import "NSNumber+ObjectIDString.h"

NSString *EMGroupTypeToString(EMGroupType type) {
    if (type == EMGroupTypeAll)
        return @"all";
    
    NSArray *types = @[];
    
    if ((type & EMGroupTypeGroup) > 0)
        types = [types arrayByAddingObject:@"g"];
    
    if ((type & EMGroupTypeTest) > 0)
        types = [types arrayByAddingObject:@"t"];
    
    if ((type & EMGroupTypeHidden) > 0)
        types = [types arrayByAddingObject:@"h"];
    
    return [types componentsJoinedByString:@","];
}

@implementation EMGroup

@synthesize ID, name, activeCount, errorCount, optoutCount;

- (id)initWithDictionary:(NSDictionary *)dict {
    if ((self = [super init])) {
        ID = [[[dict objectForKey:@"member_group_id"] numberOrNil] objectIDStringValue];
        name = [[dict objectForKey:@"group_name"] stringOrNil];
        activeCount = [[dict objectForKey:@"active_count"] intValue];
        errorCount = [[dict objectForKey:@"error_count"] intValue];
        optoutCount = [[dict objectForKey:@"optout_count"] intValue];
    }
    return self;
}

@end
