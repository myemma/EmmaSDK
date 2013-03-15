#import "EmmaSDKTests.h"
#define EXP_SHORTHAND
#import "Expecta.h"
#import "Specta.h"
#import "EmmaSDK.h"
#import "EMClient+Private.h"
#import <SBJson/SBJson.h>
#import "SMWebRequest.h"

@interface NSString (NSString_SBJsonParsing)

@end

@implementation NSString (NSString_SBJsonParsing)

- (id)JSONValue {
    SBJsonParser *parser = [[SBJsonParser alloc] init];
    id repr = [parser objectWithString:self];
    if (!repr)
        NSLog(@"-JSONValue failed. Error is: %@", parser.error);
    return repr;
}

@end

#define API_HOST @"http://api.e2ma.net"

@interface MockEndpoint : NSObject <EMEndpoint>

@property (nonatomic, copy) NSArray *calls, *results;

@end

@implementation MockEndpoint

@synthesize calls, results;

- (id)init {
    if (self = [super init]) {
        self.calls = [NSMutableArray array];
        self.results = [NSMutableArray array];
    }
    return self;
}

- (RACSignal *)getNextResult {
    id resultObject = results.count ? results[0] : nil;
    
    if (results.count) {
        NSMutableArray *newResults = [results mutableCopy];
        [newResults removeObjectAtIndex:0];
        results = newResults;
    }
    
    return resultObject;
}

- (RACSignal *)requestSignalWithURLRequest:(NSURLRequest *)urlRequest {
    NSString *hostname = urlRequest.URL.host;
    NSString *port = [urlRequest.URL.port stringValue];
    NSString *scheme = urlRequest.URL.scheme;
    NSString *host = [NSString stringWithFormat:@"%@://%@", scheme, hostname];
    
    if (port && ![@"80" isEqual:port])
        host = [NSString stringWithFormat:@"%@:%@", host, port];
    
    NSString *method = urlRequest.HTTPMethod;
    NSString *path = urlRequest.URL.path;
    
    if (urlRequest.URL.query.length)
        path = [path stringByAppendingFormat:@"?%@", urlRequest.URL.query];
    
    NSDictionary *headers = urlRequest.allHTTPHeaderFields;
    id body = [[[NSString alloc] initWithData:urlRequest.HTTPBody encoding:NSUTF8StringEncoding] JSONValue];
    NSDictionary *call = @{
                           @"host": host,
                           @"method" : method ? method : [NSNull null],
                           @"path" : path ? path : [NSNull null],
                           @"headers" : headers ? headers : [NSNull null],
                           @"body" : body ? body : [NSNull null]
                           };
    
    calls = [calls arrayByAddingObject:call];
    
    return [self getNextResult];
}

- (void)addErrorResult:(NSUInteger)status headers:(NSDictionary *)headers body:(NSData *)body {
    SMErrorResponse *errorResponse = [[SMErrorResponse alloc] init];
    errorResponse.response = [[NSHTTPURLResponse alloc] initWithURL:nil statusCode:400 HTTPVersion:@"HTTP/1.1" headerFields:nil];
    if (body)
        errorResponse.data = body;
    self.results =  [self.results arrayByAddingObject:[RACSignal error:[NSError errorWithDomain:@"SMWebRequest" code:0 userInfo:@{ SMErrorResponseKey : errorResponse }]]];
}

- (void)expectRequestWithMethod:(NSString *)method path:(NSString *)path {
    [self expectRequestWithMethod:method path:path body:nil];
}


- (void)expectRequestWithMethod:(NSString *)method path:(NSString *)path body:(id)body {
    id x = @[@{
        @"host": API_HOST,
        @"method": method,
        @"path": [NSString stringWithFormat:@"/1%@", path],
        @"headers": body ? @{ @"Content-Type": @"application/json" } : @{},
        @"body": body ? body : [NSNull null],
     }];
    
    expect(calls).to.equal(x);
}

@end

SpecBegin(EMClient)

