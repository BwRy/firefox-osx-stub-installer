//  NSData+BZip2.m


#include <bzlib.h>
#import "NSData+BZip2.h"


@implementation NSData (BZip2)

- (BOOL) decompressBZIP2CompressedDataToFile: (NSString*) path error: (NSError**) error
{
    if (error != NULL) {
        *error = nil;
    }
    
	bz_stream strm;
	strm.bzalloc = NULL;
	strm.bzfree = NULL;
	strm.opaque = NULL;
    
    int ret = BZ2_bzDecompressInit(&strm, 0, 0);
    if (ret != BZ_OK) {
        *error = [NSError errorWithDomain: @"BZip2" code: ret userInfo: nil];
        return YES;
    }

    FILE *f = fopen([path cStringUsingEncoding: NSUTF8StringEncoding], "w");
    if (f == NULL) {
        if (error) {
            *error = [NSError errorWithDomain: @"BZip2" code: errno userInfo: nil];
        }
        return NO;
    }

    strm.next_in = (char *)[self bytes];
    strm.avail_in = (unsigned int) [self length];
    
    while (ret == BZ_OK)
    {
        char buffer[16 * 1024];
        int bufferSize = 16 * 1024;
    
        strm.next_out = buffer;
        strm.avail_out = bufferSize;
        
        ret = BZ2_bzDecompress(&strm);
        if (ret == BZ_OK || ret == BZ_STREAM_END)
        {
            size_t written = fwrite(buffer, sizeof(char), strm.next_out - buffer, f);
            if (written == -1) {
                if (*error) {
                    *error = [NSError errorWithDomain: @"BZip2" code: errno userInfo: nil];
                }
                fclose(f);
                return NO;
            }
        }
    }
    
    fclose(f);

    BZ2_bzDecompressEnd (&strm);
    
    return YES;
}

@end
