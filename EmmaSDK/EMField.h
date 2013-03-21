
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

@interface EMField : NSObject

@property (nonatomic, readonly) NSString *displayName, *name;
@property (nonatomic, readonly) EMFieldType fieldType;
@property (nonatomic, readonly) EMFieldWidgetType widgetType;

@end