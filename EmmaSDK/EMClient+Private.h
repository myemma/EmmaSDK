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

@interface EMMailingResponseEvent (Private)

- (id)initWithDictionary:(NSDictionary *)dictionary accountFields:(NSArray *)accountFields;

@end

@interface EMMailingLinkResponse (Private)

- (id)initWithDictionary:(NSDictionary *)dictionary;

@end

@interface EMShareSummary (Private)

- (id)initWithDictionary:(NSDictionary *)dictionary;

@end

@interface EMShare (Private)

- (id)initWithDictionary:(NSDictionary *)dictionary;

@end

@interface EMMember (Private)

- (id)initWithDictionary:(NSDictionary *)dict accountFields:(NSArray *)accountFields;

@end

@interface EMGroup (Private)

- (id)initWithDictionary:(NSDictionary *)dict;

@end

@interface EMMailing (Private)

- (id)initWithDictionary:(NSDictionary *)dict;

@end

@interface EMMessage (Private)

- (id)initWithDictionary:(NSDictionary *)dict;

@end

@interface EMSearch (Private)

- (id)initWithDictionary:(NSDictionary *)dict;
- (NSDictionary *)dictionaryRepresentation;

@end

@interface EMField (Private)

- (id)initWithDictionary:(NSDictionary *)dict;
- (NSDictionary *)dictionaryRepresentation;

@end

@interface EMWebhookInfo (Private)

- (id)initWithDictionary:(NSDictionary *)dictionary;

@end

@interface EMWebhook (Private)

- (id)initWithDictionary:(NSDictionary *)dictionary;
- (NSDictionary *)dictionaryRepresentation;

@end

NSString *EMDeliveryStatusToString(EMDeliveryStatus status);
NSString *EMMailingStatusToString(EMMailingStatus status);
NSString *EMGroupTypeToString(EMGroupType type);
NSString *EMFieldTypeToString(EMFieldType type);
NSString *EMFieldWidgetTypeToString(EMFieldWidgetType type);
NSString *EMMemberStatusToString(EMMemberStatus status);
