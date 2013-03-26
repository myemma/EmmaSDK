#import "EMClient+Private.h"
#import <SBJson/SBJson.h>

#define API_HOST @"http://api.e2ma.net"
#define API_BASE_PATH @"/1"

NSString *EMMailingStatusToString(EMMailingStatus status) {
    
    if (status == EMMailingStatusAll)
        return @"p,a,s,x,c,f";
    
    NSMutableArray *results = [NSMutableArray array];
    
    if ((status & EMMailingStatusPending) > 0)
        [results addObject:@"p"];
    
    if ((status & EMMailingStatusPaused) > 0)
        [results addObject:@"a"];
    
    if ((status & EMMailingStatusSending) > 0)
        [results addObject:@"s"];
    
    if ((status & EMMailingStatusCanceled) > 0)
        [results addObject:@"x"];
    
    if ((status & EMMailingStatusComplete) > 0)
        [results addObject:@"c"];
    
    if ((status & EMMailingStatusFailed) > 0)
        [results addObject:@"f"];
    
    return [results componentsJoinedByString:@","];
    
}

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

//groups

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

- (RACSignal *)getGroupID:(NSString *)groupID
{
    return [[self requestSignalWithMethod:@"GET" path:[NSString stringWithFormat:@"/groups/%@", groupID] headers:nil body:nil] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(id value) {
            return [[EMGroup alloc] initWithDictionary:value];
        }].array;
    }];
}

- (RACSignal *)updateGroup:(EMGroup *)group {
    return [self requestSignalWithMethod:@"PUT" path:[NSString stringWithFormat:@"/groups/%@", group.ID] headers:nil body:@{ @"group_name": group.name }];
}

- (RACSignal *)deleteGroupID:(NSString *)groupID {
    return [self requestSignalWithMethod:@"DELETE" path:[NSString stringWithFormat:@"/groups/%@", groupID] headers:nil body:nil];
}

- (RACSignal *)getMembersInGroupID:(NSString *)groupID inRange:(EMResultRange)range includeDeleted:(BOOL)includeDeleted {
    id query = [@{@"deleted": includeDeleted ? @"true" : @"false" } dictionaryByAddingRangeParams:range];
    return [[self requestSignalWithMethod:@"GET" path:[[NSString stringWithFormat:@"/groups/%@/members", groupID] stringByAppendingQueryString:query] headers:nil body:nil] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(id value) {
            return [[EMMember alloc] initWithDictionary:value];
        }].array;
    }];
}

- (RACSignal *)addMemberIDs:(NSArray *)memberIDs toGroupID:(NSString *)groupID {
    return [self requestSignalWithMethod:@"PUT" path:[NSString stringWithFormat:@"/groups/%@/members", groupID] headers:nil body:@{ @"member_ids": memberIDs }];
}

- (RACSignal *)removeMemberIDs:(NSArray *)memberIDs fromGroupID:(NSString *)groupID {
        return [self requestSignalWithMethod:@"PUT" path:[NSString stringWithFormat:@"/groups/%@/members/remove", groupID] headers:nil body:@{ @"member_ids": memberIDs }];
}

- (RACSignal *)removeMembersWithStatus:(EMMemberStatus)status fromGroupID:(NSString *)groupID
{
    return nil;
}

//PUT /#account_id/groups/#from_group_id/#to_group_id/members/copy

- (RACSignal *)copyMembersWithStatus:(EMMemberStatus)status fromGroupID:(NSString *)fromGroupID toGroupID:(NSString *)toGroupID
{
    return [self requestSignalWithMethod:@"PUT" path:[NSString stringWithFormat:@"/groups/%@/%@/members/copy", fromGroupID, toGroupID] headers:nil body:@{ @"member_status_id": @[EMMemberStatusGetShortName(status)] }];
    return nil;
}

//mailings

- (RACSignal *)getMailingCountWithStatuses:(EMMailingStatus)statuses
{
    id query = @{@"mailing_statuses" : EMMailingStatusToString(statuses)};
    
    return [self requestSignalWithMethod:@"GET" path:[@"/mailings" stringByAppendingQueryString:query] headers:nil body:nil];
}

- (RACSignal *)getMailingsWithStatuses:(EMMailingStatus)statuses inRange:(EMResultRange)range
{
    id query = [@{@"mailing_statuses" : EMMailingStatusToString(statuses)} dictionaryByAddingRangeParams:range];
    
    return [[self requestSignalWithMethod:@"GET" path:[@"/mailings" stringByAppendingQueryString:query] headers:nil body:nil] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(id value) {
            return [[EMMailing alloc] initWithDictionary:value];
        }].array;
    }];
}

- (RACSignal *)getMailingWithID:(NSString *)mailingID
{
    return [[self requestSignalWithMethod:@"GET" path:[NSString stringWithFormat:@"/mailings/%@", mailingID] headers:nil body:nil] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(id value) {
            return [[EMMailing alloc] initWithDictionary:value];
        }].array;
    }];
}

- (RACSignal *)getMembersCountForMailingID:(NSString *)mailingID
{
    return [self requestSignalWithMethod:@"GET" path:[NSString stringWithFormat:@"/mailings/%@/members", mailingID] headers:nil body:nil];
}

