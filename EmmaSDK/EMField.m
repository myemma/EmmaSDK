#import "EMField.h"
#import "NSObject+ObjectOrNil.h"

@implementation EMField

- (id)initWithDictionary:(NSDictionary *)dict {
    if ((self = [super init])) {
        _name = [[[dict objectForKey:@"shortcut_name"] stringOrNil] copy];
        _displayName = [[[dict objectForKey:@"display_name"] stringOrNil] copy];
        
        NSString *fieldTypeString = [[dict objectForKey:@"field_type"] stringOrNil];
        
        if ([fieldTypeString isEqual:@"text"])
            _fieldType = EMFieldTypeText;
        else if ([fieldTypeString isEqual:@"text[]"])
            _fieldType = EMFieldTypeTextArray;
        else if ([fieldTypeString isEqual:@"date"])
            _fieldType = EMFieldTypeDate;
        else if ([fieldTypeString isEqual:@"timestamp"])
            _fieldType = EMFieldTypeTimestamp;
        else if ([fieldTypeString isEqual:@"numeric"])
            _fieldType = EMFieldTypeNumeric;
        else if ([fieldTypeString isEqual:@"boolean"])
            _fieldType = EMFieldTypeBoolean;
        else
            NSLog(@"-[Field initWithDictionary]: encountered unknown field type '%@'", fieldTypeString);
        
        NSString *widgetTypeString = [[dict objectForKey:@"widget_type"] stringOrNil];
        
        if ([widgetTypeString isEqual:@"text"])
            _widgetType = EMFieldWidgetTypeText;
        else if ([widgetTypeString isEqual:@"long"])
            _widgetType = EMFieldWidgetTypeLong;
        else if ([widgetTypeString isEqual:@"check_multiple"])
            _widgetType = EMFieldWidgetTypeCheckMultiple;
        else if ([widgetTypeString isEqual:@"radio"])
            _widgetType = EMFieldWidgetTypeRadio;
        else if ([widgetTypeString isEqual:@"select one"])
            _widgetType = EMFieldWidgetTypeSelectOne;
        else if ([widgetTypeString isEqual:@"select multiple"])
            _widgetType = EMFieldWidgetTypeSelectMultiple;
        else if ([widgetTypeString isEqual:@"date"])
            _widgetType = EMFieldWidgetTypeDate;
        else
            NSLog(@"-[Field initWithDictionary]: encountered unknown widget type '%@'", widgetTypeString);
    }
    return self;
}

@end
