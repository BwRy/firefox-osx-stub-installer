// MARFile.h


#import <Foundation/Foundation.h>


@class MARItem, MARSignature;


typedef NS_ENUM(NSUInteger, MARSignatureAlgorithm) {
    MARSignatureAlgorithmRSAPKCS1SHA1 = 1
};


typedef void (^MARFileOpenCallback)(NSError *error);
typedef void (^MARFileItemEnumerator)(MARItem *item, NSData *content, BOOL *stop);
typedef void (^MARFileSignatureEnumerator)(MARSignature *item, BOOL *stop);
typedef void (^MARFileExtractCallback)(MARItem *item, BOOL done, double progress, NSError *error);


@interface MARItem : NSObject
- (instancetype) initWithPath: (NSString*) path size: (NSUInteger) size permissions: (NSUInteger) permissions offset: (NSUInteger) offset;
@property (readonly) NSString *path;
@property (readonly) NSUInteger size;
@property (readonly) NSUInteger permissions;
@property (readonly) NSUInteger offset;
@end

@interface MARSignature : NSObject
@property (readonly) MARSignatureAlgorithm algorithm;
@property (readonly) NSData *signature;
@end

@interface MARFile : NSObject
- (instancetype) initWithPath: (NSString*) path;
- (void) openUsingCallback: (MARFileOpenCallback) callback;
- (void) enumerateItemsUsingBlock: (MARFileItemEnumerator) block;
- (void) extractItemsToRoot: (NSString*) root usingCallback: (MARFileExtractCallback) block;
- (void) close;
@property (readonly) NSArray *items;
@end
