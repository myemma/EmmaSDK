#import "EMImport.h"
#import "NSObject+ObjectOrNil.h"
#import "NSString+EMDateParsing.h"
#import "NSNumber+ObjectIDString.h"

@implementation EMImport

- (id)initWithDictionary:(NSDictionary *)dict
{
    if ((self = [super init])) {
        _ID = [[[dict objectForKey:@"import_id"] numberOrNil] objectIDStringValue];
        _importStatus = [[dict objectForKey:@"status"] stringOrNil];
        _style = [[dict objectForKey:@"status"] stringOrNil];
        _errorMessage = [[dict objectForKey:@"error_message"] stringOrNil];
        _numberOfMembersUpdated = [[[dict objectForKey:@"num_members_updated"] numberOrNil] intValue];
        _numberOfMembersAdded = [[[dict objectForKey:@"num_members_added"] numberOrNil] intValue];
        _numberSkipped = [[[dict objectForKey:@"num_skipped"] numberOrNil] intValue];
        _numberOfDuplicates = [[[dict objectForKey:@"num_duplicates"] numberOrNil] intValue];
        _importStarted = [[[dict objectForKey:@"import_started"] stringOrNil] em_parseTimestamp];
        _importFinished = [[[dict objectForKey:@"import_finished"] stringOrNil] em_parseTimestamp];
        _fieldsUpdated = dict[@"fields_updated"];
        _groupsUpdated = dict[@"groups_updated"];
    }
    return self;
}

@end