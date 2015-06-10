/*
 * The MIT License (MIT)
 *
 * Application: NTFS OS X
 * Copyright (c) 2015 Jeevanandam M. (jeeva@myjeeva.com)
 *
 * Permission is hereby granted, free of charge, to any person obtaining a copy
 * of this software and associated documentation files (the "Software"), to deal
 * in the Software without restriction, including without limitation the rights
 * to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
 * copies of the Software, and to permit persons to whom the Software is
 * furnished to do so, subject to the following conditions:
 *
 * The above copyright notice and this permission notice shall be included in
 * all copies or substantial portions of the Software.
 *
 * THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
 * IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
 * FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
 * AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
 * LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
 * OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
 * THE SOFTWARE.
 */

//
//  NTFSApp.m
//  NTFS-OSX
//
//  Created by Jeevanandam M. on 6/3/15.
//  Copyright (c) 2015 myjeeva.com. All rights reserved.
//

#import "NTFSApp.h"
#import "Arbitration.h"
#import "Disk.h"
#import "LaunchService.h"
#import "ProgressController.h"

@import ServiceManagement;

@implementation NTFSApp

@synthesize statusItem;

- (id)init {
	if (self = [super init]) {
		// Initializing Status Bar and Menus
		[self initStatusBar];

		// Disk Arbitration
		RegisterDA();

		// App & Workspace Notification
		[self registerSession];
        
        progressWindow = [ProgressController new];
        
        NSLog(@"Is NTFS OS X App launch on login: %@", IsAppLaunchOnLogin() ? @"YES" : @"NO");
	}

	return self;
}

- (void)dealloc {
	// Disk Arbitration
	UnregisterDA();

	// App & Workspace Notification
	[self unregisterSession];
}


#pragma mark - Status Menu Methods

- (void)prefMenuClicked:(id)sender {
	NSLog(@"prefMenuClicked: %@", sender);
}

- (void)donateMenuClicked:(id)sender {
	NSLog(@"donateMenuClicked: %@", sender);
}

- (void)supportMenuClicked:(id)sender {
	NSLog(@"supportMenuClicked: %@", sender);
}

- (void)quitMenuClicked:(id)sender {
	[[NSApplication sharedApplication] terminate:self];
}


#pragma mark - Notification Center Methods

- (void)ntfsDiskAppeared:(NSNotification *)notification {
	Disk *disk = notification.object;

	NSLog(@"ntfsDiskAppeared called - %@", disk.BSDName);
	NSLog(@"NTFS Disks Count: %lu", (unsigned long)[ntfsDisks count]);

	if (disk.isNTFSWritable) {
		NSLog(@"NTFS write mode already enabled for '%@'", disk.volumeName);
	} else {
		NSString *msgText = [NSString stringWithFormat:@"Disk detected: %@", disk.volumeName];
		//NSString *infoText = [NSString stringWithFormat:@"Would you like to enable NTFS write mode for disk '%@'", disk.volumeName];

		NSAlert *confirm = [[NSAlert alloc] init];
		[confirm addButtonWithTitle:@"Enable"];
		[confirm addButtonWithTitle:@"Not Required"];
		[confirm setMessageText:msgText];
		[confirm setInformativeText:@"Would you like to enable NTFS write mode for this disk?"];
		[confirm setAlertStyle:NSWarningAlertStyle];
		[confirm setIcon:[NSApp applicationIconImage]];

        [self bringToFront];
		if ([confirm runModal] == NSAlertFirstButtonReturn) {
            [progressWindow show];
			
            [progressWindow statusText:[NSString stringWithFormat:@"Disk '%@' unmounting...", disk.volumeName]];
            [disk unmount];
            [progressWindow incrementProgressBar:30.0];

            [progressWindow statusText:@"Enabling Write mode..."];
			[disk enableNTFSWrite];
            [progressWindow incrementProgressBar:30.0];

            [progressWindow statusText:[NSString stringWithFormat:@"Disk '%@' mounting...", disk.volumeName]];
			[disk mount];            
            [progressWindow incrementProgressBar:30.0];
		}
	}
    
    [progressWindow statusText:@"Opening mounted volume!"];
    [progressWindow close];

	NSString *volumePath = disk.volumePath;
	BOOL isExits = [[NSFileManager defaultManager] fileExistsAtPath:volumePath];
	if (isExits) {
		NSLog(@"Opening mounted NTFS Volume '%@'", volumePath);
		[[NSWorkspace sharedWorkspace] openURL:[NSURL fileURLWithPath:volumePath]];
	}
}

