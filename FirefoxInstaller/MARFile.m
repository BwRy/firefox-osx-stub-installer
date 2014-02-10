// MARFile.m


#include <sys/types.h>
#include <sys/mman.h>

#import "NSData+BZip2.h"
#import "MARFile.h"


typedef struct _MARFileHeader {
  uint32_t magic;
  uint32_t offsetToIndex;
  uint64_t fileSize;
} MARFileHeader;

typedef struct _MARIndexHeader {
    uint32_t indexSize;
} MARIndexHeader;

typedef struct _MARIndexEntry {
    uint32_t offsetToContent;
    uint32_t contentSize;
    uint32_t permissions;
    char path[];
} MARIndexEntry;


@implementation MARItem

- (instancetype) initWithPath: (NSString*) path size: (NSUInteger) size permissions: (NSUInteger) permissions offset: (NSUInteger) offset
{
    if ((self = [super init]) != nil) {
        _path = path;
        _size = size;
        _permissions = permissions;
        _offset = offset;
    }
    return self;
}

@end


@interface MARFile (Private)
- (NSError*) integrityCheck;
- (NSError*) readIndex;
- (NSError*) readSignatures;
@end


@implementation MARFile {
    NSString *_path;
    NSFileHandle *_fileHandle;
    NSUInteger _fileSize;
    NSUInteger _offsetToIndex;
    NSUInteger _indexSize;
    NSMutableArray *_items;
}

- (instancetype) initWithPath: (NSString*) path
{
    if ((self = [super init]) != nil) {
        _path = path;
        _items = [NSMutableArray new];
    }
    return self;
}

- (void) openUsingCallback: (MARFileOpenCallback) callback
{
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        NSError *error = nil;
        _fileHandle = [NSFileHandle fileHandleForReadingFromURL: [NSURL fileURLWithPath: _path] error: &error];
        if (error != nil) {
            callback(error);
            return;
        }
        
        NSError *integrityCheckError = [self integrityCheck];
        if (integrityCheckError != nil) {
            callback(integrityCheckError);
            return;
        }
        
        NSError *readIndexError = [self readIndex];
        if (readIndexError != nil) {
            callback(readIndexError);
            return;
        }
        
        NSError *readSignaturesError = [self readSignatures];
        if (readSignaturesError != nil) {
            callback(readSignaturesError);
            return;
        }
        
        callback(nil);
    });
}

- (void) extractItemsToRoot: (NSString*) root usingCallback: (MARFileExtractCallback) block
{
    __block NSUInteger itemIndex = 0;
    [self enumerateItemsUsingBlock:^(MARItem *item, NSData *content, BOOL *stop) {
        double progress = (double) itemIndex / (double) [_items count];
        itemIndex++;
        
        NSString *path = [root stringByAppendingPathComponent: item.path];
        NSLog(@"Extracting to %@", path);
        
        // Create the directory if it does not exist yet
        
        NSArray *itemPathComponents = [item.path pathComponents];
        if ([itemPathComponents count] > 1) {
            NSString *directoryPath = [root stringByAppendingPathComponent:
                [NSString pathWithComponents: [itemPathComponents subarrayWithRange: NSMakeRange(0, [itemPathComponents count]-1)]]];

            NSError *createDirectoryError = nil;
            if ([[NSFileManager defaultManager] createDirectoryAtPath: directoryPath withIntermediateDirectories: YES attributes: nil error: &createDirectoryError] == NO) {
                block(item, NO, progress, createDirectoryError);
                *stop = YES;
            }
        }
        
        // Create the file with the right permissions
        
        NSDictionary *fileAttributes = [NSDictionary dictionaryWithObject: [NSNumber numberWithUnsignedInteger: item.permissions] forKey: NSFilePosixPermissions];
        if ([[NSFileManager defaultManager] createFileAtPath: path contents: [NSMutableData data] attributes: fileAttributes] == NO) {
            block(item, NO, progress, [NSError errorWithDomain: @"MARFile" code: -1 userInfo: nil]);
            *stop = YES;
        }
        
        NSError *decompressError = nil;
        if ([content decompressBZIP2CompressedDataToFile: path error: &decompressError] == NO) {
            block(item, NO, progress, decompressError);
            *stop = YES;
        } else {
            block(item, [_items lastObject] == item, progress, nil);
        }
    }];
}

