// AppDelegate.m


#import <QuartzCore/CoreAnimation.h>

#import "MARFile.h"
#import "ASIHTTPRequest.h"
#import "AppDelegate.h"


@implementation AppDelegate {
    NSView *_currentContainerView;
    NSURL *_fileURL;
    NSString *_fileName;
    NSString *_filePath;
    ASIHTTPRequest *_downloadRequest;
    long long _fileTotalBytes;
    long long _fileDownloadedBytes;
    CATransition *_transition;
    NSView *_currentMessageView;
}

- (void) setContainerView: (NSView*) containerView
{
    if (_currentContainerView != nil) {
        [self.window.contentView replaceSubview: _currentContainerView with: containerView];
    } else {
        [self.window.contentView addSubview: containerView];
    }
    _currentContainerView = containerView;
}

#pragma mark -

- (void) applicationDidFinishLaunching: (NSNotification*) aNotification
{
    // Insert code here to initialize your application
}

- (void) awakeFromNib
{
    _transition = [CATransition animation];
    [_transition setType:kCATransitionPush];
    [_transition setSubtype:kCATransitionFromLeft];

    [self setContainerView: self.introContainerView];
    
    [self.installerProgressIndicator setMaxValue: 1.33];
    [self.installerDownloadingLabel setTextColor: [NSColor grayColor]];
    [self.installerInstallingLabel setTextColor: [NSColor grayColor]];

    // We are going to download the installer to ~/Library/Caches/$APPIDENTIFIER/ so we need to first find that full path and then create it if it does not exist.

    NSString* cachesDirectory = [NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES) lastObject];
    NSString *applicationCacheDirectory = [cachesDirectory stringByAppendingPathComponent: [[NSBundle mainBundle] bundleIdentifier]];
    
    NSError *createDirectoryError = nil;
    if ([[NSFileManager defaultManager] createDirectoryAtPath: applicationCacheDirectory withIntermediateDirectories: YES attributes: nil error: &createDirectoryError] == NO) {
        // TODO: Error handling
        return;
    }
    
    // TODO: This has to come from a web service
    _fileURL = [NSURL URLWithString: @"http://ftp.mozilla.org/pub/mozilla.org/firefox/nightly/2014/02/2014-02-08-03-02-07-mozilla-central/firefox-30.0a1.en-US.mac.complete.mar"];
    _fileName = @"firefox-30.0a1.en-US.mac.complete.mar";
    _filePath = [applicationCacheDirectory stringByAppendingPathComponent: _fileName];
}

#pragma mark - IntroContainerView

- (IBAction)introViewHandleOptions:(id)sender
{
    NSBeep();
}

- (IBAction)introViewHandleInstall:(id)sender
{
    [self setContainerView: self.installerContainerView];
    [self installViewStartDownload];

    NSDictionary *animations = [NSDictionary dictionaryWithObject: _transition forKey: @"subviews"];
    [_messageContainerView setAnimations:animations];
}

#pragma mark - InstallContainerView

- (IBAction) installViewHandleCancel:(id)sender
{
    if (_downloadRequest) {
        [_downloadRequest cancel];
    }
    
    [self setContainerView: self.introContainerView];
}

- (void)request:(ASIHTTPRequest *)request incrementDownloadSizeBy:(long long)newLength
{
    _fileTotalBytes += newLength;
}

- (void)request:(ASIHTTPRequest *)request didReceiveBytes:(long long)bytes;
{
    _fileDownloadedBytes += bytes;
    
    double percentageDownloaded = (double) _fileDownloadedBytes / (double) _fileTotalBytes;
    [self.installerProgressIndicator setDoubleValue: percentageDownloaded];
}

- (void) downloadRequestFinished:(ASIHTTPRequest *)request
{
    [self installViewStartInstallation];
}

- (void) downloadRequestFailed: (ASIHTTPRequest *)request
{
}

