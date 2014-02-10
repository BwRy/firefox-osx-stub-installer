// MARFileTestCase.m


#import <XCTest/XCTest.h>
#import "MARFile.h"


@interface MARFileTestCase : XCTestCase

@end


@implementation MARFileTestCase

- (void) testOpen
{
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    MARFile *file = [[MARFile alloc] initWithPath: @"/Users/stefan/tmp/firefox-29.0a1.en-US.mac.complete.mar"];
    XCTAssertNotNil(file);
    
    [file openUsingCallback:^(NSError *error) {
        XCTAssertNil(error);
        XCTAssertNotNil(file.items);
        XCTAssertTrue([file.items count] == 112);
        dispatch_semaphore_signal(sem);
    }];
    
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
}

- (void) testEnumerate
{
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    MARFile *file = [[MARFile alloc] initWithPath: @"/Users/stefan/tmp/firefox-29.0a1.en-US.mac.complete.mar"];
    XCTAssertNotNil(file);
    
    [file openUsingCallback:^(NSError *error) {
        XCTAssertNil(error);
        XCTAssertNotNil(file.items);
        XCTAssertTrue([file.items count] == 112);
        __block NSUInteger totalItemsEnumerated = 0;
        [file enumerateItemsUsingBlock:^(MARItem *item, NSData *content, BOOL *stop) {
            XCTAssertNotNil(item);
            XCTAssertNotNil(content);
            XCTAssertTrue(item.size == [content length]);
            totalItemsEnumerated++;
        }];
        XCTAssertTrue(totalItemsEnumerated == 112);
        dispatch_semaphore_signal(sem);
    }];
    
    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
}

- (void) testExtract
{
    dispatch_semaphore_t sem = dispatch_semaphore_create(0);

    MARFile *file = [[MARFile alloc] initWithPath: @"/Users/stefan/tmp/firefox-29.0a1.en-US.mac.complete.mar"];
    XCTAssertNotNil(file);
    
    [file openUsingCallback:^(NSError *error) {
        XCTAssertNil(error);
        if (error == nil) {
            [file extractItemsToRoot: @"/Users/stefan/tmp/FirefoxExtractedByInstaller.app" usingCallback:^(MARItem *item, double progress, NSError *error) {
                XCTAssertNil(error);
                if (progress == 100.0) {
                    dispatch_semaphore_signal(sem);
                }
            }];
        } else {
            dispatch_semaphore_signal(sem);
        }
    }];

    dispatch_semaphore_wait(sem, DISPATCH_TIME_FOREVER);
}

@end
