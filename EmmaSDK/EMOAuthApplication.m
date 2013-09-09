#import "EMOAuthApplication.h"
#import "NSObject+ObjectOrNil.h"
#import "NSNumber+ObjectIDString.h"

@implementation EMOAuthApplication

- (id)initWithDictionary:(NSDictionary *)dict {
    if ((self = [super init])) {
        _accounts = [self objectAccountArrayFromStringArray:dict[@"accounts"]];
    }
    return self;
}

- (NSArray *)objectAccountArrayFromStringArray:(NSArray *)results {
    return [[results arrayOrNil].rac_sequence map:^id(id value) {
        return [[EMOAuthAccount alloc] initWithDictionary:value];
    }].array;    
}

@end
