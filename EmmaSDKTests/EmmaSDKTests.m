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

@end

#define API_HOST @"http://api.e2ma.net"

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
        
        id x = @[@{
                     @"host": API_HOST,
                     @"method": @"POST",
                     @"path": @"/accounts/1/groups",
                     @"headers": @{ @"Content-Type": @"application/json" },
                     @"body": @{ @"groups": @[ @{ @"group_name": @"foo" },  @{ @"group_name": @"bar" }, @{ @"group_name": @"baz" } ] }
                     }];
        expect(endpoint.calls).to.equal(x);
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
        
        id x = @[@{
                     @"host": API_HOST,
                     @"method": @"GET",
                     @"path": @"/accounts/1/groups?count=true&group_types=all",
                     @"headers": @{ },
                     @"body": [NSNull null]
                   }];
        
        expect(endpoint.calls).to.equal(x);
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
        
        id x = @[@{
                     @"host": API_HOST,
                     @"method": @"GET",
                     @"path": [NSString stringWithFormat:@"/accounts/1/groups?end=20&group_types=%@&start=10", groupTypeString],
                     @"headers": @{ },
                     @"body": [NSNull null]
                     }];
        
        expect(endpoint.calls).to.equal(x);
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
        
        id x = @[@{
                     @"host": API_HOST,
                     @"method": @"PUT",
                     @"path": @"/accounts/1/groups/123",
                     @"headers": @{ @"Content-Type": @"application/json" },
                     @"body": @{ @"group_name": @"FOO" }
                     }];
        
        expect(endpoint.calls).to.equal(x);
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
        
        id x = @[@{
                     @"host": API_HOST,
                     @"method": @"GET",
                     @"path": @"/accounts/1/groups/123/members?deleted=true&end=20&start=10",
                     @"headers": @{ },
                     @"body": [NSNull null]
                     }];
        
        expect(endpoint.calls).to.equal(x);
    });
    
    it(@"getMembersInGroupID:inRange: should call endpoint without deleted", ^ {
        [[client getMembersInGroupID:@"123" inRange:(EMResultRange){ .start = 10, .end = 20 } includeDeleted:NO] subscribeCompleted:^ { }];
        
        id x = @[@{
                     @"host": API_HOST,
                     @"method": @"GET",
                     @"path": @"/accounts/1/groups/123/members?deleted=false&end=20&start=10",
                     @"headers": @{ },
                     @"body": [NSNull null]
                     }];
        
        expect(endpoint.calls).to.equal(x);
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
        
        id x = @[@{
                     @"host": API_HOST,
                     @"method": @"DELETE",
                     @"path": @"/accounts/1/groups/123",
                     @"headers": @{},
                     @"body": [NSNull null]
                     }];
        
        expect(endpoint.calls).to.equal(x);
    });
});

SpecEnd