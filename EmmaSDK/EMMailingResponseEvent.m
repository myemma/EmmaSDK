#import "EMMailingResponseEvent.h"
#import "NSObject+ObjectOrNil.h"
#import "NSString+DateParsing.h"

@implementation EMMailingResponseEvent

- (id)initWithDictionary:(NSDictionary *)dict {
    if ((self = [super init])) {
        _timestamp = [[[dict objectForKey:@"timestamp"] stringOrNil] parseISO8601Timestamp];
        _linkID = [[[dict objectForKey:@"link_id"] numberOrNil] stringValue];
        _forwardMailingID = [[[dict objectForKey:@"forward_mailing_id"] numberOrNil] stringValue];
        _member = [[EMMember alloc] initWithDictionary:dict];
    }
    return self;
}

@end
