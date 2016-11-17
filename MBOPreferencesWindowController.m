//
//  MBOPreferencesPane.m
//  MultiBoxOSX
//
//  Created by KARL BUNCH on 10/29/16.
//
//

#import "MainController.h"
#import "MBOPreferencesWindowController.h"
#import "MBOKeybindingHeaderView.h"

@implementation MBOPreferencesWindowController

-(instancetype)init {
    self = [super initWithWindowNibName:@"PreferencesWindow"];
    return self;
}

-(instancetype)initWithController:(id)controller {
    self = [self init];
    self->appController = controller;
    return self;
}

-(void)windowDidLoad {
    NSBundle *targetBundle = [NSBundle bundleWithPath:self.targetAppPath];

    if (targetBundle != NULL) {
        NSDictionary *targetInfo = [targetBundle infoDictionary];

        NSString *bundleName = [targetInfo objectForKey:@"CFBundleName"];

        if (bundleName && [bundleName length] > 0) {
            [self->targetAppVersionTextField setStringValue:[targetInfo objectForKey:@"CFBundleShortVersionString"]];
        }
    }

    [self buildKeybindingCollection];
}

-(BOOL)windowShouldClose:(id)sender {
    if (self->appController)
        [(MainController *)self->appController preferencesWindowWillClose:self];
    return YES;
}

-(void)keyBindingsChanged {
    [self buildKeybindingCollection];
    [keyBindingsCollectionView reloadData];
}

-(void)buildKeybindingCollection {
    keyBindingsBySection = [[NSMutableArray alloc] init];

    [keyBindingsBySection addObject:[[NSMutableArray alloc] init]];
    [keyBindingsBySection addObject:[[NSMutableArray alloc] init]];
    [keyBindingsBySection addObject:[[NSMutableArray alloc] init]];

    MainController *ctlr = (MainController *)self->appController;

    NSMutableArray *keys = [[NSMutableArray alloc] init];

    for (id idx in ctlr.keyBindings) {
        [keys addObject:[ctlr.keyBindings objectForKey:idx]];
    }

    NSSortDescriptor *sortByKeyCodeString = [NSSortDescriptor sortDescriptorWithKey:@"keyCodeString" ascending:YES];
    [keys sortUsingDescriptors:[NSArray arrayWithObject:sortByKeyCodeString]];

    for (MBOKeybinding *key in keys) {
        [keyBindingsBySection[[self actionToSection:key.action]] addObject:key];
    }

    [keyBindingsBySection[0] addObject:[MBOKeybinding unboundShortcutWithAction:[self sectionToAction:0]]];
    [keyBindingsBySection[1] addObject:[MBOKeybinding unboundShortcutWithAction:[self sectionToAction:1]]];
    [keyBindingsBySection[2] addObject:[MBOKeybinding unboundShortcutWithAction:[self sectionToAction:2]]];
}

-(NSInteger)actionToSection:(kMBOKeybindingAction )action {
    switch(action) {
        case kMBOKeybindingActionToggleForwarding:  return 0;
        case kMBOKeybindingActionIgnore:            return 1;
        case kMBOKeybindingActionWhitelist:         return 2;
        default: return -1;
    }
}

-(kMBOKeybindingAction)sectionToAction:(NSInteger)section {
    switch(section) {
        case 0: return kMBOKeybindingActionToggleForwarding;
        case 1: return kMBOKeybindingActionIgnore;
        case 2: return kMBOKeybindingActionWhitelist;
        default: return 0;
    }
}

#pragma mark NSCollectionViewDataSource Methods

-(NSInteger)numberOfSectionsInCollectionView:(NSCollectionView *)collectionView {
    return 3;
}

-(NSInteger)collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [self->keyBindingsBySection[section] count];
}

-(NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath {
    NSCollectionViewItem * __weak item = [collectionView makeItemWithIdentifier:@"MBOKeybindingViewItem" forIndexPath:indexPath];

    if (indexPath.item < [keyBindingsBySection[indexPath.section] count]) {
        item.representedObject = self->keyBindingsBySection[indexPath.section][indexPath.item];
    }

    return item;
}

- (nonnull NSView *)collectionView:(nonnull NSCollectionView *)collectionView viewForSupplementaryElementOfKind:(nonnull NSString *)kind atIndexPath:(nonnull NSIndexPath *)indexPath {
    if ([kind isEqual:NSCollectionElementKindSectionHeader]) {
        NSView * __weak view = [collectionView makeSupplementaryViewOfKind:kind withIdentifier:@"MBOKeybindingHeaderView" forIndexPath:indexPath];
        MBOKeybindingHeaderView *headerView = (MBOKeybindingHeaderView *)view;
        NSString *title = [NSString stringWithFormat:@"%@ Keys:", [MBOKeybinding NSStringWithMBOKeybindingAction:[self sectionToAction:indexPath.section]]];
        [headerView setSectionTitle:title];
        return view;
    }

    return nil;
}

#pragma mark NSCollectionViewDelegateFlowLayout Methods

- (NSSize)collectionView:(NSCollectionView *)collectionView layout:(NSCollectionViewLayout*)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section {
    return NSMakeSize(10000, 40);
}

- (NSSize)collectionView:(NSCollectionView *)collectionView layout:(NSCollectionViewLayout *)collectionViewLayout referenceSizeForFooterInSection:(NSInteger)section {
    return NSZeroSize;
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

    if (newPath == NULL) {
        return;
    }

    NSBundle *targetBundle = [NSBundle bundleWithPath:newPath];

    if (targetBundle == NULL) {
        NSAlert *alert = [[NSAlert alloc] init];
        [alert addButtonWithTitle:@"OK"];
        [alert setMessageText:@"Invalid Application"];
        [alert setInformativeText:@"Failed to open the Applcation's Bundle."];
        [alert setAlertStyle:NSWarningAlertStyle];
        [alert runModal];
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
