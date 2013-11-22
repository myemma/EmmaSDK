#import "EMOAuthAccount.h"
#import "NSObject+ObjectOrNil.h"
#import "NSNumber+ObjectIDString.h"

@implementation EMOAuthAccount

- (id)initWithDictionary:(NSDictionary *)dict {
    if ((self = [super init])) {
        _accountID = [[dict[@"account_id"] numberOrNil] objectIDStringValue];
    }
    return self;
}

- (NSDictionary *)dictionaryRepresentation
{
    return @{
    @"account_id" : ObjectOrNull(_accountID)
    };
}

@end
