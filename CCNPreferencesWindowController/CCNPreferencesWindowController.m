//
//  Created by Frank Gregor on 16.01.15.
//  Copyright (c) 2015 cocoa:naut. All rights reserved.
//

/*
 The MIT License (MIT)
 Copyright © 2014 Frank Gregor, <phranck@cocoanaut.com>
 http://cocoanaut.mit-license.org

 Permission is hereby granted, free of charge, to any person obtaining a copy
 of this software and associated documentation files (the “Software”), to deal
 in the Software without restriction, including without limitation the rights
 to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 copies of the Software, and to permit persons to whom the Software is
 furnished to do so, subject to the following conditions:

 The above copyright notice and this permission notice shall be included in
 all copies or substantial portions of the Software.

 THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 THE SOFTWARE.
 */

#import <QuartzCore/QuartzCore.h>
#import "CCNPreferencesWindowController.h"


static NSString *const CCNPreferencesToolbarIdentifier                 = @"CCNPreferencesMainToolbar";
static NSString *const CCNPreferencesToolbarSegmentedControlIdentifier = @"CCNPreferencesToolbarSegmentedControl";
static NSString *const CCNPreferencesWindowFrameAutoSaveName           = @"CCNPreferencesWindowFrameAutoSaveName";
static NSString *const CCNPreferencesWindowLastFrame                   = @"CCNPreferencesWindowLastFrame";
static NSString *const CCNPreferencesViewLastFrameFormat               = @"CCNPreferencesView%@Frame";
static NSRect CCNPreferencesDefaultWindowRect;
static NSSize CCNPreferencesToolbarSegmentedControlItemInset;
static unsigned short const CCNEscapeKey = 53;


/**
 ====================================================================================================================
 */
#pragma mark CCNPreferencesWindow
#pragma mark -
@interface CCNPreferencesWindow : NSWindow

- (void)setToolbarStyle:(NSInteger)style;

@end

/**
 ====================================================================================================================
 */
#pragma mark CCNImageView
#pragma mark -
@interface CCNImageView : NSButton
@property (retain) NSString *itemIdentifier;
@end

/**
 ====================================================================================================================
 */

#pragma mark - CCNPreferencesWindowController
#pragma mark -

@interface CCNPreferencesWindowController() <NSToolbarDelegate, NSWindowDelegate>

@property (strong) NSToolbar *toolbar;
@property (strong) NSSegmentedControl *segmentedControl;
@property (strong) NSMutableArray *toolbarDefaultItemIdentifiers;

@property (strong) NSMutableOrderedSet *viewControllers;
@property (strong) id<CCNPreferencesWindowControllerProtocol> activeViewController;
@end

@implementation CCNPreferencesWindowController

+ (void)initialize {
    CCNPreferencesToolbarSegmentedControlItemInset = NSMakeSize(36, 12);
}

- (instancetype)init {
    self = [super init];
    if (self) {
        [self setupDefaults];
    }
    return self;
}

- (void)setupDefaults {
    self.viewControllers = [[NSMutableOrderedSet alloc] init];
    self.activeViewController = nil;
    self.window = [[CCNPreferencesWindow alloc] init];

    self.showToolbarWithSingleViewController = YES;
    self.showToolbarItemsAsSegmentedControl = NO;
    self.centerToolbarItems = YES;
    self.toolbarItemSpacing = 0.0;
    self.showToolbarSeparator = YES;
    self.allowsVibrancy = NO;
    self.titleVisibility = YES;
    self.shouldAllowToolBarCustomization = NO;
}

- (void)setupToolbar {
    self.window.toolbar = nil;
    self.toolbar = nil;
    self.toolbarDefaultItemIdentifiers = nil;

    if (self.showToolbarWithSingleViewController || self.showToolbarItemsAsSegmentedControl || self.viewControllers.count > 1) {
        self.toolbar = [[NSToolbar alloc] initWithIdentifier:CCNPreferencesToolbarIdentifier];

        if (self.showToolbarItemsAsSegmentedControl) {
            self.toolbar.allowsUserCustomization = NO;
            self.toolbar.autosavesConfiguration = NO;
            self.toolbar.displayMode = NSToolbarDisplayModeIconOnly;

            // segment control configuration
            [self setupSegmentedControl];
        }
        else {
            self.toolbar.allowsUserCustomization = self.shouldAllowToolBarCustomization;
            self.toolbar.autosavesConfiguration = YES;
            self.toolbar.displayMode = NSToolbarDisplayModeIconAndLabel;
        }

        self.toolbar.showsBaselineSeparator = self.showToolbarSeparator;
        self.toolbar.delegate = self;
        self.window.toolbar = self.toolbar;
    }
}

