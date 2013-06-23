#import <SBJson/SBJson.h>
#import "NSData+Base64.h"
#import "NSObject+ObjectOrNil.h"
#import "NSNumber+ObjectIDString.h"
#import "EMResponseSummary.h"
#import "SMWebRequest+RAC.h"

#define API_HOST @"https://api.e2ma.net/"

EMResultRange EMResultRangeMake(NSInteger start, NSInteger end) {
    return (EMResultRange){ .start = start, .end = end };
}

EMResultRange EMResultRangeAll = ((EMResultRange){ .start = -1, .end = -1 });

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
    if (range.start == EMResultRangeAll.start && range.end == EMResultRangeAll.end)
        return self;

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
    return [SMWebRequest requestSignalWithURLRequest:request dataParser:^id(NSData *data) {
        SBJsonParser *parser = [[SBJsonParser alloc] init];
        id object = [parser objectWithData:data];
        if (!object)
            NSLog(@"Error parsing JSON from Emma: %@", parser.error);
        return object;
    }];
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
    
    if ([method isEqual:@"GET"])
        assert(body == nil);
    
    NSURL *url = [NSURL URLWithString:[NSString stringWithFormat:@"%@%@%@", API_HOST, _accountID, path]];
    NSMutableURLRequest *urlRequest = [NSMutableURLRequest requestWithURL:url cachePolicy:NSURLRequestUseProtocolCachePolicy timeoutInterval:6];
    urlRequest.HTTPMethod = method;
    urlRequest.AllHTTPHeaderFields = headers;
    
    // check to see if oauth is set, if so make oauth request, else make basic auth request
    if (_oauthToken != nil) {
        [urlRequest setValue:[@"Bearer " stringByAppendingString:[NSString stringWithFormat:@"%@", _oauthToken]] forHTTPHeaderField:@"Authorization"];
    }
    else {
        [urlRequest setValue:[@"Basic " stringByAppendingString:[[[NSString stringWithFormat:@"%@:%@", _publicKey, _privateKey] dataUsingEncoding:NSUTF8StringEncoding] base64EncodedString]] forHTTPHeaderField:@"Authorization"];
    }
        
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

// fields

- (RACSignal *)getFieldCount
{
    return [[self requestSignalWithMethod:@"GET" path:@"/fields" headers:nil body:nil] map:^id(NSNumber *value) {
        return [value numberOrNil];
    }];
}

- (RACSignal *)getFieldsInRange:(EMResultRange)range
{
    id query = [@{} dictionaryByAddingRangeParams:range];
    
    return [[self requestSignalWithMethod:@"GET" path:[@"/fields" stringByAppendingQueryString:query] headers:nil body:nil] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(id value) {
            return [[EMField alloc] initWithDictionary:value];
        }].array;
    }];
}

- (RACSignal *)getFieldID:(NSString *)fieldID
{
    return [[self requestSignalWithMethod:@"GET" path:[NSString stringWithFormat:@"/fields/%@", fieldID] headers:nil body:nil] map:^id(NSDictionary *value) {
        return [[EMField alloc] initWithDictionary:value];
    }];
}

- (RACSignal *)createField:(EMField *)field
{
    return [[self requestSignalWithMethod:@"POST" path:@"/fields" headers:nil body:field.dictionaryRepresentation] map:^id(NSNumber* result) {
        return [[result numberOrNil] objectIDStringValue];
    }];
}

- (RACSignal *)deleteFieldID:(NSString *)fieldID
{
    return [self requestSignalWithMethod:@"DELETE" path:[NSString stringWithFormat:@"/fields/%@", fieldID] headers:nil body:nil];
}

- (RACSignal *)clearFieldID:(NSString *)fieldID
{
    return [self requestSignalWithMethod:@"POST" path:[NSString stringWithFormat:@"/fields/%@/clear", fieldID] headers:nil body:nil];
}

- (RACSignal *)updateField:(EMField *)field
{
    return [[self requestSignalWithMethod:@"PUT" path:[NSString stringWithFormat:@"/fields/%@", field.fieldID] headers:nil body:field.dictionaryRepresentation] map:^id(NSNumber* result) {
        return [[result numberOrNil] objectIDStringValue];
    }];
}

//groups

