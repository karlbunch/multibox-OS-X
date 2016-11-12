//
//  MBOPreferencesPane.h
//  MultiBoxOSX
//
//  Created by KARL BUNCH on 10/29/16.
//
//

#import <Cocoa/Cocoa.h>
#import <MASShortcut/Shortcut.h>

@interface MBOPreferencesPane : NSPanel {
    IBOutlet NSTextField *targetAppVersionTextField;
    IBOutlet MASShortcutView *pauseShortcut;
}

@property (atomic, strong) NSString *targetApplication;
@property (atomic, strong) NSString *targetAppPath;

- (IBAction)browseButtonClicked:(id)sender;

@end
