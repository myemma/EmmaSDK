#import "EMClient+Private.h"
#import <SBJson/SBJson.h>

#define API_HOST @"http://api.e2ma.net"
#define API_BASE_PATH @"/1"

NSString *EMGroupTypeGetString(EMGroupType type) {
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

@interface NSDictionary (QueryString)

- (NSString *)queryString;

@end

@implementation NSDictionary (QueryString)

- (NSString *)queryString {
    NSArray *keys = [[self allKeys] sortedArrayUsingComparator:^NSComparisonResult(id obj1, id obj2) {
        return [obj1 compare:obj2];
    }];
    return [[keys.rac_sequence map:^id(id value) {
        return [NSString stringWithFormat:@"%@=%@", value, [self[value] stringByAddingPercentEscapesUsingEncoding:NSUTF8StringEncoding]];
    }].array componentsJoinedByString:@"&"];
}

- (NSDictionary *)dictionaryByAddingCountParam {
    NSMutableDictionary *dict = [self mutableCopy];
    dict[@"count"] = @"true";
    return [dict copy];
}

- (NSDictionary *)dictionaryByAddingRangeParams:(EMResultRange)range {
    NSMutableDictionary *dict = [self mutableCopy];
    dict[@"start"] = [NSString stringWithFormat:@"%d", range.start];
    dict[@"end"] = [NSString stringWithFormat:@"%d", range.end];
    return [dict copy];
}

- (NSDictionary *)dictionaryByMergingDictionary:(NSDictionary *)dictionary {
    NSMutableDictionary *dict = [self mutableCopy];
    
    for (id k in [dictionary allKeys])
        dict[k] = dictionary[k];
    
    return [dict copy];
}

@end

@interface NSString (QueryString)

- (NSString *)stringByAppendingQueryString:(NSDictionary *)params;

@end

@implementation NSString (QueryString)

- (NSString *)stringByAppendingQueryString:(NSDictionary *)params {
    NSString *queryString = [params queryString];
    
    if (queryString.length)
        return [self stringByAppendingFormat:@"?%@", queryString];
    
    return self;
}

@end

@implementation NSObject (JSONDataRepresentation)

- (NSData *)JSONDataRepresentation {
    SBJsonWriter *writer = [[SBJsonWriter alloc] init];
    NSData *json = [writer dataWithObject:self];
    if (!json)
        NSLog(@"-JSONRepresentation failed. Error is: %@", writer.error);
    return json;
}

- (id)objectOrNil {
    return [self isEqual:[NSNull null]] ? nil : self;
}

@end


@interface EMEndpoint : NSObject <EMEndpoint>

@end

@implementation EMEndpoint

- (RACSignal *)requestSignalWithURLRequest:(NSURLRequest *)request {
    return nil;
}

@end

@interface EMClient ()

@property (nonatomic, strong) id<EMEndpoint> endpoint;

@end

static EMClient *shared;

@implementation EMClient

@synthesize endpoint;

+ (void)initialize {
    shared = [[EMClient alloc] initWithEndpoint:[[EMEndpoint alloc] init]];
}

+ (EMClient *)shared {
    return shared;
}

- (id)initWithEndpoint:(id<EMEndpoint>)lEndpoint {
    if (self = [super init]) {
        endpoint = lEndpoint;
    }
    return self;
}

- (NSURLRequest *)requestWithMethod:(NSString *)method path:(NSString *)path headers:(NSDictionary *)headers body:(id)body {
    assert(method);
    assert(path);
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@%@", API_HOST, API_BASE_PATH, path]];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:6];
    urlRequest.HTTPMethod = method;
    urlRequest.AllHTTPHeaderFields = headers;
    
    if ([body isKindOfClass:[NSInputStream class]]) {
        urlRequest.HTTPBodyStream = (NSInputStream *)body;
    }
    else if (body) {
        urlRequest.HTTPBody = [body JSONDataRepresentation];
        [urlRequest setValue:@"application/json" forHTTPHeaderField:@"Content-Type"];
    }
    
    return urlRequest;
}

- (RACSignal *)requestSignalWithMethod:(NSString *)method path:(NSString *)path headers:(NSDictionary *)headers body:(id)body {
    return [endpoint requestSignalWithURLRequest:[self requestWithMethod:method path:path headers:headers body:body]];
}

- (RACSignal *)createGroupsWithNames:(NSArray *)names {
    id body = @{
        @"groups": [names.rac_sequence map:^id(id value) {
            return @{ @"group_name": value };
        }].array
    };
    
    return [[self requestSignalWithMethod:@"POST" path:@"/groups" headers:nil body:body] map:^id(NSArray * results) {
        return [results.rac_sequence map:^id(id value) {
            return [[EMGroup alloc] initWithDictionary:value];
        }].array;
    }];
}

- (RACSignal *)getGroupCountWithType:(EMGroupType)groupType {
    id query = [@{@"group_types": EMGroupTypeGetString(groupType)} dictionaryByAddingCountParam];
    
    return [self requestSignalWithMethod:@"GET" path:[@"/groups" stringByAppendingQueryString:query] headers:nil body:nil];
}

- (RACSignal *)getGroupsWithType:(EMGroupType)groupType inRange:(EMResultRange)range {
    id query = [@{@"group_types": EMGroupTypeGetString(groupType)} dictionaryByAddingRangeParams:range];
    
    return [[self requestSignalWithMethod:@"GET" path:[@"/groups" stringByAppendingQueryString:query] headers:nil body:nil] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(id value) {
            return [[EMGroup alloc] initWithDictionary:value];
        }].array;
    }];
}

- (RACSignal *)updateGroup:(EMGroup *)group {
    return [self requestSignalWithMethod:@"PUT" path:[NSString stringWithFormat:@"/groups/%@", group.ID] headers:nil body:@{ @"group_name": group.name }];
}

- (RACSignal *)getMembersInGroupID:(NSString *)groupID inRange:(EMResultRange)range includeDeleted:(BOOL)includeDeleted {
    id query = [@{@"deleted": includeDeleted ? @"true" : @"false" } dictionaryByAddingRangeParams:range];
    return [[self requestSignalWithMethod:@"GET" path:[[NSString stringWithFormat:@"/groups/%@/members", groupID] stringByAppendingQueryString:query] headers:nil body:nil] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(id value) {
            return [[EMMember alloc] initWithDictionary:value];
        }].array;
    }];
}

- (RACSignal *)deleteGroupID:(NSString *)groupID {
    return [self requestSignalWithMethod:@"DELETE" path:[NSString stringWithFormat:@"/groups/%@", groupID] headers:nil body:nil];
}

@end