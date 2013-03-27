
@interface EMSearch : NSObject

@property (nonatomic, readonly) NSString *ID, *name, *criteria;
@property (nonatomic, readonly) NSInteger activeCount, optoutCount, errorCount;
@property (nonatomic, readonly) NSDate *deletedAt, *lastRunAt;

- (id)initWithDictionary:(NSDictionary *)dict;
- (NSDictionary *)dictionaryRepresentation;

@end
