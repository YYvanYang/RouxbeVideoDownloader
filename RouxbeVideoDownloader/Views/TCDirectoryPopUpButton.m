//
//  TCDirectoryPopUpButton.m
//  RouxbeVideoDownloader
//
//  Created by Lee Tze Cheun on 2/14/13.
//  Copyright (c) 2013 Lee Tze Cheun. All rights reserved.
//

#import "TCDirectoryPopUpButton.h"

@implementation TCDirectoryPopUpButton

#pragma mark - NIB

- (void)awakeFromNib
{
    [self createMenuItems];
}

#pragma mark - Pop Up Menu Items

/**
 * Create the initial menu items for \c TCDirectoryPopUpButton.
 */
- (void)createMenuItems
{
    // Clear any menu items created automatically in the NIB.
    [self.menu removeAllItems];
        
    // Add a separator to the menu.
    [self.menu addItem:[NSMenuItem separatorItem]];
    
    // Add an "Other..." menu item to open a NSOpenPanel for user to select
    // another directory.
    NSMenuItem *selectDirectoryMenuItem = [[NSMenuItem alloc] init];
    selectDirectoryMenuItem.title = NSLocalizedString(@"Other...", @"Pop up menu item to select a custom directory.");
    selectDirectoryMenuItem.action = @selector(chooseDirectory:);
    selectDirectoryMenuItem.target =  self;
    [self.menu addItem:selectDirectoryMenuItem];
}

/** 
 * User clicked on "Other..." menu item to choose a custom Downloads 
 * directory.
 */
- (IBAction)chooseDirectory:(id)sender
{
    // Configure NSOpenPanel to only allow directories selection.
    NSOpenPanel *openPanel = [NSOpenPanel openPanel];
    openPanel.canChooseDirectories = YES;
    openPanel.canCreateDirectories = YES;
    openPanel.canChooseFiles = NO;
    openPanel.allowsMultipleSelection = NO;
    openPanel.prompt = NSLocalizedString(@"Select", @"Button to confirm directory selection.");
    openPanel.directoryURL = self.directoryURL;
    
    [openPanel beginSheetModalForWindow: self.window completionHandler:^(NSInteger result) {
        if (NSFileHandlingPanelOKButton == result) {
            // Fire the action on the target object only when the directory has
            // been changed.
            if (![self.directoryURL isEqual:openPanel.directoryURL]) {
                self.directoryURL = openPanel.directoryURL;
                [self sendAction:self.action to:self.target];
            }
        }

        // Reset selection to the directory menu item. We never want the
        // selection to remain on the "Other..." menu item.
        [self selectItemAtIndex:0];
    }];
}

#pragma mark - Directory URL

- (void)setDirectoryURL:(NSURL *)directoryURL
{
    NSParameterAssert(directoryURL);

    // If the same directory was selected, we re-select the
    // directory menu item and do nothing else.
    if ([_directoryURL isEqual:directoryURL]) {
        [self selectItemAtIndex:0];
        return;
    }
    
    _directoryURL = [directoryURL copy];

    // Get the icon for the selected directory.
    NSImage *iconImage = [[NSWorkspace sharedWorkspace] iconForFile:
                          [_directoryURL path]];
    iconImage.size = NSMakeSize(16, 16);

    // Create the NSMenuItem for the selected directory.
    NSMenuItem *directoryMenuItem = [[NSMenuItem alloc] init];
    directoryMenuItem.title = [_directoryURL lastPathComponent];
    directoryMenuItem.image = iconImage;

    // If first menu item is not a separator, it means there was a previously
    // selected directory. So, we have to remove that first.
    if (![[self.menu itemAtIndex:0] isSeparatorItem]) {
        [self.menu removeItemAtIndex:0];
    }

    // Insert this newly selected directory as the first menu item.
    // Automatically select the new directory in the pop-up menu.
    [self.menu insertItem:directoryMenuItem atIndex:0];
    [self selectItemAtIndex:0];
}

@end