describe(@"EMClient", ^{
    __block EMClient *client;
    __block MockEndpoint *endpoint;
    __block EMGroup *group;
    
    beforeEach(^ {
        endpoint = [[MockEndpoint alloc] init];
        client = [[EMClient alloc] initWithEndpoint:endpoint];
        
        group = [[EMGroup alloc] init];
        group.ID = @"123";
        group.name = @"FOO";
    });
    
    it(@"createGroupsWithNames: should call endpoint", ^ {
        [[client createGroupsWithNames:@[@"foo", @"bar", @"baz"]] subscribeCompleted:^ {}];
        [endpoint expectRequestWithMethod:@"POST" path:@"/groups" body:@{ @"groups": @[ @{ @"group_name": @"foo" },  @{ @"group_name": @"bar" }, @{ @"group_name": @"baz" } ] }];
    });
    
    it(@"createGroupsWithNames: should parse results", ^ {
        __block NSArray *result;
        
        endpoint.results = @[ [RACSignal return:@[@{ @"group_name": @"foo", @"member_group_id": @123 }, @{ @"group_name" : @"bar", @"member_group_id": @456 }] ] ];
        
        [[client createGroupsWithNames:@[]] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result.count).to.equal(2);
        expect([result[0] ID]).to.equal(@"123");
        expect([result[0] name]).to.equal(@"foo");
        expect([result[1] ID]).to.equal(@"456");
        expect([result[1] name]).to.equal(@"bar");
    });
    
    it(@"getGroupCountWithType: should call endpoint", ^ {
        [[client getGroupCountWithType:EMGroupTypeAll] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/groups?count=true&group_types=all" body:nil];
    });
    
    it(@"getGroupCountWithType: should parse results", ^ {
        __block NSArray *result;
        
        endpoint.results = @[ [RACSignal return:@6] ];
        
        [[client getGroupCountWithType:EMGroupTypeAll] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result).to.equal(@6);
    });
    
    void (^testCallsEndpointWithGroupType)(EMGroupType type, NSString *groupTypeString) = ^ (EMGroupType type, NSString *groupTypeString) {
        
        [[client getGroupsWithType:type inRange:(EMResultRange){ .start = 10, .end = 20 }] subscribeCompleted:^ { }];
        [endpoint expectRequestWithMethod:@"GET" path:[NSString stringWithFormat:@"/groups?end=20&group_types=%@&start=10", groupTypeString] body:nil];
    };
    
    it(@"getGroupsWithType:inRange: should call endpoint for all group types", ^ {
        testCallsEndpointWithGroupType(EMGroupTypeAll, @"all");
    });
    
    it(@"getGroupsWithType:inRange: should call endpoint for test groups", ^ {
        testCallsEndpointWithGroupType(EMGroupTypeTest, @"t");
    });
    
    it(@"getGroupsWithType:inRange: should call endpoint for group groups", ^ {
        testCallsEndpointWithGroupType(EMGroupTypeGroup, @"g");
    });
    
    it(@"getGroupsWithType:inRange: should call endpoint for hidden groups", ^ {
        testCallsEndpointWithGroupType(EMGroupTypeHidden, @"h");
    });
    
    it(@"getGroupsWithType:inRange: should call endpoint for multiple group types", ^ {
        testCallsEndpointWithGroupType(EMGroupTypeHidden | EMGroupTypeTest, @"t,h");
    });
    
    it(@"getGroupsWithType:inRange: should parse results", ^ {
        __block NSArray *result;
        
        endpoint.results = @[ [RACSignal return:@[
                               @{
                               @"active_count": @1,
                               @"deleted_at": [NSNull null],
                               @"error_count": @0,
                               @"optout_count": @1,
                               @"group_type": @"g",
                               @"member_group_id": @150,
                               @"account_id": @100,
                               @"group_name": @"Monthly Newsletter"
                               }
                               ]] ];
        
        [[client getGroupsWithType:EMGroupTypeAll inRange:(EMResultRange){ .start = 10, .end = 20 }] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result.count).to.equal(1);
        expect([result[0] ID]).to.equal(@"150");
        expect([result[0] name]).to.equal(@"Monthly Newsletter");
        expect([result[0] activeCount]).to.equal(@1);
        expect([result[0] errorCount]).to.equal(@0);
        expect([result[0] optoutCount]).to.equal(@1);
    });
    
    it(@"updateGroup: should call endpoint", ^ {
        [[client updateGroup:group] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"PUT" path:@"/groups/123" body:@{ @"group_name": @"FOO" }];
    });
    
    it(@"updateGroup: should parse results", ^ {
        __block NSArray *result;
        
        endpoint.results = @[ [RACSignal return:@YES] ];
        
        [[client updateGroup:group] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result).to.equal(@YES);
    });
    
    it(@"getMembersInGroupID:inRange: should call endpoint with deleted", ^ {
        [[client getMembersInGroupID:@"123" inRange:(EMResultRange){ .start = 10, .end = 20 } includeDeleted:YES] subscribeCompleted:^ { }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/groups/123/members?deleted=true&end=20&start=10" body:nil];
    });
    
    it(@"getMembersInGroupID:inRange: should call endpoint without deleted", ^ {
        [[client getMembersInGroupID:@"123" inRange:(EMResultRange){ .start = 10, .end = 20 } includeDeleted:NO] subscribeCompleted:^ { }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/groups/123/members?deleted=false&end=20&start=10" body:nil];
    });
    
    it(@"getMembersInGroupID:inRange: should parse results", ^ {
        __block NSArray *result;
        
        id memberDict0 = @{
                           @"status": @"active",
                           @"confirmed_opt_in": [NSNull null],
                           @"account_id": @100,
                           @"fields": @{
                                   @"first_name": @"Emma",
                                   @"last_name": @"Smith",
                                   @"favorite_food": @"tacos"
                                   },
                           @"member_id": @200,
                           @"last_modified_at": [NSNull null],
                           @"member_status_id": @"a",
                           @"plaintext_preferred": @NO,
                           @"email_error": [NSNull null],
                           @"member_since": @"@D:2010-11-12T11:23:45",
                           @"bounce_count": @0,
                           @"deleted_at": [NSNull null],
                           @"email": @"emma@myemma.com"
                           };
        endpoint.results = @[ [RACSignal return:@[
                             memberDict0
                               ]] ];
        
        [[client getMembersInGroupID:@"123" inRange:(EMResultRange){ .start = 10, .end = 20 } includeDeleted:YES] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result.count).to.equal(1);
        expect([result[0] ID]).to.equal(@"200");
        expect([result[0] email]).to.equal(@"emma@myemma.com");
    });
    
    it(@"deleteGroupID: should parse results", ^ {
        __block NSArray *result;
        
        endpoint.results = @[ [RACSignal return:@YES] ];
        
        [[client deleteGroupID:@"123"] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result).to.equal(@YES);
    });
    
    it(@"deleteGroupID: should call endpoint", ^ {
        [[client deleteGroupID:@"123"] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"DELETE" path:@"/groups/123" body:nil];
    });
    
    
    it(@"getMailingCountWithStatuses: should call endpoint", ^ {
        [[client getMailingCountWithStatuses:EMMailingStatusAll] subscribeCompleted:^ { }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/mailings?mailing_statuses=p,a,s,x,c,f"];
    });
    
    it(@"getMailingCountWithStatuses: should parse results", ^ {
        __block NSArray *result;

        endpoint.results = @[ [RACSignal return:@4] ];

        [[client getMailingCountWithStatuses:EMMailingStatusAll] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result).to.equal(@4);
    });
    
    void (^testCallsEndpointWithMailingStatus)(EMMailingStatus status, NSString *statusString) = ^ (EMMailingStatus status, NSString *statusString) {
        [[client getMailingsWithStatuses:status inRange:(EMResultRange){ .start = 10, .end = 20}] subscribeCompleted:^ { }];
        NSString *pathString = [NSString stringWithFormat:@"/mailings?end=20&mailing_statuses=%@&start=10", statusString];
        [endpoint expectRequestWithMethod:@"GET" path:pathString];
    };

    it(@"getMailingsWithStatuses:inRange: should call endpoint all", ^ {
        testCallsEndpointWithMailingStatus(EMMailingStatusAll, @"p,a,s,x,c,f");
    });
    
    it(@"getMailingsWithStatuses:inRange: should call endpoint pending", ^ {
        testCallsEndpointWithMailingStatus(EMMailingStatusPending, @"p");
    });
    
    it(@"getMailingsWithStatuses:inRange: should call endpoint paused", ^ {
        testCallsEndpointWithMailingStatus(EMMailingStatusPaused, @"a");
    });
    
    it(@"getMailingsWithStatuses:inRange: should call endpoint sending", ^ {
        testCallsEndpointWithMailingStatus(EMMailingStatusSending, @"s");
    });
    
    it(@"getMailingsWithStatuses:inRange: should call endpoint cancelled", ^ {
        testCallsEndpointWithMailingStatus(EMMailingStatusCanceled, @"x");
    });
    
    it(@"getMailingsWithStatuses:inRange: should call endpoint complete", ^ {
        testCallsEndpointWithMailingStatus(EMMailingStatusComplete, @"c");
    });
    
    it(@"getMailingsWithStatuses:inRange: should call endpoint failed", ^ {
        testCallsEndpointWithMailingStatus(EMMailingStatusFailed, @"f");
    });
    
    it(@"getMailingsWithStatuses:inRange: should call endpoint cancelled and complete", ^ {
        testCallsEndpointWithMailingStatus(EMMailingStatusCanceled | EMMailingStatusComplete, @"x,c");
    });
    
    it(@"getMailingsWithStatuses:inRange: should call endpoint pending and sending and failed", ^ {
        testCallsEndpointWithMailingStatus(EMMailingStatusPending | EMMailingStatusSending | EMMailingStatusFailed, @"p,s,f");
    });
    
    it(@"getMailingsWithStatuses:inRange: should parse results", ^ {
        
        __block NSArray *result;

        id mailingsDict = @{
                                 @"mailing_status": @"p",
                                 @"plaintext_only": @NO,
                                 @"sender": @"Kevin McConnell",
                                 @"name": @"Cancellable mailing",
                                 @"mailing_id": @201,
                                 @"started_or_finished": [NSNull null],
                                 @"recipient_count": @0,
                                 @"year": [NSNull null],
                                 @"subject": @"Cancellable mailing",
                                 @"mailing_type": @"m",
                                 @"month": [NSNull null],
                                 @"disabled": @NO,
                                 @"send_finished": [NSNull null],
                                 @"send_at": [NSNull null],
                                 @"parent_mailing_id": [NSNull null],
                                 @"reply_to": [NSNull null],
                                 @"send_started": [NSNull null],
                                 @"signup_form_id": [NSNull null],
                                 @"archived_ts": [NSNull null],
                                 @"account_id": @100
                             };
        
        endpoint.results = @[ [RACSignal return:@[
                               mailingsDict
                               ]] ];
        
        [[client getMailingsWithStatuses:EMMailingStatusAll inRange:(EMResultRange){ .start = 10, .end = 20 }] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result.count).to.equal(1);
        expect([result[0] status]).to.equal(EMMailingStatusPending);
        expect([result[0] sender]).to.equal(@"Kevin McConnell");
        expect([result[0] name]).to.equal(@"Cancellable mailing");
        expect([result[0] ID]).to.equal(@"201");
        expect([result[0] recipientCount]).to.equal(@0);
        expect([result[0] subject]).to.equal(@"Cancellable mailing");
    });
    
    it(@"addMemberIDs:toGroupID: should call endpoint", ^ {
        [[client addMemberIDs:@[@123, @456] toGroupID:@"789"] subscribeCompleted:^ {}];
        [endpoint expectRequestWithMethod:@"PUT" path:@"/groups/789/members" body:@{ @"member_ids": @[ @123, @456 ] }];
    });
    
    it(@"addMemberIDs:toGroupID: should parse results", ^ {
        endpoint.results = @[ [RACSignal return:@[ @123 ]] ];
        
        __block NSArray *results;
        
        [[client addMemberIDs:@[@123, @456] toGroupID:@"789"] subscribeNext:^(id x) {
            results = x;
        }];
        
        expect(results.count).to.equal(1);
        expect(results[0]).to.equal(@123);
    });
    
    it(@"removeMemberIDs:fromGroupID: should call endpoint", ^ {
        [[client removeMemberIDs:@[@123, @456] fromGroupID:@"789"] subscribeCompleted:^ {}];
        [endpoint expectRequestWithMethod:@"PUT" path:@"/groups/789/members/remove" body:@{ @"member_ids": @[ @123, @456 ] }];
    });
    
    it(@"removeMemberIDs:fromGroupID: should parse results", ^ {
        endpoint.results = @[ [RACSignal return:@[ @123 ]] ];
        
        __block NSArray *results;
        
        [[client removeMemberIDs:@[@123, @456] fromGroupID:@"789"] subscribeNext:^(id x) {
            results = x;
        }];
        
        expect(results.count).to.equal(1);
        expect(results[0]).to.equal(@123);
    });
});

SpecEnd