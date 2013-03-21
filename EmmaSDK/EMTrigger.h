
@interface EMTrigger : NSObject

@property (nonatomic, copy) NSString *triggerID, *name, *parentMailingID, *fieldID;
@property (nonatomic, copy) NSArray *groupIDs, *linkIDs, *signupFormIDs, *surveyIDs;
@property (nonatomic, assign) NSUInteger *pushOffset;
@property (nonatomic, assign) BOOL disabled;

@end
