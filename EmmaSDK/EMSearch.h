
@interface EMSearch : NSObject

@property (nonatomic, copy) NSString *ID, *name, *criteria;
@property (nonatomic, assign) NSInteger activeCount, optoutCount, errorCount;
@property (nonatomic, strong) NSDate *deletedAt, *lastRunAt;

@end