- (void)setupSegmentedControl {
    self.segmentedControl = [[NSSegmentedControl alloc] init];
    self.segmentedControl.segmentCount = self.viewControllers.count;
    self.segmentedControl.segmentStyle = NSSegmentStyleTexturedSquare;
    self.segmentedControl.target = self;
    self.segmentedControl.action = @selector(segmentedControlAction:);
    self.segmentedControl.identifier = CCNPreferencesToolbarSegmentedControlIdentifier;

    [self.segmentedControl.cell setControlSize:NSRegularControlSize];
    [self.segmentedControl.cell setTrackingMode:NSSegmentSwitchTrackingSelectOne];

    NSSize segmentSize = [self maxSegmentSizeForCurrentViewControllers];

    self.segmentedControl.frame = NSMakeRect(0, 0, segmentSize.width * self.viewControllers.count + (self.viewControllers.count + 1), segmentSize.height);

    __weak typeof(self) wSelf = self;
    [self.viewControllers enumerateObjectsUsingBlock:^(NSViewController *vc, NSUInteger idx, BOOL *stop) {
        NSString *title = [vc performSelector:@selector(preferenceTitle)];
        [wSelf.segmentedControl setLabel:title forSegment:idx];
        [wSelf.segmentedControl setWidth:segmentSize.width forSegment:idx];
        [wSelf.segmentedControl.cell setTag:idx forSegment:idx];
    }];
}

- (void)dealloc {
    _viewControllers = nil;
    _activeViewController = nil;
    _toolbar = nil;
    _toolbarDefaultItemIdentifiers = nil;
}

#pragma mark - API

- (void)setPreferencesViewControllers:(NSArray *)viewControllers {
    for (id viewController in viewControllers) {
        [self addPreferencesViewController:viewController];
    }
    [self setupToolbar];
}

- (void)showPreferencesWindow {
    self.window.alphaValue = 0.0;
    [self showWindow:self];
    [self.window makeKeyAndOrderFront:self];
    [[NSApplication sharedApplication] activateIgnoringOtherApps:YES];

    [self activateViewController:self.viewControllers[0] animate:NO];
    if (self.window.toolbar) {
        if (self.showToolbarItemsAsSegmentedControl) {
            [self.segmentedControl selectSegmentWithTag:0];
        }
        else {
            [self.window.toolbar setSelectedItemIdentifier:self.toolbarDefaultItemIdentifiers[(self.centerToolbarItems ? 1 : 0)]];
        }
    }
    self.window.alphaValue = 1.0;
}

- (void)dismissPreferencesWindow {
    [self close];
}

#pragma mark - Custom Accessors

- (void)setKeepWindowAlwaysOnTop:(BOOL)keepWindowAlwaysOnTop {
    if (_keepWindowAlwaysOnTop != keepWindowAlwaysOnTop) {
        [self.window setLevel:NSStatusWindowLevel];
    }
}

- (void)setTitlebarAppearsTransparent:(BOOL)titlebarAppearsTransparent {
    self.window.titlebarAppearsTransparent = titlebarAppearsTransparent;
}

- (void)setTitleVisibility:(BOOL)titleVisibility {
    if (_titleVisibility == titleVisibility) {
        self.window.titleVisibility = NSWindowTitleHidden;
    }
}

- (void)setCenterToolbarItems:(BOOL)centerToolbarItems {
    if (_centerToolbarItems != centerToolbarItems) {
        _centerToolbarItems = centerToolbarItems;
        self.toolbarDefaultItemIdentifiers = nil;
        [self setupToolbar];
    }
}

- (void)setToolbarItemSpacing:(float)toolbarItemSpacing {
    if (_toolbarItemSpacing != toolbarItemSpacing) {
        _toolbarItemSpacing = toolbarItemSpacing;
        self.toolbarDefaultItemIdentifiers = nil;
        [self setupToolbar];
    }
}

- (void)setShowToolbarItemsAsSegmentedControl:(BOOL)showToolbarItemsAsSegmentedControl {
    if (_showToolbarItemsAsSegmentedControl != showToolbarItemsAsSegmentedControl) {
        _showToolbarItemsAsSegmentedControl = showToolbarItemsAsSegmentedControl;
        self.toolbarDefaultItemIdentifiers = nil;
        self.centerToolbarItems = YES;
        [self setupToolbar];
    }
}

#pragma mark - Helper

