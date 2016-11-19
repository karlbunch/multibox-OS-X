//
//  MBOKeybindingHeaderView.h
//  MultiBoxOSX
//
//  Created by KARL BUNCH on 11/13/16.
//
//

#import <Cocoa/Cocoa.h>
#import "MBOKeybinding.h"

@interface MBOKeybindingHeaderView : NSView <NSCollectionViewElement>

-(void)setSectionTitle:(NSString *)title withAction:(kMBOKeybindingAction)action isRecording:(BOOL)isRecording;

@end