- (RACSignal *)getMembersForMailingID:(NSString *)mailingID inRange:(EMResultRange)range
{
    id query = [@{} dictionaryByAddingRangeParams:range];
        
    return [[self requestSignalWithMethod:@"GET" path:[[NSString stringWithFormat:@"/mailings/%@/members", mailingID] stringByAppendingQueryString:query] headers:nil body:nil] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(id value) {
            return [[EMMember alloc] initWithDictionary:value];
        }].array;
    }];
}

- (RACSignal *)getMessageToMemberID:(NSString *)memberID forMailingID:(NSString *)mailingID
{
    return [[self requestSignalWithMethod:@"GET" path:[NSString stringWithFormat:@"/mailings/%@/messages/%@", mailingID, memberID] headers:nil body:nil] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(id value) {
            return [[EMMessage alloc] initWithDictionary:value];
        }].array;
    }];
}

- (RACSignal *)getGroupCountForMailingID:(NSString *)mailingID
{
    return [self requestSignalWithMethod:@"GET" path:[NSString stringWithFormat:@"/mailings/%@/groups", mailingID] headers:nil body:nil];
}

- (RACSignal *)getGroupsForMailingID:(NSString *)mailingID inRange:(EMResultRange)range
{
    id query = [@{} dictionaryByAddingRangeParams:range];
    
    return [[self requestSignalWithMethod:@"GET" path:[[NSString stringWithFormat:@"/mailings/%@/groups", mailingID] stringByAppendingQueryString:query] headers:nil body:nil] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(id value) {
            return [[EMGroup alloc] initWithDictionary:value];
        }].array;
    }];
    return nil;
}

- (RACSignal *)getSearchCountForMailingID:(NSString *)mailingID
{
    return [self requestSignalWithMethod:@"GET" path:[NSString stringWithFormat:@"/mailings/%@/searches", mailingID] headers:nil body:nil];
}

- (RACSignal *)getSearchesForMailingID:(NSString *)mailingID inRange:(EMResultRange)range
{
    id query = [@{} dictionaryByAddingRangeParams:range];
    
    return [[self requestSignalWithMethod:@"GET" path:[[NSString stringWithFormat:@"/mailings/%@/searches", mailingID] stringByAppendingQueryString:query] headers:nil body:nil] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(id value) {
            return [[EMSearch alloc] initWithDictionary:value];
        }].array;
    }];
    return nil;
}

- (RACSignal *)updateMailingID:(NSString *)mailingID withStatus:(EMMailingStatus)status
{
    return [self requestSignalWithMethod:@"PUT" path:[NSString stringWithFormat:@"/mailings/%@", mailingID] headers:nil body:@{ @"mailing_status": EMMailingStatusToString(status) }];
}

- (RACSignal *)archiveMailingID:(NSString *)mailingID
{
    return [self requestSignalWithMethod:@"DELETE" path:[NSString stringWithFormat:@"/mailings/%@", mailingID] headers:nil body:nil];
}

- (RACSignal *)cancelMailingID:(NSString *)mailingID
{
    return [self requestSignalWithMethod:@"DELETE" path:[NSString stringWithFormat:@"/mailings/cancel/%@", mailingID] headers:nil body:nil];
}

- (RACSignal *)forwardMailingID:(NSString *)mailingID fromMemberID:(NSString *)memberID toRecipients:(NSArray *)recipients withNote:(NSString *)note
{
    return [self requestSignalWithMethod:@"POST" path:[NSString stringWithFormat:@"/forwards/%@/%@", mailingID, memberID] headers:nil body:@{@"recipient_emails" : recipients, @"note" : note}];
}

- (RACSignal *)resendMailingID:(NSString *)mailingID headsUpAddresses:(NSArray *)headsUpAddresses recipientAddresses:(NSArray *)recipientAddresses recipientGroupIDs:(NSArray *)recipientGroupIDs recipientSearchIDs:(NSArray *)recipientSearchIDs
{
    return nil;
}

- (RACSignal *)getHeadsupAddressesForMailingID:(NSString *)mailingID
{    
    return [self requestSignalWithMethod:@"GET" path:[NSString stringWithFormat:@"/mailings/%@/headsup", mailingID] headers:nil body:nil];
}

- (RACSignal *)validateMailingWithBody:(NSString *)htmlBody plaintext:(NSString *)plaintext andSubject:(NSString *)subject
{
    return [self requestSignalWithMethod:@"POST" path:@"/mailings/validate" headers:nil body:@{@"html_body" : htmlBody, @"plaintext" : plaintext, @"subject" : subject}];
}

- (RACSignal *)declareWinnerID:(NSString *)winner forMailingID:(NSString *)mailingID
{
    return [self requestSignalWithMethod:@"POST" path:[NSString stringWithFormat:@"/mailings/%@/winner/%@", mailingID, winner] headers:nil body:nil];
}

// members

- (RACSignal *)getMemberCountIncludeDeleted:(BOOL)deleted
{
    id query = @{@"deleted": deleted ? @"true" : @"false" };
    
    return [self requestSignalWithMethod:@"GET" path:[@"/members" stringByAppendingQueryString:query] headers:nil body:nil];
}

- (RACSignal *)getMembersInRange:(EMResultRange)range includeDeleted:(BOOL)deleted
{
    id query = [@{@"deleted": deleted ? @"true" : @"false" } dictionaryByAddingRangeParams:range];

    return [[self requestSignalWithMethod:@"GET" path:[@"/members" stringByAppendingQueryString:query] headers:nil body:nil] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(id value) {
            return [[EMMember alloc] initWithDictionary:value];
        }].array;
    }];
}


@end