- (NSSize)maxSegmentSizeForCurrentViewControllers {
    NSSize maxSize = NSMakeSize(42, 0);
    for (NSViewController *vc in self.viewControllers) {
        NSString *title = [vc performSelector:@selector(preferenceTitle)];
        NSSize titleSize = [title sizeWithAttributes:@{ NSFontAttributeName: [NSFont systemFontOfSize:[NSFont systemFontSizeForControlSize:NSRegularControlSize]] }];
        if (titleSize.width + CCNPreferencesToolbarSegmentedControlItemInset.width > maxSize.width) {
            maxSize = NSMakeSize(ceilf(titleSize.width) + CCNPreferencesToolbarSegmentedControlItemInset.width, ceilf(titleSize.height) + CCNPreferencesToolbarSegmentedControlItemInset.height);
        }
    }
    return maxSize;
}

- (void)addPreferencesViewController:(id<CCNPreferencesWindowControllerProtocol>)viewController {
    NSAssert([viewController conformsToProtocol:@protocol(CCNPreferencesWindowControllerProtocol)], @"ERROR: The viewController [%@] must conform to protocol <CCNPreferencesWindowControllerProtocol>", [viewController class]);

    [self.viewControllers addObject:viewController];
}

- (id<CCNPreferencesWindowControllerProtocol>)viewControllerWithIdentifier:(NSString *)identifier {
    for (id<CCNPreferencesWindowControllerProtocol> vc in self.viewControllers) {
        if ([[vc preferenceIdentifier] isEqualToString:identifier]) {
            return vc;
        }
    }
    return nil;
}

- (BOOL)showViewControllerWithIdentifier:(NSString *)identifier {
    BOOL result = NO;
    if([self viewControllerWithIdentifier:identifier]) {
        for(NSToolbarItem *item in self.toolbar.items) {
            if([item.itemIdentifier isEqualToString:identifier] && item.target) {
                [NSApp sendAction:item.action to:item.target from:item];
                result = YES;
            }
        }
    }
    return result;
}

- (void)activateViewController:(id<CCNPreferencesWindowControllerProtocol>)viewController animate:(BOOL)animate {
    // Save the current viewController's frame
    if(self.activeViewController) {
        NSString *currentFrameKey  = [NSString stringWithFormat:CCNPreferencesViewLastFrameFormat, self.activeViewController.preferenceIdentifier];
        [[NSUserDefaults standardUserDefaults] setObject:NSStringFromRect([(NSViewController *)self.activeViewController view].frame) forKey:currentFrameKey];
    }
    
    // Now get the new viewController's default and saved frames
    NSRect viewControllerFrame     = [(NSViewController *)viewController view].frame;
    NSString *lastFrameKey         = [NSString stringWithFormat:CCNPreferencesViewLastFrameFormat, viewController.preferenceIdentifier];
    NSString *lastFrame            = [[NSUserDefaults standardUserDefaults] objectForKey:lastFrameKey];
    
    if(lastFrame.length > 0) {
        NSRect rect = NSRectFromString(lastFrame);
        if(NSHeight(rect) > NSHeight(viewControllerFrame))
            viewControllerFrame.size.height = rect.size.height;
    }

    // We have to juggle the origin because the frame is specified from the
    // bottom left and we want to keep the window's title bar in the same place.
    NSRect currentWindowFrame      = self.window.frame;
    NSRect frameRectForContentRect = [self.window frameRectForContentRect:viewControllerFrame];

    CGFloat deltaX = NSWidth(currentWindowFrame) - NSWidth(frameRectForContentRect);
    CGFloat deltaY = NSHeight(currentWindowFrame) - NSHeight(frameRectForContentRect);
    NSRect newWindowFrame = NSMakeRect(NSMinX(currentWindowFrame) + (self.centerToolbarItems ? deltaX / 2 : 0),
                                       NSMinY(currentWindowFrame) + deltaY,
                                       NSWidth(frameRectForContentRect),
                                       NSHeight(frameRectForContentRect));

    if (self.showToolbarItemsAsSegmentedControl) {
        self.window.title = NSLocalizedString(@"Preferences", @"CCNPreferencesWindow: default window title with segmented control in toolbar");
    }
    else {
        self.window.title = [NSString stringWithFormat:@"%@ : %@", [[NSRunningApplication currentApplication] localizedName], [viewController preferenceTitle]];
    }

    NSView *newContentView = [(NSViewController *)viewController view];
    newContentView.alphaValue = 0.0;

    if (self.allowsVibrancy) {
        NSVisualEffectView *effectView = [[NSVisualEffectView alloc] initWithFrame:newContentView.frame];
        effectView.blendingMode = NSVisualEffectBlendingModeBehindWindow;
        [effectView addSubview:newContentView];
        self.window.contentView = effectView;
    }
    else {
        NSView *view = [[NSView alloc] initWithFrame:newContentView.frame];
        [view addSubview:newContentView];
        self.window.contentView = view;
    }

    __weak typeof(self) wSelf = self;
    [NSAnimationContext runAnimationGroup:^(NSAnimationContext *context) {
        context.duration = (animate ? 0.25 : 0);
        context.timingFunction = [CAMediaTimingFunction functionWithName:kCAMediaTimingFunctionEaseInEaseOut];
        [[wSelf.window animator] setFrame:newWindowFrame display:YES];
        [[newContentView animator] setAlphaValue:1.0];

    } completionHandler:^{
        wSelf.activeViewController = viewController;
    }];
}

