
@interface EMImport : NSObject

@property (nonatomic, copy) NSString *ID, *importStatus, *importStyle, *errorMessage, *sourceFilename;
@property (nonatomic, assign) NSInteger numberOfMembersUpdated, numberOfMembersAdded, numberSkipped, numberOfDuplicates;
@property (nonatomic, strong) NSDate *importStarted, *importFinished;
@property (nonatomic, strong) NSArray *fieldsUpdated, *groupsUpdated;

@end
