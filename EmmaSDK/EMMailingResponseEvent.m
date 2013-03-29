#import "EMMailingResponseEvent.h"
#import "NSObject+ObjectOrNil.h"
#import "NSString+DateParsing.h"

@implementation EMMailingResponseEvent

- (id)initWithDictionary:(NSDictionary *)dict {
    if ((self = [super init])) {
        _timestamp = [[[dict objectForKey:@"timestamp"] stringOrNil] parseISO8601Timestamp];
        _member = [[EMMember alloc] initWithDictionary:dict];
    }
    return self;
}

@end
