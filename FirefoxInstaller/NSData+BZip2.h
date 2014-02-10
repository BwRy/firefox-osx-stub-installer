//  NSData+BZip2.h


#import <Foundation/Foundation.h>


@interface NSData (BZip2)

- (BOOL) decompressBZIP2CompressedDataToFile: (NSString*) path error: (NSError**) error;

@end