- (RACSignal *)getGroupCountWithType:(EMGroupType)groupType {
    id query = [@{@"group_types": EMGroupTypeToString(groupType)} dictionaryByAddingCountParam];
    
    return [[self requestSignalWithMethod:@"GET" path:[@"/groups" stringByAppendingQueryString:query] headers:nil body:nil] map:^id(NSNumber *value) {
        return [value numberOrNil];
    }];
}

- (RACSignal *)getGroupsWithType:(EMGroupType)groupType inRange:(EMResultRange)range {
    id query = [@{@"group_types": EMGroupTypeToString(groupType)} dictionaryByAddingRangeParams:range];
    
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
    return [[self requestSignalWithMethod:@"GET" path:[NSString stringWithFormat:@"/groups/%@", groupID] headers:nil body:nil] map:^id(NSDictionary *value) {
        return [[EMGroup alloc] initWithDictionary:value];
    }];
}

- (RACSignal *)updateGroup:(EMGroup *)group {
    return [self requestSignalWithMethod:@"PUT" path:[NSString stringWithFormat:@"/groups/%@", group.ID] headers:nil body:@{ @"group_name": group.name }];
}

- (RACSignal *)deleteGroupID:(NSString *)groupID {
    return [self requestSignalWithMethod:@"DELETE" path:[NSString stringWithFormat:@"/groups/%@", groupID] headers:nil body:nil];
}

- (RACSignal *)getMemberCountInGroupID:(NSString *)groupID includeDeleted:(BOOL)deleted
{
    id query = @{@"deleted": deleted ? @"true" : @"false" };
    
    return [[self requestSignalWithMethod:@"GET" path:[[NSString stringWithFormat:@"/groups/%@/members", groupID] stringByAppendingQueryString:query] headers:nil body:nil] map:^id(NSNumber *value) {
        return [value numberOrNil];
    }];
}

- (RACSignal *)getMembersInGroupID:(NSString *)groupID inRange:(EMResultRange)range includeDeleted:(BOOL)includeDeleted {
    id query = [@{@"deleted": includeDeleted ? @"true" : @"false" } dictionaryByAddingRangeParams:range];
    return [[self requestSignalWithMethod:@"GET" path:[[NSString stringWithFormat:@"/groups/%@/members", groupID] stringByAppendingQueryString:query] headers:nil body:nil] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(id value) {
            return [[EMMember alloc] initWithDictionary:value accountFields:nil];
        }].array;
    }];
}

- (RACSignal *)addMemberIDs:(NSArray *)memberIDs toGroupID:(NSString *)groupID {
    return [[self requestSignalWithMethod:@"PUT" path:[NSString stringWithFormat:@"/groups/%@/members", groupID] headers:nil body:@{ @"member_ids": memberIDs } ] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(id value) {
            return [[value numberOrNil] objectIDStringValue];
        }].array;
    }];
;
}

- (RACSignal *)removeMemberIDs:(NSArray *)memberIDs fromGroupID:(NSString *)groupID {
    return [[self requestSignalWithMethod:@"PUT" path:[NSString stringWithFormat:@"/groups/%@/members/remove", groupID] headers:nil body:@{ @"member_ids": memberIDs }]  map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(id value) {
            return [[value numberOrNil] objectIDStringValue];
        }].array;
    }];
}

- (RACSignal *)removeMembersWithStatus:(EMMemberStatus)status fromGroupID:(NSString *)groupID
{
    id query = @{@"member_status_id": EMMemberStatusToString(status)};

    NSString *pathString = [[NSString stringWithFormat:@"/groups/%@/members/remove", groupID] stringByAppendingQueryString:query];
    
    return [self requestSignalWithMethod:@"DELETE" path:pathString headers:nil body:nil];
}

- (RACSignal *)copyMembersWithStatus:(EMMemberStatus)status fromGroupID:(NSString *)fromGroupID toGroupID:(NSString *)toGroupID
{
    return [self requestSignalWithMethod:@"PUT" path:[NSString stringWithFormat:@"/groups/%@/%@/members/copy", fromGroupID, toGroupID] headers:nil body:@{ @"member_status_id": @[EMMemberStatusToString(status)] }];
}

//mailings

