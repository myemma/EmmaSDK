#import "NSData+Base64.h"

@implementation NSData (Base64)

- (NSString *)base64EncodedString {
    // shamelessly lifted from http://www.chrisumbel.com/article/basic_authentication_iphone_cocoa_touch
    static char *alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
    
    int length = [self length];
    
    int encodedLength = ((((length % 3) + length) / 3) * 4) + 1;
    char *outputBuffer = malloc(encodedLength);
    char *inputBuffer = (char *)[self bytes];
    
    NSInteger i;
    NSInteger j = 0;
    int remain;
    
    for(i = 0; i < length; i += 3) {
        remain = length - i;
        
        outputBuffer[j++] = alphabet[(inputBuffer[i] & 0xFC) >> 2];
        outputBuffer[j++] = alphabet[((inputBuffer[i] & 0x03) << 4) |
                                     ((remain > 1) ? ((inputBuffer[i + 1] & 0xF0) >> 4): 0)];
        
        if(remain > 1)
            outputBuffer[j++] = alphabet[((inputBuffer[i + 1] & 0x0F) << 2)
                                         | ((remain > 2) ? ((inputBuffer[i + 2] & 0xC0) >> 6) : 0)];
        else
            outputBuffer[j++] = '=';
        
        if(remain > 2)
            outputBuffer[j++] = alphabet[inputBuffer[i + 2] & 0x3F];
        else
            outputBuffer[j++] = '=';
    }
    
    outputBuffer[j] = 0;
    
    NSString *result = [[NSString alloc] initWithUTF8String:outputBuffer];
    free(outputBuffer);
    
    return result;
}

@end