- (void) showParticlesMessage
{
    [[_messageContainerView animator] replaceSubview: _currentMessageView with: self.particlesMessageView];
    _currentMessageView = self.particlesMessageView;
}

- (void) showPencilMessage
{
    [[_messageContainerView animator] replaceSubview: _currentMessageView with: self.pencilMessageView];
    _currentMessageView = self.pencilMessageView;
}

- (void) installViewStartDownload
{
//    self.clockMessageView.frame = CGRectOffset(self.clockMessageView.frame, 0, 100);
//    self.particlesMessageView.frame = CGRectOffset(self.particlesMessageView.frame, 0, 100);
//    self.pencilMessageView.frame = CGRectOffset(self.pencilMessageView.frame, 0, 100);

    [_messageContainerView addSubview: self.clockMessageView];
    _currentMessageView = self.clockMessageView;
    
    [NSTimer scheduledTimerWithTimeInterval: 5.0 target: self selector: @selector(showParticlesMessage) userInfo:nil repeats:NO];
    [NSTimer scheduledTimerWithTimeInterval: 10.0 target: self selector: @selector(showPencilMessage) userInfo:nil repeats:NO];

    // If the file exists then the download finished previously.
    
    if ([[NSFileManager defaultManager] fileExistsAtPath: _filePath]) {
        [self installViewStartInstallation];
        return;
    }
    
    // Start a download for the Firefox installer
    
    _downloadRequest = [ASIHTTPRequest requestWithURL: _fileURL];
    _downloadRequest.downloadDestinationPath = _filePath;
    _downloadRequest.temporaryFileDownloadPath = [_filePath stringByAppendingPathExtension: @"download"];
    _downloadRequest.allowResumeForFileDownloads = YES;
    _downloadRequest.delegate = self;
    _downloadRequest.didFinishSelector = @selector(downloadRequestFinished:);
    _downloadRequest.didFailSelector = @selector(downloadRequestFailed:);
    _downloadRequest.downloadProgressDelegate = self;
    [_downloadRequest startAsynchronous];

    [self.installerDownloadingLabel setTextColor: [NSColor blackColor]];
}

- (void) terminate
{
    exit(0);
}

- (void) installViewStartInstallation
{
    // Create the app directory
    
    NSError *createDirectoryError = nil;
    if ([[NSFileManager defaultManager] createDirectoryAtPath: @"/Applications/Firefox Nighty (Stub Installed).app" withIntermediateDirectories: YES attributes: nil error: &createDirectoryError] == NO) {
        NSAlert *theAlert = [NSAlert alertWithError: createDirectoryError];
        [theAlert runModal];
        return;
    }

    // Extract the download
    
    [self.installerInstallingLabel setTextColor: [NSColor blackColor]];
    [self.installerProgressIndicator setDoubleValue: 1.0];
    
    MARFile *archive = [[MARFile alloc] initWithPath: _filePath];
    [archive openUsingCallback:^(NSError *error) {
        [archive extractItemsToRoot: @"/Applications/Firefox Nighty (Stub Installed).app" usingCallback:^(MARItem *item, BOOL done, double progress, NSError *error) {
            if (error != nil) {
                NSAlert *theAlert = [NSAlert alertWithError: error];
                [theAlert runModal];
            } else {
                if (done) {
                    //[self setContainerView: self.successContainerView];
                    //[self successViewLaunchFirefox];
                    [[NSWorkspace sharedWorkspace] launchApplication: @"/Applications/Firefox Nighty (Stub Installed).app"];
                    [self performSelector:@selector(terminate) withObject:nil afterDelay:2.5];
                } else {
                    double percentageInstalled = 0.33 * progress;
                    [self.installerProgressIndicator setDoubleValue: 1.0 + percentageInstalled];
                }
            }
        }];
    }];
}

#pragma mark - SuccessContainerView

- (void) successViewLaunchFirefox
{
    [[NSWorkspace sharedWorkspace] launchApplication: @"/Applications/Firefox Nighty (Stub Installed).app"];
}

@end