- (RACSignal *)getMailingCountWithStatuses:(EMMailingStatus)statuses
{
    id query = @{@"mailing_statuses" : EMMailingStatusToString(statuses)};
    
    return [[self requestSignalWithMethod:@"GET" path:[@"/mailings" stringByAppendingQueryString:query] headers:nil body:nil] map:^id(NSNumber *value) {
        return [value numberOrNil];
    }];
;
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
    return [[self requestSignalWithMethod:@"GET" path:[NSString stringWithFormat:@"/mailings/%@", mailingID] headers:nil body:nil] map:^id(NSDictionary *value) {
        return [[EMMailing alloc] initWithDictionary:value];
    }];
}

- (RACSignal *)getMembersCountForMailingID:(NSString *)mailingID
{
    return [[self requestSignalWithMethod:@"GET" path:[NSString stringWithFormat:@"/mailings/%@/members", mailingID] headers:nil body:nil] map:^id(NSNumber *value) {
        return [value numberOrNil];
    }];
}

- (RACSignal *)getMembersForMailingID:(NSString *)mailingID inRange:(EMResultRange)range
{
    id query = [@{} dictionaryByAddingRangeParams:range];
        
    return [[self requestSignalWithMethod:@"GET" path:[[NSString stringWithFormat:@"/mailings/%@/members", mailingID] stringByAppendingQueryString:query] headers:nil body:nil] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(id value) {
            return [[EMMember alloc] initWithDictionary:value accountFields:nil];
        }].array;
    }];
}

- (RACSignal *)getMessageToMemberID:(NSString *)memberID forMailingID:(NSString *)mailingID
{
    return [[self requestSignalWithMethod:@"GET" path:[NSString stringWithFormat:@"/mailings/%@/messages/%@", mailingID, memberID] headers:nil body:nil] map:^id(NSDictionary *value) {
        return [[EMMessage alloc] initWithDictionary:value];
    }];
}

- (RACSignal *)getGroupCountForMailingID:(NSString *)mailingID
{
    return [[self requestSignalWithMethod:@"GET" path:[NSString stringWithFormat:@"/mailings/%@/groups", mailingID] headers:nil body:nil] map:^id(NSNumber *value) {
        return [value numberOrNil];
    }];;
}

- (RACSignal *)getGroupsForMailingID:(NSString *)mailingID inRange:(EMResultRange)range
{
    id query = [@{} dictionaryByAddingRangeParams:range];
    
    return [[self requestSignalWithMethod:@"GET" path:[[NSString stringWithFormat:@"/mailings/%@/groups", mailingID] stringByAppendingQueryString:query] headers:nil body:nil] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(id value) {
            return [[EMGroup alloc] initWithDictionary:value];
        }].array;
    }];
}

- (RACSignal *)getSearchCountForMailingID:(NSString *)mailingID
{
    return [[self requestSignalWithMethod:@"GET" path:[NSString stringWithFormat:@"/mailings/%@/searches", mailingID] headers:nil body:nil] map:^id(NSNumber *value) {
        return [value numberOrNil];
    }];
}

- (RACSignal *)getSearchesForMailingID:(NSString *)mailingID inRange:(EMResultRange)range
{
    id query = [@{} dictionaryByAddingRangeParams:range];
    
    return [[self requestSignalWithMethod:@"GET" path:[[NSString stringWithFormat:@"/mailings/%@/searches", mailingID] stringByAppendingQueryString:query] headers:nil body:nil] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(id value) {
            return [[EMSearch alloc] initWithDictionary:value];
        }].array;
    }];
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
    id body = @{
    @"heads_up_emails" : headsUpAddresses,
    @"recipient_emails" : recipientAddresses,
    @"recipient_groups" : recipientGroupIDs,
    @"recipient_searches" : recipientSearchIDs
    };
    
    return [[self requestSignalWithMethod:@"POST" path:[NSString stringWithFormat:@"/mailings/%@", mailingID] headers:nil body:body] map:^id(NSNumber* result) {
        return [[result numberOrNil] objectIDStringValue];
    }];
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
    
    return [[self requestSignalWithMethod:@"GET" path:[@"/members" stringByAppendingQueryString:query] headers:nil body:nil] map:^id(NSNumber *value) {
        return [value numberOrNil];
    }];
}

