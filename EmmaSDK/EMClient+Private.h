#import "EMClient.h"


@interface NSObject (JSONDataRepresentation)

- (NSData *)JSONDataRepresentation;
- (id)objectOrNil;

@end

#define ObjectOrNull(X) ((X) ?: [NSNull null])

@protocol EMEndpoint <NSObject>

- (RACSignal *)requestSignalWithURLRequest:(NSURLRequest *)request;

@end

@interface EMClient (Private)

- (id)initWithEndpoint:(id<EMEndpoint>)endpoint;

+ (RACSignal *)batchWithBasePath:(NSString *)basePath baseQuery:(NSDictionary *)baseQuery; // return RACSignal of EMResults batch

@end