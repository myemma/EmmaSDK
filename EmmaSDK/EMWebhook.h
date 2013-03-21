
@interface EMWebhookInfo : NSObject

@property (nonatomic, copy) NSString *eventName, *webhookEventID, *description;

@end

@interface EMWebhook : NSObject

@property (nonatomic, copy) NSString *webhookID, *url, *method, *event;

@end