- (RACSignal *)getMembersInRange:(EMResultRange)range includeDeleted:(BOOL)deleted
{
    id query = [@{@"deleted": deleted ? @"true" : @"false" } dictionaryByAddingRangeParams:range];

    return [[self requestSignalWithMethod:@"GET" path:[@"/members" stringByAppendingQueryString:query] headers:nil body:nil] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(id value) {
            return [[EMMember alloc] initWithDictionary:value accountFields:nil];
        }].array;
    }];
}

- (RACSignal *)getMemberWithID:(NSString *)memberID
{
    return [[self requestSignalWithMethod:@"GET" path:[NSString stringWithFormat:@"/members/%@", memberID] headers:nil body:nil] map:^id(NSDictionary *value) {
        return [[EMMember alloc] initWithDictionary:value accountFields:nil];
    }];
}

- (RACSignal *)getMemberWithEmail:(NSString *)email
{
    return [[self requestSignalWithMethod:@"GET" path:[NSString stringWithFormat:@"/members/email/%@", email] headers:nil body:nil] map:^id(NSDictionary *value) {
        return [[EMMember alloc] initWithDictionary:value accountFields:nil];
    }];
}

- (RACSignal *)getOptoutInfoForMemberID:(NSString *)memberID
{
    return [self requestSignalWithMethod:@"GET" path:[NSString stringWithFormat:@"/members/%@/optout", memberID] headers:nil body:nil];
}

- (RACSignal *)optoutMemberWithEmail:(NSString *)email
{
    return [self requestSignalWithMethod:@"PUT" path:[NSString stringWithFormat:@"/members/email/optout/%@", email] headers:nil body:nil];
}

- (RACSignal *)createMembers:(NSArray *)members withSourceName:(NSString *)sourceName addOnly:(BOOL)addOnly groupIDs:(NSArray *)groupIDs
{
    id memberEmails = [members.rac_sequence map:^id(EMMember *value) {
        return @{ @"email" : value.email };
    }].array;
    
    id body = @{
    @"members" : memberEmails,
    @"source_filename" : sourceName,
    @"add_only" : @(addOnly),
    @"group_ids" : groupIDs
    };
    
    return [[self requestSignalWithMethod:@"POST" path:@"/members" headers:nil body:body] map:^id(id result) {
        return [[result[@"import_id"] numberOrNil] objectIDStringValue];
    }];
}

- (RACSignal *)createMember:(EMMember *)member
{
    return [[self requestSignalWithMethod:@"POST" path:@"/members/add" headers:nil body:@{ @"email" : member.email }] map:^id(id result) {
        return [[result[@"member_id"] numberOrNil] objectIDStringValue];
    }];
}

- (RACSignal *)deleteMembersWithIDs:(NSArray *)memberIDs
{
    return [self requestSignalWithMethod:@"PUT" path:@"/members/delete" headers:nil body:@{ @"member_ids" : [memberIDs.rac_sequence map:^id(NSString *memberID) {
        return [NSNumber numberWithObjectIDString:memberID];
    }].array }];
}

- (RACSignal *)updateMemberIDs:(NSArray *)memberIDs withStatus:(EMMemberStatus)status
{
    return [self requestSignalWithMethod:@"PUT" path:@"/members/status" headers:nil body:@{ @"member_ids" : memberIDs, @"status_to" : EMMemberStatusToString(status) }];
}

- (RACSignal *)updateMember:(EMMember *)member
{
    return [self requestSignalWithMethod:@"PUT" path:[NSString stringWithFormat:@"/members/%@", member.ID] headers:nil body:@{ @"email" : member.email, @"status_to" : EMMemberStatusToString(member.status) }];
}

- (RACSignal *)getGroupsForMemberID:(NSString *)memberID
{
    return [[self requestSignalWithMethod:@"GET" path:[NSString stringWithFormat:@"/members/%@/groups", memberID] headers:nil body:nil] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(id value) {
            return [[EMGroup alloc] initWithDictionary:value];
        }].array;
    }];
}

- (RACSignal *)addMemberID:(NSString *)memberID toGroupIDs:(NSArray *)groupIDs
{
    return [self requestSignalWithMethod:@"PUT" path:[NSString stringWithFormat:@"/members/%@/groups", memberID] headers:nil body:@{@"group_ids" : groupIDs}];
}

- (RACSignal *)deleteMembersWithStatus:(EMMemberStatus)status
{
    id query = @{ @"member_status" : EMMemberStatusToString(status) };
    return [self requestSignalWithMethod:@"PUT" path:[@"/members" stringByAppendingQueryString:query] headers:nil body:nil];
}

