#import "EMMember.h"
#import "NSNumber+ObjectIDString.h"

@implementation EMMember

- (id)initWithDictionary:(NSDictionary *)dict {
    if (self = [super init]) {
        _ID = [dict[@"member_id"] objectIDStringValue];
        _email = dict[@"email"];
    }
    return self;
}

@end
