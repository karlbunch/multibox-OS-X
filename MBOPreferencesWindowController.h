//
//  MBOPreferencesPane.h
//  MultiBoxOSX
//
//  Created by KARL BUNCH on 10/29/16.
//
//

#import <Cocoa/Cocoa.h>
#import <MASShortcut/Shortcut.h>

@interface MBOPreferencesWindowController : NSWindowController <NSWindowDelegate, NSCollectionViewDataSource, NSCollectionViewDelegate, NSCollectionViewDelegateFlowLayout> {
    IBOutlet NSTextField *targetAppVersionTextField;
    IBOutlet NSCollectionView *keyBindingsCollectionView;
    NSMutableArray *keyBindingsBySection;
    id appController;
}

-(IBAction)browseButtonClicked:(id)sender;
-(instancetype) initWithController:(id)controller;
-(void)keyBindingsChanged;

@end
