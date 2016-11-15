//
//  MBOKeybindingViewItem.h
//  MultiBoxOSX
//
//  Created by KARL BUNCH on 11/13/16.
//
//

#import <Cocoa/Cocoa.h>
#import "MBOKeybinding.h"

@interface MBOKeybindingViewItem : NSCollectionViewItem

@property (assign) IBOutlet MASShortcutView *shortcutView;

@end
