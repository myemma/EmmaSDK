
typedef enum {
    EMTriggerEventUnknown,
    EMTriggerEventSignup,
    EMTriggerEventClick,
    EMTriggerEventSurvey,
    EMTriggerEventDate,
    EMTriggerEventRecurringDate
} EMTriggerEventType;

@interface EMTrigger : NSObject

@property (nonatomic, copy) NSString *triggerID, *name, *parentMailingID, *fieldID;
@property (nonatomic, copy) NSArray *groupIDs, *linkIDs, *signupFormIDs, *surveyIDs; // of NSString
@property (nonatomic, assign) NSString *pushOffset; // XXX this should probably be NSTimeInterval
@property (nonatomic, assign) BOOL disabled;
@property (nonatomic, assign) EMTriggerEventType eventType;

@end
