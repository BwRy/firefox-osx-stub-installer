// AppDelegate.h


#import <Cocoa/Cocoa.h>


@interface AppDelegate : NSObject <NSApplicationDelegate>

@property (assign) IBOutlet NSWindow *window;

@property (assign) IBOutlet NSView *introContainerView;

@property (assign) IBOutlet NSView *installerContainerView;
@property (assign) IBOutlet NSProgressIndicator *installerProgressIndicator;
@property (assign) IBOutlet NSTextField *installerDownloadingLabel;
@property (assign) IBOutlet NSTextField *installerInstallingLabel;
@property (assign) IBOutlet NSImageView *installerBackground;

@property (assign) IBOutlet NSView *messageContainerView;
@property (assign) IBOutlet NSView *clockMessageView;
@property (assign) IBOutlet NSView *particlesMessageView;
@property (assign) IBOutlet NSView *pencilMessageView;

@property (assign) IBOutlet NSView *successContainerView;

@end