- (RACSignal *)removeMemberFromAllGroups:(NSString *)memberID
{
    return [self requestSignalWithMethod:@"DELETE" path:[NSString stringWithFormat:@"/members/%@/groups", memberID] headers:nil body:nil];
}

- (RACSignal *)removeMemberIDs:(NSArray *)memberIDs fromGroupIDs:(NSArray *)groupIDs
{
    return [self requestSignalWithMethod:@"PUT" path:[NSString stringWithFormat:@"/members/groups/remove"] headers:nil body:@{@"group_ids" : groupIDs, @"member_ids" : memberIDs}];
}

- (RACSignal *)getMailingHistoryForMemberID:(NSString *)memberID
{
    return [[self requestSignalWithMethod:@"GET" path:[NSString stringWithFormat:@"/members/%@/mailings", memberID] headers:nil body:nil] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(id value) {
            return [[EMMailing alloc] initWithDictionary:value];
        }].array;
    }];
}

- (RACSignal *)getMembersForImportID:(NSString *)importID
{
    return [[self requestSignalWithMethod:@"GET" path:[NSString stringWithFormat:@"/members/imports/%@/members", importID] headers:nil body:nil] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(id value) {
            return [[EMMember alloc] initWithDictionary:value accountFields:nil];
        }].array;
    }];
}

- (RACSignal *)getImportID:(NSString *)importID
{
    return [[self requestSignalWithMethod:@"GET" path:[NSString stringWithFormat:@"/members/imports/%@", importID] headers:nil body:nil] map:^id(NSDictionary *value) {
        return [[EMImport alloc] initWithDictionary:value];
    }];
}

- (RACSignal *)getImports
{
    return [[self requestSignalWithMethod:@"GET" path:@"/members/imports" headers:nil body:nil] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(id value) {
            return [[EMImport alloc] initWithDictionary:value];
        }].array;
    }];
}

- (RACSignal *)copyMembersWithStatuses:(EMMemberStatus)status toGroup:(NSString *)groupID
{
    return [self requestSignalWithMethod:@"PUT" path:[NSString stringWithFormat:@"/members/%@/copy", groupID] headers:nil body:@{ @"member_status_id" : @[ EMMemberStatusToString(status) ] }];
}

- (RACSignal *)updateMembersWithStatus:(EMMemberStatus)fromStatus toStatus:(EMMemberStatus)toStatus limitByGroupID:(NSString *)groupID
{
    id body = nil;
    if (groupID) body = @{ @"group_id" : groupID };
    return [self requestSignalWithMethod:@"PUT" path:[NSString stringWithFormat:@"/members/status/%@/to/%@", EMMemberStatusToString(fromStatus), EMMemberStatusToString(toStatus)] headers:nil body:body];
}

// searches

- (RACSignal *)getSearchCount // returns NSArray of EMSearch
{
    return [[self requestSignalWithMethod:@"GET" path:@"/searches" headers:nil body:nil] map:^id(NSNumber *value) {
        return [value numberOrNil];
    }];
}

- (RACSignal *)getSearchesInRange:(EMResultRange)range // returns NSArray of EMSearch
{
    id query = [@{} dictionaryByAddingRangeParams:range];
    
    return [[self requestSignalWithMethod:@"GET" path:[@"/searches" stringByAppendingQueryString:query] headers:nil body:nil] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(id value) {
            return [[EMSearch alloc] initWithDictionary:value];
        }].array;
    }];
}

- (RACSignal *)getSearchID:(NSString *)searchID
{
    return [[self requestSignalWithMethod:@"GET" path:[NSString stringWithFormat:@"/searches/%@", searchID] headers:nil body:nil] map:^id(NSDictionary *value) {
        return [[EMSearch alloc] initWithDictionary:value];
    }];
}

- (RACSignal *)createSearch:(EMSearch *)search
{
    return [[self requestSignalWithMethod:@"POST" path:@"/searches" headers:nil body:search.dictionaryRepresentation] map:^id(NSNumber* result) {
        return [[result numberOrNil] objectIDStringValue];
    }];}

- (RACSignal *)updateSearch:(EMSearch *)search
{
    return [self requestSignalWithMethod:@"PUT" path:[NSString stringWithFormat:@"/searches/%@", search.ID] headers:nil body:search.dictionaryRepresentation];
}

