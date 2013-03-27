
@interface EMWebhookInfo : NSObject

@property (nonatomic, copy) NSString *eventName, *webhookEventID, *webhookDescription;

- (id)initWithDictionary:(NSDictionary *)dictionary;

@end

@interface EMWebhook : NSObject

@property (nonatomic, copy) NSString *webhookID, *method, *event;
@property (nonatomic, strong) NSURL *url;

- (id)initWithDictionary:(NSDictionary *)dictionary;
- (NSDictionary *)dictionaryRepresentation;

@end
