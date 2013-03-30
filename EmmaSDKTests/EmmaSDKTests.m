#import "EmmaSDKTests.h"
#define EXP_SHORTHAND
#import "Expecta.h"
#import "Specta.h"
#import "EmmaSDK.h"
#import "EMClient+Private.h"
#import <SBJson/SBJson.h>
#import "SMWebRequest.h"
#import "NSString+DateParsing.h"
#import "NSData+Base64.h"

#define ExpectResultTo expect(clientResult).to
#define ExpectResultSelector(A) (expect([clientResult A]))

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
#define API_PUBLIC_KEY @"fooooo"
#define API_PRIVATE_KEY @"baaar"

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
    NSMutableDictionary *headers = [NSMutableDictionary dictionary];
    
    headers[@"Authorization"] = [@"Basic " stringByAppendingString:[[[NSString stringWithFormat:@"%@:%@", API_PUBLIC_KEY, API_PRIVATE_KEY] dataUsingEncoding:NSUTF8StringEncoding] base64EncodedString]];
    
    if (body)
        headers[@"Content-Type"] = @"application/json";
    
    id x = @[@{
        @"host": API_HOST,
        @"method": method,
        @"path": [NSString stringWithFormat:@"/1%@", path],
        @"headers": headers,
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
        client.accountID = @"1";
        client.publicKey = API_PUBLIC_KEY;
        client.privateKey = API_PRIVATE_KEY;
        
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
    
    it(@"getGroupID: should call endpoint", ^ {
        [[client getGroupID:@"321"] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/groups/321" body:nil];
    });
    
    it(@"getGroupID: should parse results", ^ {
        __block EMGroup *result;
        
        id memberDict0 = @{
            @"active_count": @1,
            @"deleted_at": [NSNull null],
            @"error_count": @0,
            @"optout_count": @1,
            @"group_type": @"g",
            @"member_group_id": @150,
            @"account_id": @100,
            @"group_name": @"Monthly Newsletter"
        };
        endpoint.results = @[ [RACSignal return:
                               memberDict0
                               ] ];
        
        [[client getGroupID:@"150"] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect([result ID]).to.equal(@"150");
        expect([result name]).to.equal(@"Monthly Newsletter");
        expect([result activeCount]).to.equal(@1);
        expect([result errorCount]).to.equal(@0);
        expect([result optoutCount]).to.equal(@1);
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
    
    it(@"deleteGroupID: should call endpoint", ^ {
        [[client deleteGroupID:@"123"] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"DELETE" path:@"/groups/123" body:nil];
    });
    
    it(@"deleteGroupID: should parse results", ^ {
        __block NSArray *result;
        
        endpoint.results = @[ [RACSignal return:@YES] ];
        
        [[client deleteGroupID:@"123"] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result).to.equal(@YES);
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
        expect(results[0]).to.equal(@"123");
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
        expect(results[0]).to.equal(@"123");
    });
    
    it(@"getMembersCountForMailingID: should call endpoint", ^ {
        [[client getMembersCountForMailingID:@"123"] subscribeCompleted:^ { }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/mailings/123/members"];
    });
    
    it(@"getMembersCountForMailingID: should parse results", ^ {
        __block NSArray *result;
        
        endpoint.results = @[ [RACSignal return:@3] ];
        
        [[client getMembersCountForMailingID:@"123"] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result).to.equal(@3);
    });
    
    it(@"getMembersForMailingID:inRange: should call endpoint", ^ {
        [[client getMembersForMailingID:@"123" inRange:(EMResultRange){ .start = 10, .end = 20}] subscribeCompleted:^ { }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/mailings/123/members?end=20&start=10"];
    });
    
    it(@"getMembersForMailingID:inRange: should parse results", ^ {
        
        __block NSArray *result;
        
        id mailingsDict = @{
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
                               mailingsDict
                               ]] ];
        
        [[client getMembersForMailingID:@"100" inRange:(EMResultRange){ .start = 10, .end = 20 }] subscribeNext:^(id x) {
            result = x;
        }];
    
        expect(result.count).to.equal(1);
        expect([result[0] ID]).to.equal(@"200");
        expect([result[0] email]).to.equal(@"emma@myemma.com");
        expect([result[0] status]).to.equal(EMMemberStatusActive);
        expect([result[0] memberSince]).to.equal([@"@D:2010-11-12T11:23:45" parseISO8601Timestamp]);
#warning TODO: memberFields
#warning TODO: fullName
    });
    
    it(@"getMailingWithID: should call endpoint", ^ {
        [[client getMailingWithID:@"321" ] subscribeCompleted:^ { }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/mailings/321"];
    });
    
    it(@"getMailingWithID: should parse results", ^ {
        
        __block EMMailing *result;
        
        id mailingsDict = @{
                                @"recipient_groups": @[
                                                        @{
                                                         @"member_group_id": @151,
                                                         @"name": @"Widget Buyers"
                                                        }
                                                     ],
                                @"heads_up_emails": @[],
                                @"send_started": [NSNull null],
                                @"signup_form_id": [NSNull null],
                                @"links": @[
                                            @{
                                              @"mailing_id": @200,
                                              @"plaintext": @NO,
                                              @"link_id": @200,
                                              @"link_name": @"Emma",
                                              @"link_target": @"http://www.myemma.com",
                                              @"link_order": @1
                                            }
                                          ],
                                @"mailing_id": @200,
                                @"plaintext": @"Hello [% member:first_name %]!",
                                @"recipient_count": @0,
                                @"public_webview_url": @"http://localhost/webview/uf/6db0cc7e6fdb2da589b65f29d90c96b6",
                                @"mailing_type": @"m",
                                @"parent_mailing_id": [NSNull null],
                                @"recipient_searches": @[],
                                @"account_id": @100,
                                @"recipient_members": @[
                                                        @{
                                                          @"email": @"emma@myemma.com",
                                                          @"member_id": @200
                                                        }
                                                      ], 
                                @"mailing_status": @"c",
                                @"sender": @"Kevin McConnell",
                                @"name": @"Sample Mailing",
                                @"send_finished": [NSNull null],
                                @"send_at": [NSNull null],
                                @"subject": @"Sample Mailing for [% member:first_name %] [% member:last_name %]",
                                @"archived_ts": [NSNull null],
                                @"html_body": @"<p>Hello [% member:first_name %]!</p>"
             };
        
        endpoint.results = @[ [RACSignal return:
                               mailingsDict
                               ] ];
        
        [[client getMailingWithID:@"321"] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect([result status]).to.equal(EMMailingStatusComplete);
        expect([result sender]).to.equal(@"Kevin McConnell");
        expect([result name]).to.equal(@"Sample Mailing");
        expect([result ID]).to.equal(@"200");
        expect([result recipientCount]).to.equal(@0);
        expect([result subject]).to.equal(@"Sample Mailing for [% member:first_name %] [% member:last_name %]");
        expect([result publicWebViewURL]).to.equal([NSURL URLWithString:@"http://localhost/webview/uf/6db0cc7e6fdb2da589b65f29d90c96b6"]);
    });
    
    it(@"getMessageToMemberID:forMailingID: should call endpoint", ^ {
        [[client getMessageToMemberID:@"123" forMailingID:@"321"] subscribeCompleted:^ { }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/mailings/321/messages/123"];
    });
    
    it(@"getMessageToMemberID:forMailingID: should parse results", ^ {
        
        __block EMMessage *result;
        
        id mailingsDict = @{
                                @"plaintext": @"Hello !",
                                @"subject": @"Sample Mailing for  ",
                                @"html_body": @"<p>Hello !</p>"
            };
        
        endpoint.results = @[ [RACSignal return:
                               mailingsDict
                               ] ];
        
        [[client getMessageToMemberID:@"123" forMailingID:@"321"] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect([result subject]).to.equal(@"Sample Mailing for  ");
        expect([result plaintext]).to.equal(@"Hello !");
        expect([result htmlBody]).to.equal(@"<p>Hello !</p>");
    });
    
    it(@"getGroupCountForMailingID: should call endpoint", ^ {
        [[client getGroupCountForMailingID:@"123"] subscribeCompleted:^ { }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/mailings/123/groups"];
    });
    
    it(@"getGroupCountForMailingID: should parse results", ^ {
        __block NSArray *result;
        
        endpoint.results = @[ [RACSignal return:@4] ];
        
        [[client getGroupCountForMailingID:@"123"] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result).to.equal(@4);
    });
    
    it(@"getGroupsForMailingID:inRange: should call endpoint", ^ {
        [[client getGroupsForMailingID:@"321" inRange:(EMResultRange){ .start = 10, .end = 20}] subscribeCompleted:^ { }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/mailings/321/groups?end=20&start=10"];
    });
    
    it(@"getGroupsForMailingID:inRange: should parse results", ^ {
        
        __block NSArray *result;
        
        id mailingsDict = @{
                                @"active_count": @2,
                                @"deleted_at": [NSNull null],
                                @"error_count": @0,
                                @"optout_count": @0,
                                @"group_type": @"g",
                                @"member_group_id": @151,
                                @"account_id": @100,
                                @"group_name": @"Widget Buyers"
        };
        
        endpoint.results = @[ [RACSignal return:@[
                               mailingsDict
                               ]] ];
        
        [[client getGroupsForMailingID:@"123" inRange:(EMResultRange){ .start = 10, .end = 20 }] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result.count).to.equal(1);
        expect([result[0] ID]).to.equal(@"151");
        expect([result[0] name]).to.equal(@"Widget Buyers");
        expect([result[0] activeCount]).to.equal(2);
        expect([result[0] errorCount]).to.equal(0);
        expect([result[0] optoutCount]).to.equal(0);
     });
    
    it(@"getSearchCountForMailingID: should call endpoint", ^ {
        [[client getSearchCountForMailingID:@"123"] subscribeCompleted:^ { }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/mailings/123/searches"];
    });
    
    it(@"getSearchCountForMailingID: should parse results", ^ {
        __block NSArray *result;
        
        endpoint.results = @[ [RACSignal return:@3] ];
        
        [[client getSearchCountForMailingID:@"123"] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result).to.equal(@3);
    });
    
    it(@"getSearchesForMailingID:inRange: should call endpoint", ^ {
        [[client getSearchesForMailingID:@"321" inRange:(EMResultRange){ .start = 10, .end = 20}] subscribeCompleted:^ { }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/mailings/321/searches?end=20&start=10"];
    });
    
    it(@"getSearchesForMailingID:inRange: should parse results", ^ {
        
        __block NSArray *result;
        
        id mailingsDict = @{
                            @"search_id": @200,
                            @"optout_count": @0,
                            @"error_count": @0,
                            @"name": @"Test Search",
                            @"criteria": @"[\"or\", [\"group\", \"eq\", \"Monthly Newsletter\"],[\"group\", \"eq\", \"Widget Buyers\"]]",
                            @"deleted_at": [NSNull null],
                            @"last_run_at": [NSNull null],
                            @"active_count": @0,
                            @"account_id": @100
        };
        
        endpoint.results = @[ [RACSignal return:@[
                               mailingsDict
                               ]] ];
        
        [[client getSearchesForMailingID:@"123" inRange:(EMResultRange){ .start = 10, .end = 20 }] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result.count).to.equal(1);
        expect([result[0] ID]).to.equal(@"200");
        expect([result[0] name]).to.equal(@"Test Search");
        expect([result[0] activeCount]).to.equal(@0);
        expect([result[0] optoutCount]).to.equal(@0);
        expect([result[0] errorCount]).to.equal(@0);
        expect([result[0] criteria]).to.equal(@"[\"or\", [\"group\", \"eq\", \"Monthly Newsletter\"],[\"group\", \"eq\", \"Widget Buyers\"]]");
    });
    
    void (^updateMailingTestCallsEndpointWithMailingStatus)(EMMailingStatus status, NSString *statusString) = ^ (EMMailingStatus status, NSString *statusString) {
        [[client updateMailingID:@"123" withStatus:status] subscribeCompleted:^ { }];
        [endpoint expectRequestWithMethod:@"PUT" path:@"/mailings/123" body:@{ @"mailing_status": statusString }];
    };
    
    it(@"updateMailingID:withStatus: should call endpoint", ^ {        
        updateMailingTestCallsEndpointWithMailingStatus(EMMailingStatusComplete, @"c");
    });
    
    it(@"updateMailingID:withStatus: should parse results", ^ {
        updateMailingTestCallsEndpointWithMailingStatus(EMMailingStatusPaused, @"a");
    });

    it(@"updateMailingID:withStatus: should parse results", ^ {
        __block NSArray *result;
        
        endpoint.results = @[ [RACSignal return:@"c"] ];
        
        [[client updateMailingID:@"123" withStatus:EMMailingStatusComplete] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result).to.equal(@"c");
    });
    
    it(@"archiveMailingID: should call endpoint", ^ {
        [[client archiveMailingID:@"123"] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"DELETE" path:@"/mailings/123" body:nil];
    });
    
    it(@"archiveMailingID: should parse results", ^ {
        __block NSArray *result;
        
        endpoint.results = @[ [RACSignal return:@YES] ];
        
        [[client archiveMailingID:@"123"] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result).to.equal(@YES);
    });
    
    it(@"cancelMailingID: should call endpoint", ^ {
        [[client cancelMailingID:@"123"] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"DELETE" path:@"/mailings/cancel/123" body:nil];
    });
    
    it(@"cancelMailingID: should parse results", ^ {
        __block NSArray *result;
        
        endpoint.results = @[ [RACSignal return:@YES] ];
        
        [[client cancelMailingID:@"123"] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result).to.equal(@YES);
    });
    
    it(@"getHeadsupAddressesForMailingID: should call endpoint", ^ {
        [[client getHeadsupAddressesForMailingID:@"321"] subscribeCompleted:^ { }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/mailings/321/headsup"];
    });
    
    it(@"getHeadsupAddressesForMailingID: should parse results", ^ {
        __block NSArray *result;
        
        id emails = @[@"testemail@test.com", @"coolemail@email.com"];
        
        endpoint.results = @[ [RACSignal return:@[emails]] ];
        
        [[client getHeadsupAddressesForMailingID:@"123"] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result.count).to.equal(1);
        expect(result[0]).to.equal(emails);
    });
    
    it(@"declareWinnerID:forMailingID: should call endpoint", ^ {
        [[client declareWinnerID:@"100" forMailingID:@"321"] subscribeCompleted:^ { }];
        [endpoint expectRequestWithMethod:@"POST" path:@"/mailings/321/winner/100"];
    });
    
    it(@"declareWinnerID:forMailingID: should parse results", ^ {
        
        __block NSArray *result;
        
        endpoint.results = @[ [RACSignal return:@YES] ];
        
        [[client declareWinnerID:@"100" forMailingID:@"321"] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result).to.equal(@YES);
    });
    
    it(@"forwardMailingID:fromMemberID:toRecipients:withNote: should call endpoint", ^ {
        [[client forwardMailingID:@"123" fromMemberID:@"321" toRecipients:@[@"firstemail@test.com", @"another@email.com"] withNote:@"This is a note"] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"POST"
                                     path:@"/forwards/123/321"
                                     body:@{@"recipient_emails": @[@"firstemail@test.com", @"another@email.com" ], @"note" : @"This is a note"}];
    });
    
    it(@"forwardMailingID:fromMemberID:toRecipients:withNote: should parse results", ^ {
        
        __block NSArray *result;
        
        id mailingsDict = @{
            @"mailing_id": @1024
        };
        
        endpoint.results = @[ [RACSignal return:@[
                               mailingsDict
                               ]] ];
        
        [[client forwardMailingID:@"123" fromMemberID:@"321" toRecipients:@[@"firstemail@test.com", @"another@email.com" ] withNote:@"This is a note"] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result.count).to.equal(1);
        expect(result[0]).to.equal(mailingsDict);
    });
    
    it(@"validateMailingWithBody:plaintext:andSubject: should call endpoint", ^ {
        [[client validateMailingWithBody:@"<html>super cool email</html>" plaintext:@"super cool email" andSubject:@"interesting subject"] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"POST"
                                     path:@"/mailings/validate"
                                     body:@{@"html_body": @"<html>super cool email</html>", @"plaintext" : @"super cool email", @"subject" : @"interesting subject"}];
    });
    
    it(@"validateMailingWithBody:plaintext:andSubject: should parse results", ^ {
        
        __block NSArray *result;
        
        endpoint.results = @[ [RACSignal return:@[
                               @YES
                               ]] ];
        
        [[client validateMailingWithBody:@"<html>super cool email</html>" plaintext:@"super cool email" andSubject:@"interesting subject"] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result.count).to.equal(1);
        expect(result[0]).to.equal(@YES);
    });

    it(@"getMemberCountIncludeDeleted: should call endpoint with deleted", ^ {
        [[client getMemberCountIncludeDeleted:YES] subscribeCompleted:^ { }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/members?deleted=true"];
    });
    
    it(@"getMemberCountIncludeDeleted: should call endpoint without deleted", ^ {
        [[client getMemberCountIncludeDeleted:NO] subscribeCompleted:^ { }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/members?deleted=false"];
    });
    
    it(@"getMemberCountIncludeDeleted: should parse results", ^ {
        __block NSArray *result;
        
        endpoint.results = @[ [RACSignal return:@3] ];
        
        [[client getMemberCountIncludeDeleted:YES] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result).to.equal(@3);
    });
    
    it(@"getMembersInRange: should call endpoint with deleted", ^ {
        [[client getMembersInRange:(EMResultRange){ .start = 10, .end = 20 } includeDeleted:YES] subscribeCompleted:^ { }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/members?deleted=true&end=20&start=10" body:nil];
    });
    
    it(@"getMembersInRange: should call endpoint without deleted", ^ {
        [[client getMembersInRange:(EMResultRange){ .start = 10, .end = 20 } includeDeleted:NO] subscribeCompleted:^ { }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/members?deleted=false&end=20&start=10" body:nil];
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
        
        [[client getMembersInRange:(EMResultRange){ .start = 10, .end = 20 } includeDeleted:YES] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result.count).to.equal(1);
        expect([result[0] ID]).to.equal(@"200");
        expect([result[0] email]).to.equal(@"emma@myemma.com");
        expect([result[0] status]).to.equal(EMMemberStatusActive);
    });
    
    void (^testCopyMembersWithStatusCallsEndpointWithMemberStatus)(EMMemberStatus status, NSString *statusString) = ^ (EMMemberStatus status, NSString *statusString) {
        [[client copyMembersWithStatus:status fromGroupID:@"123" toGroupID:@"321"] subscribeCompleted:^ { }];
        [endpoint expectRequestWithMethod:@"PUT" path:@"/groups/123/321/members/copy" body:@{ @"member_status_id": @[statusString] }];
    };

    it(@"copyMembersWithStatus:fromGroupID:toGroupID: should call endpoint with active", ^ {
        testCopyMembersWithStatusCallsEndpointWithMemberStatus(EMMemberStatusActive, EMMemberStatusGetShortName(EMMemberStatusActive));
    });
    
    it(@"copyMembersWithStatus:fromGroupID:toGroupID: should call endpoint with optout", ^ {
        testCopyMembersWithStatusCallsEndpointWithMemberStatus(EMMemberStatusOptout, EMMemberStatusGetShortName(EMMemberStatusOptout));
    });
    
    it(@"copyMembersWithStatus:fromGroupID:toGroupID: should call endpoint with active", ^ {
        testCopyMembersWithStatusCallsEndpointWithMemberStatus(EMMemberStatusError, EMMemberStatusGetShortName(EMMemberStatusError));
    });
    
    it(@"copyMembersWithStatus:fromGroupID:toGroupID: should parse results", ^ {
        __block NSArray *result;
        
        endpoint.results = @[ [RACSignal return:@YES] ];
        
        [[client copyMembersWithStatus:EMMemberStatusActive fromGroupID:@"123" toGroupID:@"321"] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result).to.equal(@YES);
    });
    
    void (^testRemoveMembersWithStatusCallsEndpointWithMemberStatus)(EMMemberStatus status, NSString *statusString) = ^ (EMMemberStatus status, NSString *statusString) {
        [[client removeMembersWithStatus:status fromGroupID:@"123"] subscribeCompleted:^ { }];
        [endpoint expectRequestWithMethod:@"DELETE" path:[NSString stringWithFormat:@"/groups/123/members/remove?member_status_id=%@", statusString]];
    };
    
    it(@"removeMembersWithStatus:fromGroupID: should call endpoint with active", ^ {
        testRemoveMembersWithStatusCallsEndpointWithMemberStatus(EMMemberStatusActive, EMMemberStatusGetShortName(EMMemberStatusActive));
    });
    
    it(@"removeMembersWithStatus:fromGroupID: should call endpoint with optout", ^ {
        testRemoveMembersWithStatusCallsEndpointWithMemberStatus(EMMemberStatusOptout, EMMemberStatusGetShortName(EMMemberStatusOptout));
    });
    
    it(@"removeMembersWithStatus:fromGroupID: should call endpoint with active", ^ {
        testRemoveMembersWithStatusCallsEndpointWithMemberStatus(EMMemberStatusError, EMMemberStatusGetShortName(EMMemberStatusError));
    });
    
    it(@"removeMembersWithStatus:fromGroupID: should parse results", ^ {
        __block NSArray *result;
        
        endpoint.results = @[ [RACSignal return:@YES] ];
        
        [[client removeMembersWithStatus:EMMemberStatusActive fromGroupID:@"123"] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result).to.equal(@YES);
    });
    
    it(@"resendMailingID:headsUpAddresses:recipientAddresses:recipientGroupIDs:recipientSearchIDs: should call endpoint", ^ {
        [[client resendMailingID:@"123" headsUpAddresses:@[@"one@test.com", @"two@test.com"] recipientAddresses:@[@"three@test.com", @"four@test.com"] recipientGroupIDs:@[@"123", @"321"] recipientSearchIDs:@[@"543", @"345"]] subscribeCompleted:^ { }];
        
        id body = @{
        @"heads_up_emails" : @[@"one@test.com", @"two@test.com"],
        @"recipient_emails" : @[@"three@test.com", @"four@test.com"],
        @"recipient_groups" : @[@"123", @"321"],
        @"recipient_searches" : @[@"543", @"345"]
        };
        
        [endpoint expectRequestWithMethod:@"POST" path:@"/mailings/123" body:body];
    });
    
    it(@"resendMailingID:headsUpAddresses:recipientAddresses:recipientGroupIDs:recipientSearchIDs: should parse results", ^ {
        __block NSString *result;
        
        endpoint.results = @[ [RACSignal return:@1024] ];
        
        [[client resendMailingID:@"123" headsUpAddresses:@[@"hdsup@test.com"] recipientAddresses:@[@"recip@ient.com"] recipientGroupIDs:@[@"321"] recipientSearchIDs:@[@"432"]] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result).to.equal(@"1024");
    });
    
    it(@"getFieldCount: should call endpoint", ^ {
        [[client getFieldCount] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/fields" body:nil];
    });
    
    it(@"getFieldCount: should parse results", ^ {
        __block NSArray *result;
        
        endpoint.results = @[ [RACSignal return:@6] ];
        
        [[client getFieldCount] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result).to.equal(@6);
    });
    
    it(@"getFieldsInRange: should call endpoint", ^ {
        [[client getFieldsInRange:(EMResultRange){ .start = 10, .end = 20 }] subscribeCompleted:^ { }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/fields?end=20&start=10" body:nil];
    });
    
    it(@"getFieldsInRange: should parse results", ^ {
        __block NSArray *result;
        
        endpoint.results = @[ [RACSignal return:@[
                               @{
                                    @"shortcut_name": @"first_name",
                                    @"display_name": @"First Name",
                                    @"account_id": @100,
                                    @"field_type": @"text",
                                    @"required": @NO,
                                    @"field_id": @200,
                                    @"widget_type": @"text",
                                    @"short_display_name": [NSNull null],
                                    @"column_order": @1,
                                    @"deleted_at": [NSNull null],
                                    @"options": [NSNull null]
                                }
                               ]] ];
        
        [[client getFieldsInRange:(EMResultRange){ .start = 10, .end = 20 }] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result.count).to.equal(1);
        expect([result[0] name]).to.equal(@"first_name");
        expect([result[0] displayName]).to.equal(@"First Name");
        expect([result[0] fieldType]).to.equal(EMFieldTypeText);
        expect([result[0] widgetType]).to.equal(EMFieldWidgetTypeText);
    });
    
    it(@"getFieldID: should call endpoint", ^ {
        [[client getFieldID:@"321"] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/fields/321" body:nil];
    });
    
    it(@"getFieldID: should parse results", ^ {
        __block EMField *result;
        
        id dict = @{
            @"shortcut_name": @"first_name",
            @"display_name": @"First Name",
            @"account_id": @100,
            @"field_type": @"text",
            @"required": @NO,
            @"field_id": @200,
            @"widget_type": @"text",
            @"short_display_name": [NSNull null],
            @"column_order": @1,
            @"deleted_at": [NSNull null],
            @"options": [NSNull null]
        };
        
        endpoint.results = @[ [RACSignal return:
                               dict
                               ] ];
        
        [[client getFieldID:@"123"] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect([result name]).to.equal(@"first_name");
        expect([result displayName]).to.equal(@"First Name");
        expect([result fieldType]).to.equal(EMFieldTypeText);
        expect([result widgetType]).to.equal(EMFieldWidgetTypeText);
        expect([result fieldID]).to.equal(@"200");

    });
    
    it(@"createField: should call endpoint", ^ {
        
        EMField *field = [[EMField alloc] init];
        field.fieldID = @"123";
        field.name = @"first_name";
        field.displayName = @"First Name";
        field.fieldType = EMFieldTypeText;
        field.widgetType = EMFieldWidgetTypeText;
        field.columnOrder = 3;
        
        [[client createField:field] subscribeCompleted:^ {}];
        [endpoint expectRequestWithMethod:@"POST" path:@"/fields" body:@{
         @"field_id" : @"123",
         @"shortcut_name" : @"first_name",
         @"display_name" : @"First Name",
         @"field_type" : @"text",
         @"widget_type" : @"text",
         @"column_order" : @3
         }];
    });
    
    it(@"createField: should parse results", ^ {
        __block NSString *result;
        
        endpoint.results = @[ [RACSignal return:@123 ] ];
        
        EMField *field = [[EMField alloc] init];
        field.fieldID = @"123";
        field.name = @"first_name";
        field.displayName = @"First Name";
        field.fieldType = EMFieldTypeText;
        field.widgetType = EMFieldWidgetTypeText;
        field.columnOrder = 3;
        
        [[client createField:field] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result).to.equal(@"123");
    });
    
    it(@"deleteFieldID: should call endpoint", ^ {
        [[client deleteFieldID:@"123"] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"DELETE" path:@"/fields/123" body:nil];
    });
    
    it(@"deleteFieldID: should parse results", ^ {
        __block NSArray *result;
        
        endpoint.results = @[ [RACSignal return:@YES] ];
        
        [[client deleteFieldID:@"123"] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result).to.equal(@YES);
    });
    
    it(@"clearFieldID: should call endpoint", ^ {
        [[client clearFieldID:@"123"] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"POST" path:@"/fields/123/clear" body:nil];
    });
    
    it(@"clearFieldID: should parse results", ^ {
        __block NSArray *result;
        
        endpoint.results = @[ [RACSignal return:@YES] ];
        
        [[client clearFieldID:@"123"] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result).to.equal(@YES);
    });
    
    it(@"updateField: should call endpoint", ^ {
        
        EMField *field = [[EMField alloc] init];
        field.fieldID = @"123";
        field.name = @"first_name";
        field.displayName = @"First Name";
        field.fieldType = EMFieldTypeText;
        field.widgetType = EMFieldWidgetTypeText;
        field.columnOrder = 3;
        
        [[client updateField:field] subscribeCompleted:^ {}];
        [endpoint expectRequestWithMethod:@"PUT" path:@"/fields/123" body:@{
         @"field_id" : @"123",
         @"shortcut_name" : @"first_name",
         @"display_name" : @"First Name",
         @"field_type" : @"text",
         @"widget_type" : @"text",
         @"column_order" : @3
         }];
    });
    
    it(@"updateField: should parse results", ^ {
        __block NSString *result;
        
        endpoint.results = @[ [RACSignal return:@123 ] ];
        
        EMField *field = [[EMField alloc] init];
        field.fieldID = @"123";
        field.name = @"first_name";
        field.displayName = @"First Name";
        field.fieldType = EMFieldTypeText;
        field.widgetType = EMFieldWidgetTypeText;
        field.columnOrder = 3;
        
        [[client updateField:field] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result).to.equal(@"123");
    });

    it(@"getWebhookCount should call endpoint", ^ {
        [[client getWebhookCount] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/webhooks?count=true"];
    });
    
    it(@"getWebhookCount should parse result", ^ {
        endpoint.results = @[ [RACSignal return:@123] ];
        
        __block NSNumber *result;
        
        [[client getWebhookCount] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result).to.equal(@123);
    });
    
    it(@"getWebhooksInRange: should call endpoint", ^ {
        [[client getWebhooksInRange:EMResultRangeMake(10, 20)] subscribeCompleted:^{}];
        [endpoint expectRequestWithMethod:@"GET" path:@"/webhooks?end=20&start=10"];
    });
    
    it(@"getWebhooksInRange: should parse results", ^ {
        endpoint.results = @[ [RACSignal return:@[@{
                                   @"url": @"http://myemma.com",
                                   @"webhook_id": @100,
                                   @"method": @"POST",
                                   @"account_id": @100,
                                   @"event": @"mailing_finish"
                               },
                               @{
                                   @"url": @"http://tech.myemma.com",
                                   @"webhook_id": @101,
                                   @"method": @"POST",
                                   @"account_id": @100,
                                   @"event": @"mailing_finish"
                               }]] ];
        
        __block NSArray *result;
        
        [[client getWebhooksInRange:EMResultRangeAll] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result.count).to.equal(2);
        expect([result[0] url]).to.equal([NSURL URLWithString:@"http://myemma.com"]);
        expect([result[0] webhookID]).to.equal(@"100");
        expect([result[0] method]).to.equal(@"POST");
        expect([result[0] event]).to.equal(@"mailing_finish");
        expect([result[1] url]).to.equal([NSURL URLWithString:@"http://tech.myemma.com"]);
        expect([result[1] webhookID]).to.equal(@"101");
        expect([result[1] method]).to.equal(@"POST");
        expect([result[1] event]).to.equal(@"mailing_finish");
    });
    
    it(@"getWebhookEvents should call endpoint", ^ {
        [[client getWebhookEvents] subscribeCompleted:^ {}];
        [endpoint expectRequestWithMethod:@"GET" path:@"/webhooks/events"];
    });
    
    it(@"getWebhookEvents should parse results", ^{
        endpoint.results = @[ [RACSignal return:@[
        @{
            @"event_name": @"mailing_finish",
            @"webhook_event_id": @1,
            @"description": @"Fired when a mailing is finished."
        },
        @{
            @"event_name": @"mailing_start",
            @"webhook_event_id": @2,
            @"description": @"Fired when a mailing starts."
        },
        @{
            @"event_name": @"member_signup",
            @"webhook_event_id": @3,
            @"description": @"Fired when a member signs up through a signup form."
        } ] ] ];
        
        __block NSArray *result;
        
        [[client getWebhookEvents] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result.count).to.equal(3);
        expect([result[0] eventName]).to.equal(@"mailing_finish");
        expect([result[0] webhookEventID]).to.equal(@"1");
        expect([result[0] webhookDescription]).to.equal(@"Fired when a mailing is finished.");
        expect([result[1] eventName]).to.equal(@"mailing_start");
        expect([result[1] webhookEventID]).to.equal(@"2");
        expect([result[1] webhookDescription]).to.equal(@"Fired when a mailing starts.");
        expect([result[2] eventName]).to.equal(@"member_signup");
        expect([result[2] webhookEventID]).to.equal(@"3");
        expect([result[2] webhookDescription]).to.equal(@"Fired when a member signs up through a signup form.");
    });
    
    it(@"createWebhook:withPublicKey: should call endpoint", ^ {
        EMWebhook *webhook = [[EMWebhook alloc] init];
        webhook.url = [NSURL URLWithString:@"http://my.cool.website.tld/poast"];
        webhook.method = @"POST";
        webhook.event = @"member_signup";
        [[client createWebhook:webhook withPublicKey:nil] subscribeCompleted:^{}];
        
        [endpoint expectRequestWithMethod:@"POST" path:@"/webhooks" body:@{
         @"url": @"http://my.cool.website.tld/poast",
         @"method": @"POST",
         @"event": @"member_signup"
         }];
    });
    
    it(@"createWebhook:withPublicKey: should call endpoint with public key", ^ {
        EMWebhook *webhook = [[EMWebhook alloc] init];
        webhook.url = [NSURL URLWithString:@"http://my.cool.website.tld/poast"];
        webhook.method = @"POST";
        webhook.event = @"member_signup";
        [[client createWebhook:webhook withPublicKey:@"foobs"] subscribeCompleted:^{}];
        
        [endpoint expectRequestWithMethod:@"POST" path:@"/webhooks" body:@{
         @"url": @"http://my.cool.website.tld/poast",
         @"method": @"POST",
         @"event": @"member_signup",
         @"public_key": @"foobs"
         }];
    });
    
    it(@"createWebhook:withPublicKey: should parse results", ^ {
        endpoint.results = @[ [RACSignal return:@1024] ];
        __block NSString *result;
        [[client createWebhook:nil withPublicKey:nil] subscribeNext:^(id x) {
            result = x;
        }];
        expect(result).to.equal(@"1024");
    });
    
    it(@"updateWebhook: should call endpoint", ^ {
        EMWebhook *webhook = [[EMWebhook alloc] init];
        webhook.url = [NSURL URLWithString:@"http://my.cool.website.tld/poast"];
        webhook.method = @"POST";
        webhook.event = @"member_signup";
        webhook.webhookID = @"999888";
        [[client updateWebhook:webhook] subscribeCompleted:^ { }];
        [endpoint expectRequestWithMethod:@"PUT" path:@"/webhooks/999888" body:@{
            @"url": @"http://my.cool.website.tld/poast",
            @"method": @"POST",
            @"event": @"member_signup"
        }];
    });
    
    it(@"updateWebhook: should parse results", ^ {
        endpoint.results = @[ [RACSignal return:@100] ];
        __block NSString *result;
        [[client updateWebhook:nil] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result).to.equal(@"100");
    });
    
    it(@"deleteWebhookWithID: should call endpoint", ^ {
        [[client deleteWebhookWithID:@"1234"] subscribeCompleted:^ {}];
        [endpoint expectRequestWithMethod:@"DELETE" path:@"/webhooks/1234"];
    });
    
    it(@"deleteWebhookWithID: should parse results", ^ {
        endpoint.results = @[[RACSignal return:@YES] ];
        __block NSNumber *result;
        [[client deleteWebhookWithID:@"1234"] subscribeNext:^(id x) {
            result = x;
        }];
        expect(result).to.equal(@YES);
    });
    
    it(@"deleteAllWebhooks: should call endpoint", ^ {
        [[client deleteAllWebhooks] subscribeCompleted:^ {}];
        [endpoint expectRequestWithMethod:@"DELETE" path:@"/webhooks"];
    });
    
    it(@"deleteAllWebhooks: should parse results", ^ {
        endpoint.results = @[ [RACSignal return:@YES] ];
        __block NSNumber *result;
        [[client deleteAllWebhooks] subscribeNext:^(id x) {
            result = x;
        }];
        expect(result).to.equal(@YES);
    });
    
    it(@"getSearchCount: should call endpoint", ^ {
        [[client getSearchCount] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/searches" body:nil];
    });
    
    it(@"getSearchCount: should parse results", ^ {
        __block NSArray *result;
        
        endpoint.results = @[ [RACSignal return:@6] ];
        
        [[client getSearchCount] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result).to.equal(@6);
    });
    
    it(@"getSearchesInRange: should call endpoint", ^ {
        [[client getSearchesInRange:(EMResultRange){ .start = 10, .end = 20 }] subscribeCompleted:^ { }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/searches?end=20&start=10" body:nil];
    });
    
    it(@"getSearchesInRange: should parse results", ^ {
        __block NSArray *result;
        
        endpoint.results = @[ [RACSignal return:@[
                               @{
                                    @"search_id": @201,
                                    @"optout_count": @0,
                                    @"error_count": @0,
                                    @"name": @"Second Test Search",
                                    @"criteria": @"[\"group\", \"eq\", \"Special Events\"]",
                                    @"deleted_at": [NSNull null],
                                    @"last_run_at": [NSNull null],
                                    @"active_count": @0,
                                    @"account_id": @100
                               }
                               ]] ];
        
        [[client getSearchesInRange:(EMResultRange){ .start = 10, .end = 20 }] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result.count).to.equal(1);
        expect([result[0] ID]).to.equal(@"201");
        expect([result[0] name]).to.equal(@"Second Test Search");
        expect([result[0] criteria]).to.equal(@"[\"group\", \"eq\", \"Special Events\"]");
        expect([result[0] activeCount]).to.equal(0);
        expect([result[0] optoutCount]).to.equal(0);
        expect([result[0] errorCount]).to.equal(0);
    });
    
    it(@"getSearchID: should call endpoint", ^ {
        [[client getSearchID:@"321"] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/searches/321" body:nil];
    });
    
    it(@"getSearchID: should parse results", ^ {
        __block EMSearch *result;
        
        id dict = @{
        @"search_id": @200,
        @"optout_count": @1,
        @"error_count": @0,
        @"name": @"Test Search",
        @"criteria": @"[\"or\", [\"group\", \"eq\", \"Monthly Newsletter\"],[\"group\", \"eq\", \"Widget Buyers\"]]",
        @"deleted_at": [NSNull null],
        @"last_run_at": @"@D:2013-03-20T14:21:44",
        @"active_count": @2,
        @"account_id": @100
        };
        endpoint.results = @[ [RACSignal return:
                               dict
                               ] ];
        
        [[client getSearchID:@"150"] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect([result ID]).to.equal(@"200");
        expect([result name]).to.equal(@"Test Search");
        expect([result criteria]).to.equal(@"[\"or\", [\"group\", \"eq\", \"Monthly Newsletter\"],[\"group\", \"eq\", \"Widget Buyers\"]]");
        expect([result activeCount]).to.equal(2);
        expect([result optoutCount]).to.equal(1);
        expect([result errorCount]).to.equal(0);
        expect([result lastRunAt]).to.equal([@"@D:2013-03-20T14:21:44" parseISO8601Timestamp]);
    });
    
    it(@"createSearch: should call endpoint", ^ {
    
        EMSearch *search = [[EMSearch alloc] init];
        search.ID = @"123";
        search.name = @"A Search";
        search.criteria = @"[\"or\", [\"group\", \"eq\", \"Monthly Newsletter\"],[\"group\", \"eq\", \"Widget Buyers\"]]";
        
        [[client createSearch:search] subscribeCompleted:^ {}];
        [endpoint expectRequestWithMethod:@"POST" path:@"/searches" body:@{
         @"search_id" : @"123",
         @"name" : @"A Search",
         @"criteria" : @"[\"or\", [\"group\", \"eq\", \"Monthly Newsletter\"],[\"group\", \"eq\", \"Widget Buyers\"]]",
         }];
    });
    
    it(@"createSearch: should parse results", ^ {
        __block NSString *result;
        
        endpoint.results = @[ [RACSignal return:@123 ] ];
        
        EMSearch *search = [[EMSearch alloc] init];
        search.ID = @"123";
        search.name = @"A Search";
        search.criteria = @"[\"or\", [\"group\", \"eq\", \"Monthly Newsletter\"],[\"group\", \"eq\", \"Widget Buyers\"]]";
        
        [[client createSearch:search] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result).to.equal(@"123");
    });
    
    it(@"updateSearch: should call endpoint", ^ {
        
        
        EMSearch *search = [[EMSearch alloc] init];
        search.ID = @"123";
        search.name = @"A Cool Search";
        search.criteria = @"[\"or\", [\"group\", \"eq\", \"Monthly Newsletter\"],[\"group\", \"eq\", \"Widget Buyers\"]]";

        [[client updateSearch:search] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"PUT" path:@"/searches/123" body:@{ @"name": @"A Cool Search", @"criteria" : @"[\"or\", [\"group\", \"eq\", \"Monthly Newsletter\"],[\"group\", \"eq\", \"Widget Buyers\"]]"}];
    });
    
    it(@"updateSearch: should parse results", ^ {
        __block NSNumber *result;
        
        endpoint.results = @[ [RACSignal return:@YES] ];
        
        EMSearch *search = [[EMSearch alloc] init];
        search.ID = @"123";
        search.name = @"A Cool Search";
        search.criteria = @"[\"or\", [\"group\", \"eq\", \"Monthly Newsletter\"],[\"group\", \"eq\", \"Widget Buyers\"]]";
        
        [[client updateSearch:search] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result).to.equal(@YES);
    });
    
    it(@"deleteSearchID: should call endpoint", ^ {
        [[client deleteSearchID:@"123"] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"DELETE" path:@"/searches/123" body:nil];
    });
    
    it(@"deleteSearchID: should parse results", ^ {
        __block NSArray *result;
        
        endpoint.results = @[ [RACSignal return:@YES] ];
        
        [[client deleteSearchID:@"123"] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result).to.equal(@YES);
    });
    
    it(@"getMemberCountInSearchID: should call endpoint", ^ {
        [[client getMemberCountInSearchID:@"123"] subscribeCompleted:^ { }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/searches/123/members"];
    });
    
    it(@"getMemberCountInSearchID: should parse results", ^ {
        __block NSArray *result;
        
        endpoint.results = @[ [RACSignal return:@3] ];
        
        [[client getMemberCountInSearchID:@"123"] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result).to.equal(@3);
    });
    
    it(@"getMembersInSearchID:inRange: should call endpoint", ^ {
        [[client getMembersInSearchID:@"123" inRange:(EMResultRange){ .start = 10, .end = 20 }] subscribeCompleted:^ { }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/searches/123/members?end=20&start=10" body:nil];
    });
    
    it(@"getMembersInSearchID:inRange: should parse results", ^ {
        __block NSArray *result;
        
        id memberDict0 = @{
        @"status": @"opt-out",
        @"confirmed_opt_in": [NSNull null],
        @"account_id": @100,
        @"fields": @{
            @"first_name": @"Gladys",
            @"last_name": @"Jones",
            @"favorite_food": @"toast"
        },
        @"member_id": @201,
        @"last_modified_at": [NSNull null],
        @"member_status_id": @"o",
        @"plaintext_preferred": @NO,
        @"email_error": [NSNull null],
        @"member_since": @"@D:2011-01-03T15:54:13",
        @"bounce_count": @0,
        @"deleted_at": [NSNull null],
        @"email": @"gladys@myemma.com"

        };
        endpoint.results = @[ [RACSignal return:@[
                               memberDict0
                               ]] ];
        
        [[client getMembersInSearchID:@"123" inRange:(EMResultRange){ .start = 10, .end = 20 }] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result.count).to.equal(1);
        expect([result[0] ID]).to.equal(@"201");
        expect([result[0] email]).to.equal(@"gladys@myemma.com");
    });
    
    it(@"getMemberWithID: should call endpoint", ^ {
        [[client getMemberWithID:@"321"] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/members/321" body:nil];
    });
    
    it(@"getMemberWithID: should parse results", ^ {
        __block EMMember *result;
        
        id memberDict0 = @{
            @"status": @"opt-out",
            @"confirmed_opt_in": [NSNull null],
            @"account_id": @100,
            @"fields": @{
            @"first_name": @"Gladys",
            @"last_name": @"Jones",
            @"favorite_food": @"toast"
            },
            @"member_id": @201,
            @"last_modified_at": [NSNull null],
            @"member_status_id": @"o",
            @"plaintext_preferred": @NO,
            @"email_error": [NSNull null],
            @"member_since": @"@D:2011-01-03T15:54:13",
            @"bounce_count": @0,
            @"deleted_at": [NSNull null],
            @"email": @"gladys@myemma.com"

        };
        endpoint.results = @[ [RACSignal return:
                               memberDict0
                               ] ];
        
        [[client getMemberWithID:@"201"] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect([result ID]).to.equal(@"201");
        expect([result email]).to.equal(@"gladys@myemma.com");
        expect([result memberSince]).to.equal([@"@D:2011-01-03T15:54:13" parseISO8601Timestamp]);
        expect([result status]).to.equal(EMMemberStatusOptout);
    });
    
    it(@"getMemberWithEmail: should call endpoint", ^ {
        [[client getMemberWithEmail:@"super@email.com"] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/members/email/super@email.com" body:nil];
    });
    
    it(@"getMemberWithEmail: should parse results", ^ {
        __block EMMember *result;
        
        id memberDict0 = @{
            @"status": @"opt-out",
            @"confirmed_opt_in": [NSNull null],
            @"account_id": @100,
            @"fields": @{
            @"first_name": @"Gladys",
            @"last_name": @"Jones",
            @"favorite_food": @"toast"
            },
            @"member_id": @201,
            @"last_modified_at": [NSNull null],
            @"member_status_id": @"o",
            @"plaintext_preferred": @NO,
            @"email_error": [NSNull null],
            @"member_since": @"@D:2011-01-03T15:54:13",
            @"bounce_count": @0,
            @"deleted_at": [NSNull null],
            @"email": @"gladys@myemma.com"
        };
        endpoint.results = @[ [RACSignal return:
                               memberDict0
                               ] ];
        
        [[client getMemberWithEmail:@"gladys@myemma.com"] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect([result ID]).to.equal(@"201");
        expect([result email]).to.equal(@"gladys@myemma.com");
        expect([result memberSince]).to.equal([@"@D:2011-01-03T15:54:13" parseISO8601Timestamp]);
        expect([result status]).to.equal(EMMemberStatusOptout);
    });
    
    it(@"getOptoutInfoForMemberID: should call endpoint", ^ {
        [[client getOptoutInfoForMemberID:@"123"] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/members/123/optout" body:nil];
    });
    
    it(@"getOptoutInfoForMemberID: should parse results", ^ {
        __block id result;
    
        endpoint.results = @[ [RACSignal return:
                               @"opt out info"
                               ] ];
        
        [[client getOptoutInfoForMemberID:@"123"] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result).to.equal(@"opt out info");
    });
    
    it(@"optoutMemberWithEmail: should call endpoint", ^ {
        [[client optoutMemberWithEmail:@"some@email.com"] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"PUT" path:@"/members/email/optout/some@email.com" body:nil];
    });
    
    it(@"optoutMemberWithEmail: should parse results", ^ {
        __block id result;
        
        endpoint.results = @[ [RACSignal return:
                               @YES
                               ] ];
        
        [[client optoutMemberWithEmail:@"test@email.com"] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result).to.equal(@YES);
    });
    
    it(@"createMembers:withSourceName:addOnly:groupIDs: should call endpoint", ^ {
        EMMember *firstMember = [[EMMember alloc] init];
        firstMember.email = @"first@email.com";
        
        EMMember *secondMember = [[EMMember alloc] init];
        secondMember.email = @"second@email.com";
        
        [[client createMembers:@[firstMember, secondMember] withSourceName:@"source name" addOnly:YES groupIDs:@[@"123", @"234"]] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"POST" path:@"/members" body:@{@"members" : @[ @{@"email" : @"first@email.com"}, @{@"email" : @"second@email.com"} ], @"source_filename" : @"source name", @"add_only" : @YES, @"group_ids" : @[@"123", @"234"]}];
    });
    
    it(@"createMembers:withSourceName:addOnly:groupIDs: should parse results", ^ {
        __block id result;
        
        endpoint.results = @[ [RACSignal return:
                               @{@"import_id" : @1234}
                               ] ];
        
        EMMember *firstMember = [[EMMember alloc] init];
        firstMember.email = @"first@email.com";
        EMMember *secondMember = [[EMMember alloc] init];
        secondMember.email = @"second@email.com";
        
        [[client createMembers:@[firstMember, secondMember] withSourceName:@"source name" addOnly:YES groupIDs:@[@"123", @"234"]] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result).to.equal(@"1234");
    });
    
    __block id clientResult;
    void (^SetEndpointResult)(id) = ^ (id endpointResult) {
        endpoint.results = @[ [RACSignal return:endpointResult] ];
    };
    void (^EvaluateSignal)(RACSignal *) = ^ (RACSignal *signal) {
        [signal subscribeNext:^(id x) {
            clientResult = x;
        } completed:^ {}];
    };
    
    it(@"getTriggerCount should call endpoint", ^ {
        EvaluateSignal([client getTriggerCount]);
        [endpoint expectRequestWithMethod:@"GET" path:@"/triggers?count=true"];
    });
    
    it(@"getTriggerCount should parse results", ^ {
        SetEndpointResult(@123);
        EvaluateSignal([client getTriggerCount]);
        expect(clientResult).to.equal(@123);
    });
    
    it(@"getTriggersInRange: should call endpoint", ^ {
        EvaluateSignal([client getTriggersInRange:EMResultRangeMake(10, 20)]);
        [endpoint expectRequestWithMethod:@"GET" path:@"/triggers?end=20&start=10"];
    });
    
    it(@"getTriggersInRange: should parse results", ^ {
        SetEndpointResult(@[
                           @{
                               @"parent_mailing": @{
                                   @"mailing_type": @"m",
                                   @"send_started": [NSNull null],
                                   @"signup_form_id": [NSNull null],
                                   @"mailing_id": @200,
                                   @"plaintext": @"Hello [% member:first_name %]!",
                                   @"recipient_count": @0,
                                   @"year": [NSNull null],
                                   @"account_id": @100,
                                   @"month": [NSNull null],
                                   @"disabled": @NO,
                                   @"parent_mailing_id": [NSNull null],
                                   @"started_or_finished": [NSNull null],
                                   @"name": @"Sample Mailing",
                                   @"mailing_status": @"c",
                                   @"plaintext_only": @NO,
                                   @"sender": @"Kevin McConnell",
                                   @"send_finished": [NSNull null],
                                   @"send_at": [NSNull null],
                                   @"reply_to": [NSNull null],
                                   @"subject": @"Sample Mailing for [% member:first_name %] [% member:last_name %]",
                                   @"archived_ts": [NSNull null],
                                   @"html_body": @"<p>Hello [% member:first_name %]!</p>"
                               },
                               @"surveys": [NSNull null],
                               @"event_type": @"r",
                               @"links": [NSNull null],
                               @"field_id": @203,
                               @"push_offset_units": @"0:-14:0:0",
                               @"start_ts": @"@D:2013-03-20T14:21:42",
                               @"trigger_id": @100,
                               @"signups": [NSNull null],
                               @"push_offset": @"@I:-1209600.0",
                               @"account_id": @100,
                               @"groups": @[ @1, @2 ],
                               @"parent_mailing_id": @200,
                               @"deleted_at": [NSNull null],
                               @"is_disabled": @YES,
                               @"name": @"Birthday triggers"
                           },
                           @{
                               @"parent_mailing": @{
                                   @"mailing_type": @"m",
                                   @"send_started": [NSNull null],
                                   @"signup_form_id": [NSNull null],
                                   @"mailing_id": @200,
                                   @"plaintext": @"Hello [% member:first_name %]!",
                                   @"recipient_count": @0,
                                   @"year": [NSNull null],
                                   @"account_id": @100,
                                   @"month": [NSNull null],
                                   @"disabled": @NO,
                                   @"parent_mailing_id": [NSNull null],
                                   @"started_or_finished": [NSNull null],
                                   @"name": @"Sample Mailing",
                                   @"mailing_status": @"c",
                                   @"plaintext_only": @NO,
                                   @"sender": @"Kevin McConnell",
                                   @"send_finished": [NSNull null],
                                   @"send_at": [NSNull null],
                                   @"reply_to": [NSNull null],
                                   @"subject": @"Sample Mailing for [% member:first_name %] [% member:last_name %]",
                                   @"archived_ts": [NSNull null],
                                   @"html_body": @"<p>Hello [% member:first_name %]!</p>"
                               },
                               @"surveys": @[@5,@9],
                               @"event_type": @"s",
                               @"links": @[@3, @4],
                               @"field_id": [NSNull null],
                               @"push_offset_units": @"0:3:0:0",
                               @"start_ts": @"@D:2013-03-20T14:21:42",
                               @"trigger_id": @101,
                               @"signups": @[
                                           @1,
                                           @2,
                                           @3
                                           ],
                               @"push_offset": @"@I:259200.0",
                               @"account_id": @100,
                               @"groups": [NSNull null],
                               @"parent_mailing_id": @200,
                               @"deleted_at": [NSNull null],
                               @"is_disabled": @NO,
                               @"name": @"Test Signup Form triggers"
                           }
                          ]);
        
        id x;
        EvaluateSignal([client getTriggersInRange:EMResultRangeAll]);
        expect([clientResult count]).to.equal(2);
        expect([clientResult[0] triggerID]).to.equal(@"100");
        expect([clientResult[0] name]).to.equal(@"Birthday triggers");
        expect([clientResult[0] parentMailingID]).to.equal(@"200");
        expect([clientResult[0] fieldID]).to.equal(@"203");
        x = @[ @"1", @"2" ];
        expect([clientResult[0] groupIDs]).to.equal(x);
        expect([clientResult[0] linkIDs]).to.beNil();
        expect([clientResult[0] signupFormIDs]).to.beNil();
        expect([clientResult[0] surveyIDs]).to.beNil();
        expect([clientResult[0] pushOffset]).to.equal(@"@I:-1209600.0");
        expect([clientResult[0] disabled]).to.beTruthy();
        
        expect([clientResult[1] triggerID]).to.equal(@"101");
        expect([clientResult[1] name]).to.equal(@"Test Signup Form triggers");
        expect([clientResult[1] parentMailingID]).to.equal(@"200");
        expect([clientResult[1] fieldID]).to.beNil();
        expect([clientResult[1] groupIDs]).to.beNil();
        x = @[ @"3", @"4"];
        expect([clientResult[1] linkIDs]).to.equal(x);
        x = @[@"1", @"2", @"3"];
        expect([clientResult[1] signupFormIDs]).to.equal(x);
        x = @[ @"5", @"9" ];
        expect([clientResult[1] surveyIDs]).to.equal(x);
        expect([clientResult[1] pushOffset]).to.equal(@"@I:259200.0");
        expect([clientResult[1] disabled]).to.beFalsy();
    });
    
    it(@"createTrigger: should call endpoint", ^ {
        EMTrigger *t = [[EMTrigger alloc] init];
        t.name = @"Birthdays";
        t.eventType = EMTriggerEventClick;
        t.parentMailingID = @"234";
        t.fieldID = @"944";
        t.groupIDs = nil;
        t.linkIDs = nil;
        t.signupFormIDs = nil;
        t.surveyIDs = nil;
        t.pushOffset = @"@I:123459";
        t.disabled = NO;
        
        EvaluateSignal([client createTrigger:t]);
        [endpoint expectRequestWithMethod:@"POST" path:@"/triggers" body:@{
         @"name": @"Birthdays",
         @"event_type": @"c",
         @"parent_mailing_id": @234,
         @"field_id": @944,
         @"groups": [NSNull null],
         @"links": [NSNull null],
         @"signups": [NSNull null],
         @"surveys": [NSNull null],
         @"push_offset": @"@I:123459",
         @"is_disabled": @NO
        }];
    });
    
    it(@"createTrigger: should parse results", ^ {
        SetEndpointResult(@1234);
        EvaluateSignal([client createTrigger:nil]);
        ExpectResultTo.equal(@"1234");
    });
    
    it(@"getTriggerWithID: should call endpoint", ^ {
        EvaluateSignal([client getTriggerWithID:@"123"]);
        [endpoint expectRequestWithMethod:@"GET" path:@"/triggers/123"];
    });
    
    it(@"getTriggerWithID: should parse results", ^ {
        SetEndpointResult(@{
                          @"surveys": [NSNull null],
                          @"event_type": @"r",
                          @"links": [NSNull null],
                          @"field_id": @203,
                          @"push_offset_units": @"0:-14:0:0",
                          @"start_ts": @"@D:2013-03-20T14:21:42",
                          @"trigger_id": @100,
                          @"signups": [NSNull null],
                          @"push_offset": @"@I:-1209600.0",
                          @"account_id": @100,
                          @"groups": [NSNull null],
                          @"parent_mailing_id": @200,
                          @"deleted_at": [NSNull null],
                          @"is_disabled": @NO,
                          @"name": @"Birthday triggers"
                          });
        EvaluateSignal([client getTriggerWithID:@"1234"]);
        ExpectResultSelector(name).to.equal(@"Birthday triggers");
        ExpectResultSelector(eventType).to.equal(EMTriggerEventRecurringDate);
        ExpectResultSelector(parentMailingID).to.equal(@"200");
        ExpectResultSelector(fieldID).to.equal(@"203");
        ExpectResultSelector(groupIDs).to.beNil();
        ExpectResultSelector(linkIDs).to.beNil();
        ExpectResultSelector(signupFormIDs).to.beNil();
        ExpectResultSelector(surveyIDs).to.beNil();
        ExpectResultSelector(pushOffset).to.equal(@"@I:-1209600.0");
        ExpectResultSelector(disabled).to.beFalsy();
    });
    
    it(@"updateTrigger: should call endpoint", ^ {
        EMTrigger *t = [[EMTrigger alloc] init];
        t.name = @"Birthdays";
        t.eventType = EMTriggerEventClick;
        t.parentMailingID = @"234";
        t.fieldID = @"944";
        t.groupIDs = nil;
        t.linkIDs = nil;
        t.signupFormIDs = nil;
        t.surveyIDs = nil;
        t.pushOffset = @"@I:123459";
        t.disabled = NO;
        
        EvaluateSignal([client createTrigger:t]);
        [endpoint expectRequestWithMethod:@"POST" path:@"/triggers" body:@{
         @"name": @"Birthdays",
         @"event_type": @"c",
         @"parent_mailing_id": @234,
         @"field_id": @944,
         @"groups": [NSNull null],
         @"links": [NSNull null],
         @"signups": [NSNull null],
         @"surveys": [NSNull null],
         @"push_offset": @"@I:123459",
         @"is_disabled": @NO
         }];
    });
    
    it(@"updateTrigger: should parse results", ^ {
        SetEndpointResult(@1239);
        EvaluateSignal([client updateTrigger:nil]);
        ExpectResultTo.equal(@"1239");
    });
    
    it(@"deleteTriggerWithID: should call endpoint", ^ {
        EvaluateSignal([client deleteTriggerWithID:@"1234"]);
        [endpoint expectRequestWithMethod:@"DELETE" path:@"/triggers/1234"];
    });
    
    it(@"deleteTriggerWithID: should parse results", ^ {
        SetEndpointResult(@YES);
        EvaluateSignal([client deleteTriggerWithID:@"1234"]);
        ExpectResultTo.equal(@YES);
    });
    
    it(@"getTriggerMailingsCount should call endpoint", ^ {
        EvaluateSignal([client getMailingCountForTriggerID:@"12349"]);
        [endpoint expectRequestWithMethod:@"GET" path:@"/triggers/12349/mailings?count=true"];
    });
    
    it(@"getTriggerMailingsCount should parse results", ^ {
        SetEndpointResult(@123);
        EvaluateSignal([client getMailingCountForTriggerID:@"1992"]);
        ExpectResultTo.equal(@123);
    });
    
    it(@"getMailingsForTriggerID:inRange: should call endpoint", ^ {
        EvaluateSignal([client getMailingsForTriggerID:@"1999" inRange:EMResultRangeMake(20, 40)]);
        [endpoint expectRequestWithMethod:@"GET" path:@"/triggers/1999/mailings?end=40&start=20"];
    });
    
    it(@"getMailingsForTriggerID:inRange: should parse results", ^ {
        SetEndpointResult(nil);
        EvaluateSignal([client getMailingsForTriggerID:@"1449" inRange:EMResultRangeMake(20, 40)]);
        // XXX assert that mailings were parsed;
    });
    
    it(@"createMember: should call endpoint", ^ {
        EMMember *firstMember = [[EMMember alloc] init];
        firstMember.email = @"first@email.com";
        
        [[client createMember:firstMember] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"POST" path:@"/members/add" body:@{@"email" : @"first@email.com"}];
    });
    
    it(@"createMember: should parse results", ^ {
        __block id result;
        
        endpoint.results = @[ [RACSignal return:
                               @{@"member_id" : @1234}
                               ] ];
        
        EMMember *firstMember = [[EMMember alloc] init];
        firstMember.email = @"first@email.com";
        
        [[client createMember:firstMember] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result).to.equal(@"1234");
    });
    
    it(@"deleteMembersWithIDs: should call endpoint", ^ {
        [[client deleteMembersWithIDs:@[@"123", @"567"]] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"PUT" path:@"/members/delete" body:@{@"member_ids" : @[@123, @567]}];
    });
    
    it(@"deleteMembersWithIDs: should parse results", ^ {
        __block id result;
        
        endpoint.results = @[ [RACSignal return:@YES] ];
        
        [[client deleteMembersWithIDs:@[@"123", @"567"]] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result).to.equal(@YES);
    });
    
#warning test other statuses?
    it(@"updateMemberIDs:withStatus: should call endpoint", ^ {
        [[client updateMemberIDs:@[@"123", @"567"] withStatus:EMMemberStatusActive] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"PUT" path:@"/members/status" body:@{@"member_ids" : @[@"123", @"567"], @"status_to" : @"a"}];
    });
    
    it(@"updateMemberIDs:withStatus: should parse results", ^ {
        __block id result;
        
        endpoint.results = @[ [RACSignal return:@YES] ];
        
        [[client updateMemberIDs:@[@"123", @"567"] withStatus:EMMemberStatusActive] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result).to.equal(@YES);
    });
    
    it(@"updateMember: should call endpoint", ^ {
        EMMember *memberToUpdate = [[EMMember alloc] init];
        memberToUpdate.email = @"email@emma.com";
        memberToUpdate.status = EMMemberStatusOptout;
        
        [[client updateMember:memberToUpdate] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"PUT" path:[NSString stringWithFormat:@"/members/%@", memberToUpdate.ID] body:@{@"email" : @"email@emma.com", @"status_to" : @"o"}];
    });
    
    it(@"updateMember: should parse results", ^ {
        __block id result;
        
        EMMember *memberToUpdate = [[EMMember alloc] init];
        memberToUpdate.email = @"email@emma.com";
        memberToUpdate.status = EMMemberStatusOptout;

        endpoint.results = @[ [RACSignal return:@YES] ];
        
        [[client updateMember:memberToUpdate] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result).to.equal(@YES);
    });
    
    it(@"getGroupsForMemberID: should call endpoint", ^ {
        [[client getGroupsForMemberID:@"123"] subscribeCompleted:^ { }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/members/123/groups" body:nil];
    });
    
    it(@"getGroupsForMemberID: should parse results", ^ {
        __block NSArray *result;
        
        id groupDict1 = @{
            @"active_count": @1,
            @"deleted_at": [NSNull null],
            @"error_count": @0,
            @"optout_count": @1,
            @"group_type": @"g",
            @"member_group_id": @150,
            @"account_id": @100,
            @"group_name": @"Monthly Newsletter"
        };
        endpoint.results = @[ [RACSignal return:@[
                               groupDict1
                               ]] ];
        
        [[client getGroupsForMemberID:@"123"] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result.count).to.equal(1);
        expect([result[0] name]).to.equal(@"Monthly Newsletter");
        expect([result[0] activeCount]).to.equal(1);
        expect([result[0] optoutCount]).to.equal(1);
        expect([result[0] errorCount]).to.equal(0);
        expect([result[0] ID]).to.equal(@"150");
    });
    
    it(@"addMemberID:toGroupIDs: should call endpoint", ^ {
        [[client addMemberID:@"123" toGroupIDs:@[@"321", @"432"]] subscribeCompleted:^ { }];
         [endpoint expectRequestWithMethod:@"PUT" path:@"/members/123/groups" body:@{@"group_ids" : @[@"321", @"432"]}];
    });
    
    it(@"addMemberID:toGroupIDs: should parse results", ^ {
        __block NSArray *result;
    
        endpoint.results = @[ [RACSignal return:@[
                               @"321", @"432"
                               ]] ];
        
        [[client addMemberID:@"123" toGroupIDs:@[@"321", @"432"]] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result[0]).to.equal(@"321");
        expect(result[1]).to.equal(@"432");
    });
    
    it(@"deleteMembersWithStatus: should call endpoint", ^ {
        [[client deleteMembersWithStatus:EMMemberStatusError] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"PUT" path:@"/members?member_status=e" body:nil];
    });
    
    it(@"deleteMembersWithStatus: should parse results", ^ {
        __block id result;
        
        endpoint.results = @[ [RACSignal return:@YES] ];
        
        [[client deleteMembersWithStatus:EMMemberStatusError] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result).to.equal(@YES);
    });
    
    it(@"removeMemberFromAllGroups: should call endpoint", ^ {
        [[client removeMemberFromAllGroups:@"123"] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"DELETE" path:@"/members/123/groups" body:nil];
    });
    
    it(@"removeMemberFromAllGroups: should parse results", ^ {
        __block id result;
        
        endpoint.results = @[ [RACSignal return:@YES] ];
        
        [[client removeMemberFromAllGroups:@"123"] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result).to.equal(@YES);
    });

    it(@"removeMemberIDs:fromGroupIDs: should call endpoint", ^ {
        [[client removeMemberIDs:@[@"123", @"234"] fromGroupIDs:@[@"543", @"432"]] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"PUT" path:@"/members/groups/remove" body:@{@"group_ids" : @[@"543", @"432"], @"member_ids" : @[@"123", @"234"]}];
    });
    
    it(@"removeMemberIDs:fromGroupIDs: should parse results", ^ {
        __block id result;
        
        endpoint.results = @[ [RACSignal return:@YES] ];
        
        [[client removeMemberIDs:@[@"123", @"234"] fromGroupIDs:@[@"543", @"432"]] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result).to.equal(@YES);
    });
    
    it(@"getMailingHistoryForMemberID: should call endpoint", ^ {
        [[client getMailingHistoryForMemberID:@"123"] subscribeCompleted:^ { }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/members/123/mailings" body:nil];
    });
    
    it(@"getMailingHistoryForMemberID: should parse results", ^ {
        __block NSArray *result;
        
        id mailingsDict = @{
            @"delivery_type": @"d",
            @"clicked": @"@D:2011-01-02T11:14:32",
            @"opened": @"@D:2011-01-02T11:13:51",
            @"mailing_id": @200,
            @"delivery_ts": @"@D:2011-01-02T10:29:36",
            @"name": @"Sample Mailing",
            @"forwarded": [NSNull null],
            @"shared": [NSNull null],
            @"subject": @"Sample Mailing for [% member:first_name %] [% member:last_name %]",
            @"sent": @"@D:2011-01-02T10:27:43",
            @"account_id": @100
        };
        endpoint.results = @[ [RACSignal return:@[
                               mailingsDict
                               ]] ];
        
        [[client getMailingHistoryForMemberID:@"123"] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result.count).to.equal(1);
        expect([result[0] ID]).to.equal(@"200");
        expect([result[0] name]).to.equal(@"Sample Mailing");
        expect([result[0] subject]).to.equal(@"Sample Mailing for [% member:first_name %] [% member:last_name %]");
    });
    
    it(@"getMembersForImportID: should call endpoint", ^ {
        [[client getMembersForImportID:@"999"] subscribeCompleted:^ { }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/members/imports/999/members" body:nil];
    });
    
    it(@"getMembersForImportID: should parse results", ^ {
        __block NSArray *result;
        
        id membersDict = @{
            @"member_id": @200,
            @"change_type": @"a",
            @"member_status_id": @"a",
            @"email": @"emma@myemma.com"
        };
        endpoint.results = @[ [RACSignal return:@[
                               membersDict
                               ]] ];
        
        [[client getMembersForImportID:@"999"] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result.count).to.equal(1);
        expect([result[0] ID]).to.equal(@"200");
        expect([result[0] status]).to.equal(EMMemberStatusActive);
        expect([result[0] email]).to.equal(@"emma@myemma.com");
    });
    
    it(@"getImportID: should call endpoint", ^ {
        [[client getImportID:@"333"] subscribeCompleted:^ { }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/members/imports/333" body:nil];
    });
    
    it(@"getImportID: should parse results", ^ {
        __block id result;
        
        id importDict = @{
            @"import_id": @200,
            @"status": [NSNull null],
            @"style": [NSNull null],
            @"import_started": @"@D:2010-12-13T23:12:44",
            @"account_id": @100,
            @"error_message": [NSNull null],
            @"num_members_updated": @0,
            @"source_filename": [NSNull null],
            @"fields_updated": @[],
            @"num_members_added": @0,
            @"import_finished": [NSNull null],
            @"groups_updated": @[],
            @"num_skipped": @0,
            @"num_duplicates": @0
        };
        endpoint.results = @[ [RACSignal return:
                               importDict
                               ] ];
        
        [[client getImportID:@"999"] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result[@"import_id"]).to.equal(@200);
        expect(result[@"import_started"]).to.equal(@"@D:2010-12-13T23:12:44");
    });
    
    it(@"getImports should call endpoint", ^ {
        [[client getImports] subscribeCompleted:^ { }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/members/imports" body:nil];
    });
    
    it(@"getImports should parse results", ^ {
        __block NSArray *result;
        
        id importDict = @{
        @"import_id": @200,
        @"status": [NSNull null],
        @"style": [NSNull null],
        @"import_started": @"@D:2010-12-13T23:12:44",
        @"account_id": @100,
        @"error_message": [NSNull null],
        @"num_members_updated": @0,
        @"source_filename": [NSNull null],
        @"fields_updated": @[],
        @"num_members_added": @0,
        @"import_finished": [NSNull null],
        @"groups_updated": @[],
        @"num_skipped": @0,
        @"num_duplicates": @0
        };
        
        endpoint.results = @[ [RACSignal return:@[
                               importDict
                               ]] ];
        
        [[client getImports] subscribeNext:^(id x) {
            result = x;
        }];
        
        id import = result[0];
        expect(result.count).to.equal(1);
        expect(import[@"import_id"]).to.equal(@200);
        expect(import[@"num_members_updated"]).to.equal(@0);
    });

    it(@"copyMembersWithStatuses:toGroup: should call endpoint", ^ {
        [[client copyMembersWithStatuses:EMMemberStatusOptout toGroup:@"321"] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"PUT" path:@"/members/321/copy" body:@{ @"member_status_id" : @[ @"o" ] }];
    });
    
    it(@"copyMembersWithStatuses:toGroup: should parse results", ^ {
        __block id result;
        
        endpoint.results = @[ [RACSignal return:@YES] ];
        
        [[client copyMembersWithStatuses:EMMemberStatusOptout toGroup:@"321"] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result).to.equal(@YES);
    });
    
    it(@"updateMembersWithStatus:toStatus:limitByGroupID: should call endpoint limited by group ", ^ {
        [[client updateMembersWithStatus:EMMemberStatusOptout toStatus:EMMemberStatusActive limitByGroupID:@"321"] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"PUT" path:@"/members/status/o/to/a" body:@{ @"group_id" : @"321" }];
    });
    
    it(@"updateMembersWithStatus:toStatus:limitByGroupID: should call endpoint not limited by group", ^ {
        [[client updateMembersWithStatus:EMMemberStatusError toStatus:EMMemberStatusForwarded limitByGroupID:nil] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"PUT" path:@"/members/status/e/to/f" body:nil];
    });
    
    it(@"updateMembersWithStatus:toStatus:limitByGroupID: should parse results", ^ {
        __block id result;
        
        endpoint.results = @[ [RACSignal return:@YES] ];
        
        [[client updateMembersWithStatus:EMMemberStatusError toStatus:EMMemberStatusForwarded limitByGroupID:nil] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result).to.equal(@YES);
    });
    
    it(@"getResponseSummary should call endpoint", ^ {
        [[client getResponseSummary] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/response?include_archived=false" body:nil];
    });
    
    it(@"getResponseSummary should parse results", ^ {
        __block NSArray *result;
        
        id responseSummary = @{
            @"account_id": @200,
            @"month": @01,
            @"year": @2013,
            @"mailings": @3,
            @"sent": @0,
            @"delivered": @1,
            @"bounced": @0,
            @"opened": @3,
            @"clicked_unique": @0,
            @"clicked": @0,
            @"forwarded": @2,
            @"shared": @1,
            @"share_clicked": @1,
            @"webview_shared": @0,
            @"webview_share_clicked": @0,
            @"opted_out": @2,
            @"signed_up": @3
        };
        
        endpoint.results = @[ [RACSignal return:
                               @[ responseSummary ]
                               ] ];
        
        [[client getResponseSummary] subscribeNext:^(id x) {
            result = x;
        }];
    
        EMResponseSummary *summary = result[0];
        expect(result.count).to.equal(1);
        expect([summary month]).to.equal(1);
        expect([summary year]).to.equal(2013);
        expect([summary mailings]).to.equal(3);
        expect([summary sent]).to.equal(0);
        expect([summary delivered]).to.equal(1);
        expect([summary bounced]).to.equal(0);
        expect([summary opened]).to.equal(3);
        expect([summary clickedUnique]).to.equal(0);
        expect([summary clicked]).to.equal(0);
        expect([summary forwarded]).to.equal(2);
        expect([summary shared]).to.equal(1);
        expect([summary shareClicked]).to.equal(1);
        expect([summary webViewShared]).to.equal(0);
        expect([summary webViewClicked]).to.equal(0);
        expect([summary optedOut]).to.equal(2);
        expect([summary signedUp]).to.equal(3);
    });
    
    it(@"getResponseSummaryInRange:includeArchived should call endpoint with archived", ^ {
        [[client getResponseSummaryInRange:@"2011-04-01~2011-09-01" includeArchived:YES] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/response?include_archived=true&range=2011-04-01~2011-09-01" body:nil];
    });
    it(@"getResponseSummaryInRange:includeArchived should call endpoint without archived", ^ {
        [[client getResponseSummaryInRange:@"2011-04-01~2011-09-01" includeArchived:NO] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/response?include_archived=false&range=2011-04-01~2011-09-01" body:nil];
    });
    
    it(@"getResponseSummaryInRange:includeArchived: should parse results", ^ {
        __block NSArray *result;
        
        id responseSummary = @{
            @"account_id": @200,
            @"month": @01,
            @"year": @2013,
            @"mailings": @3,
            @"sent": @0,
            @"delivered": @1,
            @"bounced": @0,
            @"opened": @3,
            @"clicked_unique": @0,
            @"clicked": @0,
            @"forwarded": @2,
            @"shared": @1,
            @"share_clicked": @1,
            @"webview_shared": @0,
            @"webview_share_clicked": @0,
            @"opted_out": @2,
            @"signed_up": @3
        };
        
        endpoint.results = @[ [RACSignal return:
                               @[ responseSummary ]
                               ] ];
        
        [[client getResponseSummaryInRange:@"2011-04-01~2011-09-01" includeArchived:YES] subscribeNext:^(id x) {
            result = x;
        }];
        
        EMResponseSummary *summary = result[0];
        expect(result.count).to.equal(1);
        expect([summary month]).to.equal(1);
        expect([summary year]).to.equal(2013);
        expect([summary mailings]).to.equal(3);
        expect([summary sent]).to.equal(0);
        expect([summary delivered]).to.equal(1);
        expect([summary bounced]).to.equal(0);
        expect([summary opened]).to.equal(3);
        expect([summary clickedUnique]).to.equal(0);
        expect([summary clicked]).to.equal(0);
        expect([summary forwarded]).to.equal(2);
        expect([summary shared]).to.equal(1);
        expect([summary shareClicked]).to.equal(1);
        expect([summary webViewShared]).to.equal(0);
        expect([summary webViewClicked]).to.equal(0);
        expect([summary optedOut]).to.equal(2);
        expect([summary signedUp]).to.equal(3);
    });
    
    it(@"getResponseForMailingID: should call endpoint", ^ {
        [[client getResponseForMailingID:@"123"] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/response/123" body:nil];
    });
    
    it(@"getResponseForMailingID: should parse results", ^ {
        __block EMMailingResponse *result;
        
        id responseSummary = @{
                @"delivered": @0,
                @"signed_up": @0,
                @"clicked": @3,
                @"name": @"Sample Mailing",
                @"clicked_unique": @0,
                @"webview_share_clicked": @0,
                @"opened": @0,
                @"opted_out": @0,
                @"share_clicked": @0,
                @"webview_shared": @0,
                @"shared": @0,
                @"in_progress": @0,
                @"bounced": @0,
                @"recipient_count": @0,
                @"sent": @0,
                @"forwarded": @0
        };
        
        endpoint.results = @[ [RACSignal return:
                               responseSummary
                               ] ];
        
        [[client getResponseForMailingID:@"123"] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect([result delivered]).to.equal(0);
        expect([result signedUp]).to.equal(0);
        expect([result clicked]).to.equal(3);
        expect([result clickedUnique]).to.equal(0);
        expect([result webviewShareClicked]).to.equal(0);
        expect([result opened]).to.equal(0);
        expect([result optedOut]).to.equal(0);
        expect([result shareClicked]).to.equal(0);
        expect([result webviewShared]).to.equal(0);
        expect([result shared]).to.equal(0);
    });
    
    it(@"getSendsForMailingID: should call endpoint", ^ {
        [[client getSendsForMailingID:@"123"] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/response/123/sends" body:nil];
    });
    
    it(@"getSendsForMailingID: should parse results", ^ {
        __block NSArray *result;
        
        id responseSummary = @{
        @"fields": @{
            @"first_name": @"Emma",
            @"last_name": @"Smith",
            @"favorite_food": @"tacos"
        },
        @"timestamp": @"@D:2011-01-02T10:27:43",
        @"member_id": @200,
        @"member_since": @"@D:2010-11-12T11:23:45",
        @"email_domain": @"myemma.com",
        @"email_user": @"emma",
        @"email": @"emma@myemma.com",
        @"member_status_id": @"a"
        };
        
        endpoint.results = @[ [RACSignal return:
                               @[ responseSummary ]
                               ] ];
        
        [[client getSendsForMailingID:@"123"] subscribeNext:^(id x) {
            result = x;
        }];
        
        EMMailingResponseEvent *summary = result[0];
        expect(result.count).to.equal(1);
        expect([summary timestamp]).to.equal([@"@D:2011-01-02T10:27:43" parseISO8601Timestamp]);
        expect([summary.member ID]).to.equal(@"200");
        expect([summary.member memberSince]).to.equal([@"@D:2010-11-12T11:23:45" parseISO8601Timestamp]);
        expect([summary.member email]).to.equal(@"emma@myemma.com");
        expect([summary.member status]).to.equal(EMMemberStatusActive);
    });
    
    it(@"getInProgressForMailingID: should call endpoint", ^ {
        [[client getInProgressForMailingID:@"123"] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/response/123/in_progress" body:nil];
    });
    
    it(@"getInProgressForMailingID: should parse results", ^ {
        __block NSArray *result;
        
        id responseSummary = @{
            @"fields": @{
            @"first_name": @"Emma",
            @"last_name": @"Smith",
            @"favorite_food": @"tacos"
            },
            @"member_id": @200,
            @"member_since": @"@D:2010-11-12T11:23:45",
            @"email_domain": @"myemma.com",
            @"email_user": @"emma",
            @"email": @"emma@myemma.com",
            @"member_status_id": @"a"
        };
        
        endpoint.results = @[ [RACSignal return:
                               @[ responseSummary ]
                               ] ];
        
        [[client getInProgressForMailingID:@"123"] subscribeNext:^(id x) {
            result = x;
        }];
        
        EMMailingResponseEvent *summary = result[0];
        expect(result.count).to.equal(1);
        expect([summary timestamp]).to.equal(nil);
        expect([summary.member ID]).to.equal(@"200");
        expect([summary.member memberSince]).to.equal([@"@D:2010-11-12T11:23:45" parseISO8601Timestamp]);
        expect([summary.member email]).to.equal(@"emma@myemma.com");
        expect([summary.member status]).to.equal(EMMemberStatusActive);
    });
    
    void (^testGetDeliveriesCallsEndpointWithDeliveryStatus)(EMDeliveryStatus status, NSString *statusString) = ^ (EMDeliveryStatus status, NSString *statusString) {
        [[client getDeliveriesForMailingID:@"123" withDeliveryStatus:status] subscribeCompleted:^ { }];
        NSString *pathString = [NSString stringWithFormat:@"/response/123/deliveries?del_status=%@", statusString];
        [endpoint expectRequestWithMethod:@"GET" path:pathString];
    };
    
    it(@"getDeliveriesForMailingID:withDeliveryStatus: should call endpoint with status all", ^ {
        testGetDeliveriesCallsEndpointWithDeliveryStatus(EMDeliveryStatusAll, @"all");
    });
    
    it(@"getDeliveriesForMailingID:withDeliveryStatus: should call endpoint with status delivered", ^ {
        testGetDeliveriesCallsEndpointWithDeliveryStatus(EMDeliveryStatusDelivered, @"delivered");
    });
    
    it(@"getDeliveriesForMailingID:withDeliveryStatus: should call endpoint with status bounced", ^ {
        testGetDeliveriesCallsEndpointWithDeliveryStatus(EMDeliveryStatusBounced, @"bounced");
    });
    
    it(@"getDeliveriesForMailingID:withDeliveryStatus: should call endpoint with status hard bounced", ^ {
        testGetDeliveriesCallsEndpointWithDeliveryStatus(EMDeliveryStatusHardBounce, @"hard");
    });
    
    it(@"getDeliveriesForMailingID:withDeliveryStatus: should call endpoint with status soft bounced", ^ {
        testGetDeliveriesCallsEndpointWithDeliveryStatus(EMDeliveryStatusSoftBounce, @"soft");
    });
    
    it(@"getDeliveriesForMailingID:withDeliveryStatus: should parse results", ^ {
        __block NSArray *result;
        
        id responseSummary = @{
        @"fields": @{
        @"first_name": @"Emma",
        @"last_name": @"Smith",
        @"favorite_food": @"tacos"
        },
        @"member_id": @200,
        @"member_since": @"@D:2010-11-12T11:23:45",
        @"email_domain": @"myemma.com",
        @"email_user": @"emma",
        @"email": @"emma@myemma.com",
        @"member_status_id": @"a",
        @"delivery_type": @"delivered"
        };
        
        endpoint.results = @[ [RACSignal return:
                               @[ responseSummary ]
                               ] ];
        
        [[client getInProgressForMailingID:@"123"] subscribeNext:^(id x) {
            result = x;
        }];
        
        EMMailingResponseEvent *summary = result[0];
        expect(result.count).to.equal(1);

        expect([summary timestamp]).to.equal(nil);
        expect([summary.member ID]).to.equal(@"200");
        expect([summary.member memberSince]).to.equal([@"@D:2010-11-12T11:23:45" parseISO8601Timestamp]);
        expect([summary.member email]).to.equal(@"emma@myemma.com");
        expect([summary.member status]).to.equal(EMMemberStatusActive);
#warning review test for this
//        expect([summary deliveryStatus]).to.equal(EMMemberStatusActive);
    });
    
    it(@"getOpensForMailingID: should call endpoint", ^ {
        [[client getOpensForMailingID:@"123"] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/response/123/opens" body:nil];
    });
    
    it(@"getOpensForMailingID: should parse results", ^ {
        __block NSArray *result;
        
        id responseSummary = @{
        @"fields": @{
        @"first_name": @"Emma",
        @"last_name": @"Smith",
        @"favorite_food": @"tacos"
        },
        @"member_id": @200,
        @"member_since": @"@D:2010-11-12T11:23:45",
        @"email_domain": @"myemma.com",
        @"email_user": @"emma",
        @"email": @"emma@myemma.com",
        @"member_status_id": @"a",
        @"timestamp": @"@D:2011-01-02T11:13:51"
        };
        
        endpoint.results = @[ [RACSignal return:
                               @[ responseSummary ]
                               ] ];
        
        [[client getOpensForMailingID:@"123"] subscribeNext:^(id x) {
            result = x;
        }];
        
        EMMailingResponseEvent *summary = result[0];
        expect(result.count).to.equal(1);
        expect([summary timestamp]).to.equal([@"@D:2011-01-02T11:13:51" parseISO8601Timestamp]);
        expect([summary.member ID]).to.equal(@"200");
        expect([summary.member memberSince]).to.equal([@"@D:2010-11-12T11:23:45" parseISO8601Timestamp]);
        expect([summary.member email]).to.equal(@"emma@myemma.com");
        expect([summary.member status]).to.equal(EMMemberStatusActive);
    });
    
    it(@"getLinksForMailingID: should call endpoint", ^ {
        [[client getLinksForMailingID:@"123"] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/response/123/links" body:nil];
    });
    
    it(@"getLinksForMailingID: should parse results", ^ {
        __block NSArray *result;
        
        id responseSummary = @{
        @"link_order": @1,
        @"link_name": @"Emma",
        @"unique_clicks": @1,
        @"plaintext": @NO,
        @"link_target": @"http://www.myemma.com",
        @"total_clicks": @1,
        @"link_id": @200
        };
        
        endpoint.results = @[ [RACSignal return:
                               @[ responseSummary ]
                               ] ];
        
        [[client getLinksForMailingID:@"123"] subscribeNext:^(id x) {
            result = x;
        }];
        
        EMMailingLinkResponse *linkResponse = result[0];
        expect(result.count).to.equal(1);
        expect([linkResponse clicks]).to.equal(1);
        expect([linkResponse uniqueClicks]).to.equal(1);
        expect([linkResponse linkOrder]).to.equal(1);
        expect([linkResponse name]).to.equal(@"Emma");
        expect([linkResponse target]).to.equal([NSURL URLWithString:@"http://www.myemma.com"]);
        expect([linkResponse isPlaintext]).to.equal(@NO);
    });
    
    /*
     - (RACSignal *)getClicksForMailingID:(NSString *)mailingID memberID:(NSString *)memberID linkID:(NSString *)linkID
     {
     return [[self requestSignalWithMethod:@"GET" path:[NSString stringWithFormat:@"/response/%@/clicks", mailingID] headers:nil body:@{@"member_id" : memberID, @"link_id" : linkID}] map:^id(NSArray *results) {

     */
    
    it(@"getClicksForMailingID:memberID:linkID: should call endpoint", ^ {
        [[client getClicksForMailingID:@"123" memberID:@"333" linkID:@"543"] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/response/123/clicks" body:@{@"member_id" : @"333", @"link_id" : @"543"}];
    });
    
    it(@"getClicksForMailingID:memberID:linkID: should parse results", ^ {
        __block NSArray *result;
        
        id responseSummary = @{
        @"fields": @{
        @"first_name": @"Emma",
        @"last_name": @"Smith",
        @"favorite_food": @"tacos"
        },
        @"member_id": @200,
        @"member_since": @"@D:2010-11-12T11:23:45",
        @"email_domain": @"myemma.com",
        @"email_user": @"emma",
        @"email": @"emma@myemma.com",
        @"member_status_id": @"a",
        @"timestamp": @"@D:2011-01-02T11:13:51",
        @"link_id" : @543
        };
        
        endpoint.results = @[ [RACSignal return:
                               @[ responseSummary ]
                               ] ];
        
        [[client getClicksForMailingID:@"123" memberID:@"333" linkID:@"543"] subscribeNext:^(id x) {
            result = x;
        }];
        
        EMMailingResponseEvent *summary = result[0];
        expect(result.count).to.equal(1);
        expect([summary timestamp]).to.equal([@"@D:2011-01-02T11:13:51" parseISO8601Timestamp]);
        expect([summary linkID]).to.equal(@"543");
        expect([summary.member ID]).to.equal(@"200");
        expect([summary.member memberSince]).to.equal([@"@D:2010-11-12T11:23:45" parseISO8601Timestamp]);
        expect([summary.member email]).to.equal(@"emma@myemma.com");
        expect([summary.member status]).to.equal(EMMemberStatusActive);
    });
    
    it(@"getForwardsForMailingID: should call endpoint", ^ {
        [[client getForwardsForMailingID:@"321"] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/response/321/forwards" body:nil];
    });
    
    it(@"getForwardsForMailingID: should parse results", ^ {
        __block NSArray *result;
        
        id responseSummary = @{
        @"fields": @{
        @"first_name": @"Emma",
        @"last_name": @"Smith",
        @"favorite_food": @"tacos"
        },
        @"member_id": @200,
        @"member_since": @"@D:2010-11-12T11:23:45",
        @"email_domain": @"myemma.com",
        @"email_user": @"emma",
        @"email": @"emma@myemma.com",
        @"member_status_id": @"a",
        @"timestamp": @"@D:2011-01-02T11:13:51",
        @"forward_mailing_id" : @543
        };
        
        endpoint.results = @[ [RACSignal return:
                               @[ responseSummary ]
                               ] ];
        
        [[client getForwardsForMailingID:@"321"] subscribeNext:^(id x) {
            result = x;
        }];
        
        EMMailingResponseEvent *summary = result[0];
        expect(result.count).to.equal(1);
        expect([summary timestamp]).to.equal([@"@D:2011-01-02T11:13:51" parseISO8601Timestamp]);
        expect([summary forwardMailingID]).to.equal(@"543");
        expect([summary.member ID]).to.equal(@"200");
        expect([summary.member memberSince]).to.equal([@"@D:2010-11-12T11:23:45" parseISO8601Timestamp]);
        expect([summary.member email]).to.equal(@"emma@myemma.com");
        expect([summary.member status]).to.equal(EMMemberStatusActive);
    });
    
    it(@"getOptoutsForMailingID: should call endpoint", ^ {
        [[client getOptoutsForMailingID:@"321"] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/response/321/optouts" body:nil];
    });
    
    it(@"getOptoutsForMailingID: should parse results", ^ {
        __block NSArray *result;
        
        id responseSummary = @{
        @"fields": @{
        @"first_name": @"Emma",
        @"last_name": @"Smith",
        @"favorite_food": @"tacos"
        },
        @"member_id": @200,
        @"member_since": @"@D:2010-11-12T11:23:45",
        @"email_domain": @"myemma.com",
        @"email_user": @"emma",
        @"email": @"emma@myemma.com",
        @"member_status_id": @"a",
        @"timestamp": @"@D:2011-01-02T11:13:51",
        };
        
        endpoint.results = @[ [RACSignal return:
                               @[ responseSummary ]
                               ] ];
        
        [[client getOptoutsForMailingID:@"321"] subscribeNext:^(id x) {
            result = x;
        }];
        
        EMMailingResponseEvent *summary = result[0];
        expect(result.count).to.equal(1);
        expect([summary timestamp]).to.equal([@"@D:2011-01-02T11:13:51" parseISO8601Timestamp]);
        expect([summary.member ID]).to.equal(@"200");
        expect([summary.member memberSince]).to.equal([@"@D:2010-11-12T11:23:45" parseISO8601Timestamp]);
        expect([summary.member email]).to.equal(@"emma@myemma.com");
        expect([summary.member status]).to.equal(EMMemberStatusActive);
    });
    
    it(@"getSignupsForMailingID: should call endpoint", ^ {
        [[client getSignupsForMailingID:@"321"] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/response/321/signups" body:nil];
    });
    
    it(@"getSignupsForMailingID: should parse results", ^ {
        __block NSArray *result;
        
        id responseSummary = @{
        @"fields": @{
        @"first_name": @"Emma",
        @"last_name": @"Smith",
        @"favorite_food": @"tacos"
        },
        @"member_id": @200,
        @"member_since": @"@D:2010-11-12T11:23:45",
        @"email_domain": @"myemma.com",
        @"email_user": @"emma",
        @"email": @"emma@myemma.com",
        @"member_status_id": @"a",
        @"timestamp": @"@D:2011-01-02T11:13:51",
        };
        
        endpoint.results = @[ [RACSignal return:
                               @[ responseSummary ]
                               ] ];
        
        [[client getSignupsForMailingID:@"321"] subscribeNext:^(id x) {
            result = x;
        }];
        
        EMMailingResponseEvent *summary = result[0];
        expect(result.count).to.equal(1);
        expect([summary timestamp]).to.equal([@"@D:2011-01-02T11:13:51" parseISO8601Timestamp]);
        expect([summary.member ID]).to.equal(@"200");
        expect([summary.member memberSince]).to.equal([@"@D:2010-11-12T11:23:45" parseISO8601Timestamp]);
        expect([summary.member email]).to.equal(@"emma@myemma.com");
        expect([summary.member status]).to.equal(EMMemberStatusActive);
    });
    
    it(@"getSharesForMailingID: should call endpoint", ^ {
        [[client getSharesForMailingID:@"321"] subscribeCompleted:^{ }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/response/321/shares" body:nil];
    });
    
    it(@"getSharesForMailingID: should parse results", ^ {
        __block NSArray *result;
        
        id shareInfo = @{
        @"member_id": @200,
        @"network": @"Cool Network",
        @"clicks" : @1
        };
        
        endpoint.results = @[ [RACSignal return:
                               @[ shareInfo ]
                               ] ];
        
        [[client getSharesForMailingID:@"321"] subscribeNext:^(id x) {
            result = x;
        }];
        
        EMShare *share = result[0];
        expect(result.count).to.equal(1);
        expect([share memberID]).to.equal(@"200");
        expect([share network]).to.equal(@"Cool Network");
        expect([share clicks]).to.equal(1);
    });
});

SpecEnd