- (RACSignal *)deleteSearchID:(NSString *)searchID
{
    return [self requestSignalWithMethod:@"DELETE" path:[NSString stringWithFormat:@"/searches/%@", searchID] headers:nil body:nil];
}

- (RACSignal *)getMemberCountInSearchID:(NSString *)searchID // returns NSNumber
{
    return [[self requestSignalWithMethod:@"GET" path:[NSString stringWithFormat:@"/searches/%@/members", searchID] headers:nil body:nil] map:^id(NSNumber *value) {
        return [value numberOrNil];
    }];
}

- (RACSignal *)getMembersInSearchID:(NSString *)searchID inRange:(EMResultRange)range // returns NSArray of EMMember
{
    id query = [@{} dictionaryByAddingRangeParams:range];
    return [[self requestSignalWithMethod:@"GET" path:[[NSString stringWithFormat:@"/searches/%@/members", searchID] stringByAppendingQueryString:query] headers:nil body:nil] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(id value) {
            return [[EMMember alloc] initWithDictionary:value accountFields:nil];
        }].array;
    }];}

//webhooks

- (RACSignal *)getWebhookCount {
    return [self requestSignalWithMethod:@"GET" path:[@"/webhooks" stringByAppendingQueryString:[@{} dictionaryByAddingCountParam]] headers:nil body:nil];
}

- (RACSignal *)getWebhooksInRange:(EMResultRange)range {
    return [[self requestSignalWithMethod:@"GET" path:
             [@"/webhooks" stringByAppendingQueryString:[@{} dictionaryByAddingRangeParams:range]] headers:nil body:nil] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(NSDictionary *value) {
            return [[EMWebhook alloc] initWithDictionary:value];
        }].array;
    }];
}

- (RACSignal *)getWebhookEvents {
    return [[self requestSignalWithMethod:@"GET" path:@"/webhooks/events" headers:nil body:nil] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(id value) {
            return [[EMWebhookInfo alloc] initWithDictionary:value];
        }].array;
    }];
}

- (RACSignal *)createWebhook:(EMWebhook *)webhook withPublicKey:(NSString *)publicKey {
    NSMutableDictionary *body = [webhook.dictionaryRepresentation mutableCopy];
    
    if (publicKey)
        body[@"public_key"] = publicKey;
    
    return [[self requestSignalWithMethod:@"POST" path:@"/webhooks" headers:nil body:body] map:^id(NSNumber *number) {
        return [[number numberOrNil] objectIDStringValue];
    }];
}

- (RACSignal *)updateWebhook:(EMWebhook *)webhook {
    return [[self requestSignalWithMethod:@"PUT" path:[NSString stringWithFormat:@"/webhooks/%@", webhook.webhookID] headers:nil body:webhook.dictionaryRepresentation] map:^id(NSNumber *number) {
        return [[number numberOrNil] objectIDStringValue];
    }];
}

- (RACSignal *)deleteWebhookWithID:(NSString *)webhookID {
    return [self requestSignalWithMethod:@"DELETE" path:[NSString stringWithFormat:@"/webhooks/%@", webhookID] headers:nil body:nil];
}

- (RACSignal *)deleteAllWebhooks {
    return [self requestSignalWithMethod:@"DELETE" path:@"/webhooks" headers:nil body:nil];
}

// triggers

- (RACSignal *)getTriggerCount {
    return [self requestSignalWithMethod:@"GET" path:[@"/triggers" stringByAppendingQueryString:[@{} dictionaryByAddingCountParam]] headers:nil body:nil];
}

- (RACSignal *)getTriggersInRange:(EMResultRange)range {
    return [[self requestSignalWithMethod:@"GET" path:[@"/triggers" stringByAppendingQueryString:[@{} dictionaryByAddingRangeParams:range]] headers:nil body:nil] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(NSDictionary *value) {
            return [[EMTrigger alloc] initWithDictionary:value];
        }].array;
    }];
}

- (RACSignal *)createTrigger:(EMTrigger *)trigger {
    return [[self requestSignalWithMethod:@"POST" path:@"/triggers" headers:nil body:trigger.dictionaryRepresentation] map:^id(id value) {
        return [[value numberOrNil] objectIDStringValue];
    }];
}

