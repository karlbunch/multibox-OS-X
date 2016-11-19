//
//  MBOPreferencesPane.h
//  MultiBoxOSX
//
//  Created by KARL BUNCH on 10/29/16.
//
//

#import <Cocoa/Cocoa.h>
#import <MASShortcut/Shortcut.h>
#import "MBOKeybinding.h"

@interface MBOPreferencesWindowController : NSWindowController <NSWindowDelegate, NSCollectionViewDataSource, NSCollectionViewDelegate, NSCollectionViewDelegateFlowLayout>

-(instancetype)initWithController:(id)controller;
-(void)keyBindingsChanged;

@end
