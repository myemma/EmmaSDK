#import "EMField.h"

@implementation EMField

- (id)initWithDictionary:(NSDictionary *)dict {
    if ((self = [super init])) {
        _name = [[[dict objectForKey:@"shortcut_name"] stringOrNil] copy];
        _displayName = [[[dict objectForKey:@"display_name"] stringOrNil] copy];
        
        NSString *fieldTypeString = [[dict objectForKey:@"field_type"] stringOrNil];
        
        if ([fieldTypeString isEqual:@"text"])
            _fieldType = FieldTypeText;
        else if ([fieldTypeString isEqual:@"text[]"])
            _fieldType = FieldTypeTextArray;
        else if ([fieldTypeString isEqual:@"date"])
            _fieldType = FieldTypeDate;
        else if ([fieldTypeString isEqual:@"timestamp"])
            _fieldType = FieldTypeTimestamp;
        else if ([fieldTypeString isEqual:@"numeric"])
            _fieldType = FieldTypeNumeric;
        else if ([fieldTypeString isEqual:@"boolean"])
            _fieldType = FieldTypeBoolean;
        else
            NSLog(@"-[Field initWithDictionary]: encountered unknown field type '%@'", fieldTypeString);
        
        NSString *widgetTypeString = [[dict objectForKey:@"widget_type"] stringOrNil];
        
        if ([widgetTypeString isEqual:@"text"])
            _widgetType = FieldWidgetTypeText;
        else if ([widgetTypeString isEqual:@"long"])
            _widgetType = FieldWidgetTypeLong;
        else if ([widgetTypeString isEqual:@"check_multiple"])
            _widgetType = FieldWidgetTypeCheckMultiple;
        else if ([widgetTypeString isEqual:@"radio"])
            _widgetType = FieldWidgetTypeRadio;
        else if ([widgetTypeString isEqual:@"select one"])
            _widgetType = FieldWidgetTypeSelectOne;
        else if ([widgetTypeString isEqual:@"select multiple"])
            _widgetType = FieldWidgetTypeSelectMultiple;
        else if ([widgetTypeString isEqual:@"date"])
            _widgetType = FieldWidgetTypeDate;
        else
            NSLog(@"-[Field initWithDictionary]: encountered unknown widget type '%@'", widgetTypeString);
    }
    return self;
}

@end
