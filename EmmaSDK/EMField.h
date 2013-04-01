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

@property (nonatomic, copy) NSString *displayName, *name, *fieldID;
@property (nonatomic, assign) EMFieldType fieldType;
@property (nonatomic, assign) EMFieldWidgetType widgetType;
@property (nonatomic, copy) NSArray *options;
@property (nonatomic, assign) NSUInteger columnOrder;

@end