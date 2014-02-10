// SITintedView.m


#import "SITintedView.h"


@implementation SITintedView

- (void)drawRect:(NSRect)dirtyRect
{
    CGContextRef context = (CGContextRef) [[NSGraphicsContext currentContext] graphicsPort];
    CGContextSetRGBFillColor(context, 1.0, 0.984, 1.0, 1.0);
    CGContextFillRect(context, NSRectToCGRect(dirtyRect));
}

@end
