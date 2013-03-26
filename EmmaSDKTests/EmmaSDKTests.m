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
        __block NSArray *result;
        
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
        endpoint.results = @[ [RACSignal return:@[
                               memberDict0
                               ]] ];
        
        [[client getGroupID:@"150"] subscribeNext:^(id x) {
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
        //TODO: memberSince (weird bug with parseISO8601Timestamp)
        //TODO: memberFields
        //TODO: fullName
    });
    
    it(@"getMailingWithID: should call endpoint", ^ {
        [[client getMailingWithID:@"321" ] subscribeCompleted:^ { }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/mailings/321"];
    });
    
    it(@"getMailingWithID: should parse results", ^ {
        
        __block NSArray *result;
        
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
        
        endpoint.results = @[ [RACSignal return:@[
                               mailingsDict
                               ]] ];
        
        [[client getMailingWithID:@"321"] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result.count).to.equal(1);
        expect([result[0] status]).to.equal(EMMailingStatusComplete);
        expect([result[0] sender]).to.equal(@"Kevin McConnell");
        expect([result[0] name]).to.equal(@"Sample Mailing");
        expect([result[0] ID]).to.equal(@"200");
        expect([result[0] recipientCount]).to.equal(@0);
        expect([result[0] subject]).to.equal(@"Sample Mailing for [% member:first_name %] [% member:last_name %]");
        expect([result[0] publicWebViewURL]).to.equal([NSURL URLWithString:@"http://localhost/webview/uf/6db0cc7e6fdb2da589b65f29d90c96b6"]);
    });
    
    it(@"getMessageToMemberID:forMailingID: should call endpoint", ^ {
        [[client getMessageToMemberID:@"123" forMailingID:@"321"] subscribeCompleted:^ { }];
        [endpoint expectRequestWithMethod:@"GET" path:@"/mailings/321/messages/123"];
    });
    
    it(@"getMessageToMemberID:forMailingID: should parse results", ^ {
        
        __block NSArray *result;
        
        id mailingsDict = @{
                                @"plaintext": @"Hello !",
                                @"subject": @"Sample Mailing for  ",
                                @"html_body": @"<p>Hello !</p>"
            };
        
        endpoint.results = @[ [RACSignal return:@[
                               mailingsDict
                               ]] ];
        
        [[client getMessageToMemberID:@"123" forMailingID:@"321"] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result.count).to.equal(1);
        expect([result[0] subject]).to.equal(@"Sample Mailing for  ");
        expect([result[0] plaintext]).to.equal(@"Hello !");
        expect([result[0] htmlBody]).to.equal(@"<p>Hello !</p>");
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
        __block NSArray *result;
        
        id memberDict0 = @{
            @"mailing_id": @1024
        };
        
        endpoint.results = @[ [RACSignal return:@[
                               memberDict0
                               ]] ];
        
        [[client resendMailingID:@"123" headsUpAddresses:@[@"hdsup@test.com"] recipientAddresses:@[@"recip@ient.com"] recipientGroupIDs:@[@"321"] recipientSearchIDs:@[@"432"]] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result.count).to.equal(1);
        expect([result[0] ID]).to.equal(@"1024");
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
        __block NSArray *result;
        
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
        
        endpoint.results = @[ [RACSignal return:@[
                               dict
                               ]] ];
        
        [[client getFieldID:@"123"] subscribeNext:^(id x) {
            result = x;
        }];
        
        expect(result.count).to.equal(1);
        expect([result[0] name]).to.equal(@"first_name");
        expect([result[0] displayName]).to.equal(@"First Name");
        expect([result[0] fieldType]).to.equal(EMFieldTypeText);
        expect([result[0] widgetType]).to.equal(EMFieldWidgetTypeText);
    });
});

SpecEnd