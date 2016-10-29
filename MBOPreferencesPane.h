//
//  MBOPreferencesPane.h
//  MultiBoxOSX
//
//  Created by KARL BUNCH on 10/29/16.
//
//

#import <Cocoa/Cocoa.h>

@interface MBOPreferencesPane : NSPanel {
    IBOutlet NSTextField *targetAppVersionTextField;
}

@property (atomic, strong) NSString *targetApplication;
@property (atomic, strong) NSString *targetAppPath;

- (IBAction)browseButtonClicked:(id)sender;

@end