- (void) close
{
}

- (void) enumerateItemsUsingBlock: (MARFileItemEnumerator) block
{
    [_items enumerateObjectsUsingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        MARItem *item = obj;
        [_fileHandle seekToFileOffset: item.offset];
        NSData *content = [_fileHandle readDataOfLength: item.size];
        block(obj, content, stop);
    }];
}

- (NSError*) integrityCheck
{
    _fileSize = [_fileHandle seekToEndOfFile];

    // Grab the file header and do some basic checks

    [_fileHandle seekToFileOffset: 0];
    NSData *fileHeaderData = [_fileHandle readDataOfLength: sizeof(MARFileHeader)];
    MARFileHeader *fileHeader = (MARFileHeader*) [fileHeaderData bytes];
    fileHeader->magic = OSSwapBigToHostInt32(fileHeader->magic);
    fileHeader->offsetToIndex = OSSwapBigToHostInt32(fileHeader->offsetToIndex);
    fileHeader->fileSize = OSSwapBigToHostInt64(fileHeader->fileSize);

    if (fileHeader->magic != 'MAR1') {
        return [NSError errorWithDomain: @"MARFileErrorDomain" code: -1 userInfo: nil];
    }
    
    if (fileHeader->fileSize != _fileSize) {
        return [NSError errorWithDomain: @"MARFileErrorDomain" code: -1 userInfo: nil];
    }
    
    if (fileHeader->offsetToIndex > _fileSize) {
        return [NSError errorWithDomain: @"MARFileErrorDomain" code: -1 userInfo: nil];
    }
    
    _offsetToIndex = fileHeader->offsetToIndex;
    
    // Grab the index header
    
    [_fileHandle seekToFileOffset: _offsetToIndex];
    NSData *indexHeaderData = [_fileHandle readDataOfLength: sizeof(MARIndexHeader)];
    MARIndexHeader *indexHeader = (MARIndexHeader*) [indexHeaderData bytes];
    indexHeader->indexSize = OSSwapBigToHostInt32(indexHeader->indexSize);
    
    _indexSize = indexHeader->indexSize;

    return nil;
}

- (NSError*) readIndex
{
    [_fileHandle seekToFileOffset: _offsetToIndex + sizeof(uint32_t)];
    
    NSData *indexData = [_fileHandle readDataOfLength: _indexSize];
    if ([indexData length] != _indexSize) {
        return [NSError errorWithDomain: @"MARFileErrorDomain" code: -1 userInfo: nil];
    }
    
    const void *p = [indexData bytes];
    NSUInteger remaining = _indexSize;
    
    while (remaining > 0)
    {
        MARIndexEntry *indexEntry = (MARIndexEntry*) p;
        indexEntry->contentSize = OSSwapBigToHostInt32(indexEntry->contentSize);
        indexEntry->offsetToContent = OSSwapBigToHostInt32(indexEntry->offsetToContent);
        indexEntry->permissions = OSSwapBigToHostInt32(indexEntry->permissions);
        
        [_items addObject: [[MARItem alloc] initWithPath: [NSString stringWithCString: indexEntry->path encoding: NSUTF8StringEncoding]
            size: indexEntry->contentSize permissions: indexEntry->permissions offset: indexEntry->offsetToContent]];
        
        remaining -= sizeof(MARIndexEntry) + strlen(indexEntry->path) + 1;
        p += sizeof(MARIndexEntry) + strlen(indexEntry->path) + 1;
    }

    return nil;
}

- (NSError*) readSignatures
{
    return nil;
}

@end
