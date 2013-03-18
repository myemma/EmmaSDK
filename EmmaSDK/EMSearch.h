
@interface EMSearch : NSObject

@property (nonatomic, readonly) NSString *ID, *name;
@property (nonatomic, readonly) NSInteger activeCount;

- (id)initWithDictionary:(NSDictionary *)dict;

@end
