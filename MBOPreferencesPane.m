//
//  MBOPreferencesPane.m
//  MultiBoxOSX
//
//  Created by KARL BUNCH on 10/29/16.
//
//

#import "MBOPreferencesPane.h"

@implementation MBOPreferencesPane

-(instancetype)initWithContentRect:(NSRect)contentRect styleMask:(NSWindowStyleMask)aStyle backing:(NSBackingStoreType)bufferingType defer:(BOOL)flag {
    self = [super initWithContentRect:contentRect styleMask:aStyle backing:bufferingType defer:flag];

    NSLog(@"[%@ initWithContentRect:(%f, %f) %f x %f styleMask:%lu backing:%lu defer:%d]", [self className], contentRect.origin.x, contentRect.origin.y, contentRect.size.width, contentRect.size.height, (unsigned long)aStyle, (unsigned long)bufferingType, flag);

    return self;
}

-(void)makeKeyAndOrderFront:(id)sender {
    NSLog(@"[%@ makeKeyAndOrderFront:%@", [self className], sender);

    NSBundle *targetBundle = [NSBundle bundleWithPath:self.targetAppPath];

    if (targetBundle != NULL) {
        NSDictionary *targetInfo = [targetBundle infoDictionary];

        NSString *bundleName = [targetInfo objectForKey:@"CFBundleName"];

        if (bundleName && [bundleName length] > 0) {
            [self->targetAppVersionTextField setStringValue:[targetInfo objectForKey:@"CFBundleShortVersionString"]];
        }
    }

    [pauseShortcut setAssociatedUserDefaultsKey:kMBO_Shortcut_Pause];

    [super makeKeyAndOrderFront:sender];
}

- (NSString *)targetApplication {
    return [[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey:kMBO_Preference_TargetApplication];
}

- (void) setTargetApplication:(NSString *)targetApplication {
    [[NSUserDefaults standardUserDefaults] setValue:targetApplication forKey:kMBO_Preference_TargetApplication];
}

- (NSString *)targetAppPath {
    return [[[NSUserDefaultsController sharedUserDefaultsController] values] valueForKey:kMBO_Preference_TargetAppPath];
}

- (void)setTargetAppPath:(NSString *)targetAppPath {
    [[NSUserDefaults standardUserDefaults] setValue:targetAppPath forKey:kMBO_Preference_TargetAppPath];
}

- (IBAction)browseButtonClicked:(id)sender {
    NSOpenPanel *dirBrowser = [NSOpenPanel openPanel];

    [dirBrowser setAllowsMultipleSelection:NO];
    [dirBrowser setCanCreateDirectories:NO];
    [dirBrowser setCanChooseFiles:YES];
    [dirBrowser setCanChooseDirectories:NO];
    [dirBrowser setAllowedFileTypes:@[ @"app" ]];
    [dirBrowser setPrompt:@"Choose"];
    [dirBrowser setMessage:@"Please choose the application to manage:"];

    NSString *newPath = NULL;

    if ([dirBrowser runModal] == NSModalResponseOK) {
        for (NSURL *url in [dirBrowser URLs]) {
            NSLog(@"Selected: %@", url);
            newPath = [url path];
        }
    }

    NSBundle *targetBundle = [NSBundle bundleWithPath:newPath];

    if (targetBundle == NULL) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Invalid Application"];
        [alert setInformativeText:@"Failed to open the Applcation's Bundle."];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert runModal];
        [alert release];
        return;
    }

    self.targetAppPath = newPath;

    NSDictionary *targetInfo = [targetBundle infoDictionary];

    NSLog(@"targetInfo=%@", targetInfo);

    NSString *bundleName = [targetInfo objectForKey:@"CFBundleName"];

    if (bundleName && [bundleName length] > 0) {
        self.targetApplication = bundleName;
        [self->targetAppVersionTextField setStringValue:[targetInfo objectForKey:@"CFBundleShortVersionString"]];
    }
}

@end