#pragma mark - NSToolbarItem Actions

- (void)toolbarItemAction:(NSToolbarItem *)toolbarItem {
    if (![[self.activeViewController preferenceIdentifier] isEqualToString:toolbarItem.itemIdentifier]) {
        id<CCNPreferencesWindowControllerProtocol> vc = [self viewControllerWithIdentifier:toolbarItem.itemIdentifier];
        [self activateViewController:vc animate:NO];
        self.toolbar.selectedItemIdentifier = toolbarItem.itemIdentifier;
    }
}

#pragma mark - NSToolbarItem Actions

- (void)segmentedControlAction:(NSSegmentedControl *)segmentedControl {
    id<CCNPreferencesWindowControllerProtocol> vc = self.viewControllers[[segmentedControl.cell tagForSegment:segmentedControl.selectedSegment]];
    if (![[self.activeViewController preferenceIdentifier] isEqualToString:[vc preferenceIdentifier]]) {
        [self activateViewController:vc animate:YES];
    }
}

#pragma mark - NSToolbarDelegate

- (NSToolbarItem *)toolbar:(NSToolbar *)toolbar itemForItemIdentifier:(NSString *)itemIdentifier willBeInsertedIntoToolbar:(BOOL)flag {
    if ([itemIdentifier isEqualToString:NSToolbarFlexibleSpaceItemIdentifier]) {
        return nil;
    }

    else if ([itemIdentifier isEqualToString:CCNPreferencesToolbarSegmentedControlIdentifier]) {
        NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:itemIdentifier];
        toolbarItem.view = self.segmentedControl;

        return toolbarItem;
    }

    else {
        id<CCNPreferencesWindowControllerProtocol> vc = [self viewControllerWithIdentifier:itemIdentifier];
        NSString *identifier = [vc preferenceIdentifier];
        NSString *label      = [vc preferenceTitle];
        NSImage *icon        = [vc preferenceIcon];
        NSString *toolTip    = nil;
        if ([vc respondsToSelector:@selector(preferenceToolTip)]) {
            toolTip = [vc preferenceToolTip];
        }

        NSToolbarItem *toolbarItem = [[NSToolbarItem alloc] initWithItemIdentifier:identifier];
        NSOperatingSystemVersion version = NSProcessInfo.processInfo.operatingSystemVersion;
        
        // Set up item spacing if it's specified and we're running on a version of macOS prior to
        // Big Sur. As of Big Sur, NSWindowToolbarStylePreference will take care of this for us.
        if(self.toolbarItemSpacing > 0 && version.majorVersion == 10 && version.minorVersion < 16) {
            float iconHeight = (toolbar.sizeMode == NSToolbarSizeModeSmall) ? 24 : 32;
            float iconSpacing = self.toolbarItemSpacing * ((toolbar.sizeMode == NSToolbarSizeModeSmall) ?  0.75 : 1.0);
            NSSize iconSize = NSMakeSize(iconHeight + iconSpacing, iconHeight);
            CCNImageView *view = [[CCNImageView alloc] initWithFrame:NSMakeRect(0, 0, iconSize.width, iconSize.height)];

            view.target                = self;
            view.action                = @selector(toolbarItemAction:);
            view.itemIdentifier        = identifier;
            view.image                 = icon;
            toolbarItem.view           = view;
            toolbarItem.minSize        = iconSize;
            toolbarItem.maxSize        = iconSize;
        }
        else {
            toolbarItem.target         = self;
            toolbarItem.action         = @selector(toolbarItemAction:);
            toolbarItem.image          = icon;
        }
        toolbarItem.label          = label;
        toolbarItem.paletteLabel   = label;
        toolbarItem.toolTip        = toolTip;
        
        return toolbarItem;
    }
}

