#import "EMClient+Private.h"
#import <SBJson/SBJson.h>

#define API_HOST @"http://api.e2ma.net"
#define API_BASE_PATH @"/accounts/1"

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
    else {
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
    return [[self requestSignalWithMethod:@"POST" path:@"/groups" headers:nil body:body] map:^id(id value) {
        return [((NSArray *)value).rac_sequence map:^id(id value) {
            EMGroup *group = [[EMGroup alloc] init];
            group.name = value[@"group_name"];
            group.ID = value[@"member_group_id"];
            return group;
        }].array;
    }];
}

@end
