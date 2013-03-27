enum {
    EMFieldTypeText,
    EMFieldTypeDate,
    EMFieldTypeTimestamp,
    EMFieldTypeTextArray,
    EMFieldTypeBoolean,
    EMFieldTypeNumeric
};
typedef NSInteger EMFieldType;

enum {
    EMFieldWidgetTypeText,
    EMFieldWidgetTypeLong,
    EMFieldWidgetTypeCheckMultiple,
    EMFieldWidgetTypeRadio,
    EMFieldWidgetTypeSelectOne,
    EMFieldWidgetTypeSelectMultiple,
    EMFieldWidgetTypeDate
};
typedef NSInteger EMFieldWidgetType;

EMFieldType EMFieldTypeFromString(NSString *fieldTypeString);
NSString *EMFieldTypeToString(EMFieldType type);

EMFieldWidgetType EMFieldWidgetTypeFromString(NSString *widgetTypeString);
NSString *EMFieldWidgetTypeToString(EMFieldWidgetType type);

@interface EMField : NSObject

@property (nonatomic, readonly) NSString *displayName, *name, *fieldID;
@property (nonatomic, readonly) EMFieldType fieldType;
@property (nonatomic, readonly) EMFieldWidgetType widgetType;
@property (nonatomic, readonly) NSArray *options;
@property (nonatomic) NSUInteger columnOrder;

- (id)initWithDictionary:(NSDictionary *)dict;
- (NSDictionary *)dictionaryRepresentation;

@end