- (NSArray *)toolbarDefaultItemIdentifiers:(NSToolbar *)toolbar {
    if (!self.toolbarDefaultItemIdentifiers && self.viewControllers.count > 0) {
        self.toolbarDefaultItemIdentifiers = [[NSMutableArray alloc] init];

        // the toolbar will be presented with a segmentedControl
        if (self.showToolbarItemsAsSegmentedControl) {
            [self.toolbarDefaultItemIdentifiers insertObject:NSToolbarFlexibleSpaceItemIdentifier atIndex:0];
            [self.toolbarDefaultItemIdentifiers insertObject:CCNPreferencesToolbarSegmentedControlIdentifier atIndex:self.toolbarDefaultItemIdentifiers.count];
            [self.toolbarDefaultItemIdentifiers insertObject:NSToolbarFlexibleSpaceItemIdentifier atIndex:self.toolbarDefaultItemIdentifiers.count];
        }

        // the toolbar will be presented with standard NSToolbarItem's
        else {
            if (self.centerToolbarItems) {
                [self.toolbarDefaultItemIdentifiers insertObject:NSToolbarFlexibleSpaceItemIdentifier atIndex:0];
            }

            NSInteger offset = self.toolbarDefaultItemIdentifiers.count;
            __weak typeof(self) wSelf = self;
            [self.viewControllers enumerateObjectsUsingBlock:^(id<CCNPreferencesWindowControllerProtocol>vc, NSUInteger idx, BOOL *stop) {
                [wSelf.toolbarDefaultItemIdentifiers insertObject:[vc preferenceIdentifier] atIndex:idx + offset];
            }];

            if (self.centerToolbarItems) {
                [self.toolbarDefaultItemIdentifiers insertObject:NSToolbarFlexibleSpaceItemIdentifier atIndex:self.toolbarDefaultItemIdentifiers.count];
            }
        }
    }
    return self.toolbarDefaultItemIdentifiers;
}

- (NSArray *)toolbarAllowedItemIdentifiers:(NSToolbar *)toolbar {
    return [self toolbarDefaultItemIdentifiers:toolbar];
}

- (NSArray *)toolbarSelectableItemIdentifiers:(NSToolbar *)toolbar {
    return [self toolbarDefaultItemIdentifiers:toolbar];
}

@end




/**
 ====================================================================================================================
 */

#pragma mark - CCNPreferencesWindow
#pragma mark -

@implementation CCNPreferencesWindow

+ (void)initialize {
    CCNPreferencesDefaultWindowRect = NSMakeRect(0, 0, 420, 230);
}

- (instancetype)init {
    NSRect frameRect = CCNPreferencesDefaultWindowRect;
    NSString *lastFrame = [[NSUserDefaults standardUserDefaults] objectForKey:CCNPreferencesWindowLastFrame];
    if(lastFrame) frameRect = NSRectFromString(lastFrame);
    self = [super initWithContentRect:frameRect
                            styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask | NSUnifiedTitleAndToolbarWindowMask | NSResizableWindowMask)
                              backing:NSBackingStoreBuffered
                                defer:YES];
    if (self) {
        [self center];
        self.frameAutosaveName = CCNPreferencesWindowFrameAutoSaveName;
        [self setFrameFromString:CCNPreferencesWindowFrameAutoSaveName];
        if (@available(macOS 10.16, *)) {
            if([self respondsToSelector:@selector(setToolbarStyle:)])
                [self setToolbarStyle:2]; // NSWindowToolbarStylePreference
        }
    }
    return self;
}

- (void)keyDown:(NSEvent *)theEvent {
    switch(theEvent.keyCode) {
        case CCNEscapeKey:
            [self orderOut:nil];
            [self close];
            break;
        default: [super keyDown:theEvent];
    }
}

- (void)close {
    [[NSUserDefaults standardUserDefaults] setObject:NSStringFromRect(self.frame) forKey:CCNPreferencesWindowLastFrame];
    [super close];
}

@end


/**
 ====================================================================================================================
 */

#pragma mark - CCNImageView
#pragma mark -

@implementation CCNImageView

- (id)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if(self) {
        self.bezelStyle = NSRegularSquareBezelStyle;
        self.buttonType = NSMomentaryChangeButton;
        self.imagePosition = NSImageOnly;
        self.bordered = NO;
    }
    return self;
}

@end