- (void)ntfsDiskDisappeared:(NSNotification *)notification {
	Disk *disk = notification.object;

	NSLog(@"ntfsDiskDisappeared called - %@", disk.BSDName);

	[disk disappeared];
}

- (void)volumeMountNotification:(NSNotification *) notification {
	Disk *disk = [Disk getDiskForUserInfo:notification.userInfo];

	if (disk) {
		NSLog(@"NTFS Disk: '%@' mounted at '%@'", disk.BSDName, disk.volumePath);

		disk.favoriteItem = AddPathToFinderFavorites(disk.volumePath);
		NSLog(@"Added path to favorties");
	}

}

- (void)volumeUnmountNotification:(NSNotification *) notification {
	Disk *disk = [Disk getDiskForUserInfo:notification.userInfo];

	if (disk) {
		NSLog(@"NTFS Disk: '%@' unmounted from '%@'", disk.BSDName, disk.volumePath);

		if (disk.favoriteItem) {
			RemoveItemFromFinderFavorties((LSSharedFileListItemRef)disk.favoriteItem);
			NSLog(@"Removed path from favorties");
		}
	}
}

- (void)toggleLaunchAtStartup:(BOOL)state {
	SMLoginItemSetEnabled((__bridge CFStringRef)AppBundleID, state);
}


#pragma mark - Private Methods

- (void)initStatusBar {
	NSMenu *statusMenu = [[NSMenu alloc] init];

	NSMenuItem *prefMenuItem = [[NSMenuItem alloc] initWithTitle:@"Preferences"
	                            action:@selector(prefMenuClicked:)
	                            keyEquivalent:@""];
	NSMenuItem *donateMenuItem = [[NSMenuItem alloc] initWithTitle:@"Donate"
	                              action:@selector(donateMenuClicked:)
	                              keyEquivalent:@""];
	NSMenuItem *supportMenuItem = [[NSMenuItem alloc] initWithTitle:@"Support"
	                               action:@selector(supportMenuClicked:)
	                               keyEquivalent:@""];
	NSMenuItem *quitMenuIteam = [[NSMenuItem alloc] initWithTitle:@"Quit"
	                             action:@selector(quitMenuClicked:)
	                             keyEquivalent:@""];
	prefMenuItem.target = self;
	donateMenuItem.target = self;
	supportMenuItem.target = self;
	quitMenuIteam.target = self;

	[statusMenu addItem:prefMenuItem];
	[statusMenu addItem:[NSMenuItem separatorItem]];
	[statusMenu addItem:donateMenuItem];
	[statusMenu addItem:supportMenuItem];
	[statusMenu addItem:[NSMenuItem separatorItem]];
	[statusMenu addItem:quitMenuIteam];

	statusItem = [[NSStatusBar systemStatusBar] statusItemWithLength:NSSquareStatusItemLength];
	statusItem.highlightMode = YES;
	statusItem.image = [NSImage imageNamed:AppStatusBarIconName];
	statusItem.toolTip = @"Enable native option of NTFS Write on Mac OSX";
	statusItem.menu = statusMenu;
	statusItem.title = @"";
	[statusItem.image setTemplate:YES];
}

- (void)registerSession {
	// App Level Notification
	NSNotificationCenter *acenter = [NSNotificationCenter defaultCenter];

	[acenter addObserver:self selector:@selector(ntfsDiskAppeared:) name:NTFSDiskAppearedNotification object:nil];
	[acenter addObserver:self selector:@selector(ntfsDiskDisappeared:) name:NTFSDiskDisappearedNotification object:nil];

	// Workspace Level Notification
	NSNotificationCenter *wcenter = [[NSWorkspace sharedWorkspace] notificationCenter];

	[wcenter addObserver:self selector:@selector(volumeMountNotification:) name:NSWorkspaceDidMountNotification object:nil];
	[wcenter addObserver:self selector:@selector(volumeUnmountNotification:) name:NSWorkspaceDidUnmountNotification object:nil];
}

- (void)unregisterSession {
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	[[[NSWorkspace sharedWorkspace] notificationCenter] removeObserver:self];
}

- (void)bringToFront {
    [[NSRunningApplication currentApplication] activateWithOptions:NSApplicationActivateIgnoringOtherApps];
}

@end
