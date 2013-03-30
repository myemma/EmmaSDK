#import "SMWebRequest.h"
#import <ReactiveCocoa/ReactiveCocoa.h>

@interface SMWebRequest (RAC)

+ (RACSignal *)requestSignalWithURLRequest:(NSURLRequest *)request dataParser:(id (^)(id))parser;

@end
