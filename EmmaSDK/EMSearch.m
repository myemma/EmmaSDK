#import "EMSearch.h"
#import "NSObject+ObjectOrNil.h"
#import "NSNumber+ObjectIDString.h"
#import "NSString+DateParsing.h"

@implementation EMSearch

- (id)initWithDictionary:(NSDictionary *)dict {
    if ((self = [super init])) {
        _ID = [[[dict objectForKey:@"search_id"] numberOrNil] objectIDStringValue];
        _name = [dict objectForKey:@"name"];
        _criteria = [dict objectForKey:@"criteria"];
        _activeCount = [[[dict objectForKey:@"active_count"] numberOrNil] intValue];
        _optoutCount = [[[dict objectForKey:@"optout_count"] numberOrNil] intValue];
        _errorCount = [[[dict objectForKey:@"error_count"] numberOrNil] intValue];
        _lastRunAt = [[[dict objectForKey:@"last_run_at"] stringOrNil] em_parseTimestamp];
        _deletedAt = [[[dict objectForKey:@"last_run_at"] stringOrNil] em_parseTimestamp];
    }
    return self;
}

- (NSDictionary *)dictionaryRepresentation
{
    return @{
    @"name" : ObjectOrNull(_name),
    @"criteria" : ObjectOrNull(_criteria),
    };
}

@end
