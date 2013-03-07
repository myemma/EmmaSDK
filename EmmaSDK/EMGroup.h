
typedef enum {
    EMGroupTypeGroup = 1 << 0,
    EMGroupTypeTest = 1 << 1,
    EMGroupTypeHidden = 1 << 2,
    EMGroupTypeAll = 1 << 3,
} EMGroupType;

@interface EMGroup : NSObject

@property (nonatomic, copy) NSString *ID, *name;
@property (nonatomic, assign) NSInteger activeCount, errorCount, optoutCount;

- (id)initWithDictionary:(NSDictionary *)dict;

@end
