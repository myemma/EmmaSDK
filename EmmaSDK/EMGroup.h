
typedef enum {
    EMGroupTypeGroup,
    EMGroupTypeTest,
    EMGroupTypeHidden,
    EMGroupTypeAll,
} EMGroupType;

@interface EMGroup : NSObject

@property (nonatomic, copy) NSString *ID, *name;
@property (nonatomic, assign) NSInteger activeCount, errorCount, optoutCount;

@end