- (RACSignal *)getTriggerWithID:(NSString *)triggerID {
    return [[self requestSignalWithMethod:@"GET" path:[NSString stringWithFormat:@"/triggers/%@", triggerID] headers:nil body:nil] map:^id(id value) {
        return [[EMTrigger alloc] initWithDictionary:value];
    }];
}

- (RACSignal *)updateTrigger:(EMTrigger *)trigger {
    return [[self requestSignalWithMethod:@"PUT" path:[NSString stringWithFormat:@"/triggers/%@", trigger.triggerID] headers:nil body:trigger.dictionaryRepresentation] map:^id(id value) {
        return [[value numberOrNil] objectIDStringValue];
    }];
}

- (RACSignal *)deleteTriggerWithID:(NSString *)triggerID {
    return [self requestSignalWithMethod:@"DELETE" path:[NSString stringWithFormat:@"/triggers/%@", triggerID] headers:nil body:nil];
}

- (RACSignal *)getMailingCountForTriggerID:(NSString *)triggerID {
    return [[self requestSignalWithMethod:@"GET" path:[[NSString stringWithFormat:@"/triggers/%@/mailings", triggerID] stringByAppendingQueryString:[@{} dictionaryByAddingCountParam]] headers:nil body:nil] map:^id(id value) {
        return [value numberOrNil];
    }];
}

- (RACSignal *)getMailingsForTriggerID:(NSString *)triggerID inRange:(EMResultRange)range {
    return [self requestSignalWithMethod:@"GET" path:[[NSString stringWithFormat:@"/triggers/%@/mailings", triggerID] stringByAppendingQueryString:[@{} dictionaryByAddingRangeParams:range]] headers:nil body:nil];
}

//response

- (RACSignal *)getResponseSummary
{
    return [[self requestSignalWithMethod:@"GET" path:@"/response?include_archived=false" headers:nil body:nil] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(id value) {
            return [[EMResponseSummary alloc] initWithDictionary:value];
        }].array;
    }];
}

- (RACSignal *)getResponseSummaryInRange:(NSString *)rangeString includeArchived:(BOOL)includeArchived
{
    id query = @{ @"include_archived": includeArchived ? @"true" : @"false", @"range" : rangeString };
    
    return [[self requestSignalWithMethod:@"GET" path:[@"/response" stringByAppendingQueryString:query] headers:nil body:nil] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(id value) {
            return [[EMResponseSummary alloc] initWithDictionary:value];
        }].array;
    }];
}

- (RACSignal *)getResponseForMailingID:(NSString *)mailingID
{
    return [[self requestSignalWithMethod:@"GET" path:[NSString stringWithFormat:@"/response/%@", mailingID] headers:nil body:nil] map:^id(id value) {
        return [[EMMailingResponse alloc] initWithDictionary:value];
    }];
}

- (RACSignal *)getSendsForMailingID:(NSString *)mailingID
{
    return [[self requestSignalWithMethod:@"GET" path:[NSString stringWithFormat:@"/response/%@/sends", mailingID] headers:nil body:nil] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(id value) {
            return [[EMMailingResponseEvent alloc] initWithDictionary:value accountFields:nil];
        }].array;
    }];
}

- (RACSignal *)getInProgressForMailingID:(NSString *)mailingID
{
    return [[self requestSignalWithMethod:@"GET" path:[NSString stringWithFormat:@"/response/%@/in_progress", mailingID] headers:nil body:nil] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(id value) {
            return [[EMMailingResponseEvent alloc] initWithDictionary:value accountFields:nil];
        }].array;
    }];
}

- (RACSignal *)getDeliveriesForMailingID:(NSString *)mailingID withDeliveryStatus:(EMDeliveryStatus)status
{
    NSString *delStatus = nil;
    delStatus = EMDeliveryStatusToString(status);
    if (!delStatus) delStatus = EMDeliveryStatusToString(EMDeliveryStatusAll);
    return [[self requestSignalWithMethod:@"GET" path:[NSString stringWithFormat:@"/response/%@/deliveries?del_status=%@", mailingID, delStatus] headers:nil body:nil] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(id value) {
            return [[EMMailingResponseEvent alloc] initWithDictionary:value accountFields:nil];
        }].array;
    }];
}
- (RACSignal *)getOpensForMailingID:(NSString *)mailingID
{
    return [[self requestSignalWithMethod:@"GET" path:[NSString stringWithFormat:@"/response/%@/opens", mailingID] headers:nil body:nil] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(id value) {
            return [[EMMailingResponseEvent alloc] initWithDictionary:value accountFields:nil];
        }].array;
    }];
}

