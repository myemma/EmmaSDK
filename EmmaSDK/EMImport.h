
@interface EMImport : NSObject

@property (nonatomic, copy) NSString *ID, *importStatus, *style, *errorMessage;
@property (nonatomic, assign) NSInteger numberOfMembersUpdated, numberOfMembersAdded, numberSkipped, numberOfDuplicates;
@property (nonatomic, strong) NSDate *importStarted, *importFinished;
@property (nonatomic, strong) NSDictionary *fieldsUpdated, *groupsUpdated;

@end
