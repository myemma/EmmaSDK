
typedef enum {
    EMGroupTypeGroup,
    EMGroupTypeTest,
    EMGroupTypeHidden,
    EMGroupTypeAll,
} EMGroupType;

@interface EMGroup : NSObject

@property (nonatomic, readonly) NSString *ID;
@property (nonatomic, readonly) NSString *name;
@property (nonatomic, readonly) NSInteger activeCount, errorCount, optoutCount;

@end