- (RACSignal *)getLinksForMailingID:(NSString *)mailingID
{
    return [[self requestSignalWithMethod:@"GET" path:[NSString stringWithFormat:@"/response/%@/links", mailingID] headers:nil body:nil] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(id value) {
            return [[EMMailingLinkResponse alloc] initWithDictionary:value];
        }].array;
    }];
}

- (RACSignal *)getClicksForMailingID:(NSString *)mailingID memberID:(NSString *)memberID linkID:(NSString *)linkID
{
    id query = [@{} mutableCopy];
    
    if (memberID)
        query[@"member_id"] = memberID;
    
    if (linkID)
        query[@"link_id"] = linkID;
    
    return [[self requestSignalWithMethod:@"GET" path:[[NSString stringWithFormat:@"/response/%@/clicks", mailingID] stringByAppendingQueryString:query] headers:nil body:nil] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(id value) {
            return [[EMMailingResponseEvent alloc] initWithDictionary:value accountFields:nil];
        }].array;
    }];
}

- (RACSignal *)getForwardsForMailingID:(NSString *)mailingID
{
    return [[self requestSignalWithMethod:@"GET" path:[NSString stringWithFormat:@"/response/%@/forwards", mailingID] headers:nil body:nil] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(id value) {
            return [[EMMailingResponseEvent alloc] initWithDictionary:value accountFields:nil];
        }].array;
    }];
}

- (RACSignal *)getOptoutsForMailingID:(NSString *)mailingID
{
    return [[self requestSignalWithMethod:@"GET" path:[NSString stringWithFormat:@"/response/%@/optouts", mailingID] headers:nil body:nil] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(id value) {
            return [[EMMailingResponseEvent alloc] initWithDictionary:value accountFields:nil];
        }].array;
    }];
}

- (RACSignal *)getSignupsForMailingID:(NSString *)mailingID
{
    return [[self requestSignalWithMethod:@"GET" path:[NSString stringWithFormat:@"/response/%@/signups", mailingID] headers:nil body:nil] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(id value) {
            return [[EMMailingResponseEvent alloc] initWithDictionary:value accountFields:nil];
        }].array;
    }];
}

- (RACSignal *)getSharesForMailingID:(NSString *)mailingID
{
    return [[self requestSignalWithMethod:@"GET" path:[NSString stringWithFormat:@"/response/%@/shares", mailingID] headers:nil body:nil] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(id value) {
            return [[EMShare alloc] initWithDictionary:value];
        }].array;
    }];
}

- (RACSignal *)getCustomerSharesForMailingID:(NSString *)mailingID
{
    return [[self requestSignalWithMethod:@"GET" path:[NSString stringWithFormat:@"/response/%@/customer_shares", mailingID] headers:nil body:nil] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(id value) {
            return [[EMShare alloc] initWithDictionary:value];
        }].array;
    }];
}

- (RACSignal *)getCustomerShareClicksForMailingID:(NSString *)mailingID
{
    return [[self requestSignalWithMethod:@"GET" path:[NSString stringWithFormat:@"/response/%@/customer_share_clicks", mailingID] headers:nil body:nil] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(id value) {
            return [[EMShare alloc] initWithDictionary:value];
        }].array;
    }];
}

- (RACSignal *)getCustomerShareID:(NSString *)shareID
{
    return [[self requestSignalWithMethod:@"GET" path:[NSString stringWithFormat:@"/response/%@/customer_share", shareID] headers:nil body:nil] map:^id(NSDictionary *value) {
        return [[EMShare alloc] initWithDictionary:value];
    }];
}

- (RACSignal *)getSharesOverviewForMailingID:(NSString *)mailingID
{
    return [[self requestSignalWithMethod:@"GET" path:[NSString stringWithFormat:@"/response/%@/shares/overview", mailingID] headers:nil body:nil] map:^id(NSArray *results) {
        return [results.rac_sequence map:^id(id value) {
            return [[EMShareSummary alloc] initWithDictionary:value];
        }].array;
    }];
}

@end