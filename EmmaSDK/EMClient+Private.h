#import "EMClient.h"

@interface NSObject (JSONDataRepresentation)

- (NSData *)JSONDataRepresentation;
- (id)objectOrNil;

@end

#define ObjectOrNull(X) ((X) ?: (id)[NSNull null])

@protocol EMEndpoint <NSObject>

- (RACSignal *)requestSignalWithURLRequest:(NSURLRequest *)request;

@end

@interface EMClient (Private)

- (id)initWithEndpoint:(id<EMEndpoint>)endpoint;

+ (RACSignal *)batchWithBasePath:(NSString *)basePath baseQuery:(NSDictionary *)baseQuery; // return RACSignal of EMResults batch

@end

@interface EMTrigger (Private)

- (id)initWithDictionary:(NSDictionary *)dictionary;
- (NSDictionary *)dictionaryRepresentation;

@end

@interface EMResponseSummary (Private)

- (id)initWithDictionary:(NSDictionary *)dictionary;

@end

@interface EMMailingResponse (Private)

- (id)initWithDictionary:(NSDictionary *)dictionary;

@end