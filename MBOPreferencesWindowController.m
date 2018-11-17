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

@interface MBOPreferencesWindowController () {
    __weak IBOutlet NSTextField *_targetAppVersionTextField;
    __weak IBOutlet NSCollectionView *_keyBindingsCollectionView;
    __weak id _appController;
    NSMutableArray *_keyBindingsBySection;
    CFMachPortRef _eventTap;
    CFRunLoopSourceRef _eventRunLoop;
    BOOL _isRecording;
    NSMutableOrderedSet *_recordedKeys;
    kMBOKeybindingAction _recordAction;
}

-(IBAction)browseButtonClicked:(id)sender;

@end

@implementation MBOPreferencesWindowController

-(instancetype)init {
    self = [super initWithWindowNibName:@"PreferencesWindow"];
    return self;
}

-(instancetype)initWithController:(id)controller {
    self = [self init];
    _appController = controller;
    return self;
}

-(void)windowDidLoad {
    NSBundle *targetBundle = [NSBundle bundleWithPath:self.targetAppPath];

    if (targetBundle != NULL) {
        NSDictionary *targetInfo = [targetBundle infoDictionary];

        NSString *bundleName = [targetInfo objectForKey:@"CFBundleName"];

        if (bundleName && [bundleName length] > 0) {
            [_targetAppVersionTextField setStringValue:[targetInfo objectForKey:@"CFBundleShortVersionString"]];
        }
    }

    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(observeRecordKeysButtonClicked:) name:kMBO_Notification_RecordKeysButtonClicked object:nil];

    _isRecording = NO;

    [self buildKeybindingCollection];
}

-(void)keyBindingsChanged {
    [self buildKeybindingCollection];
    [_keyBindingsCollectionView reloadData];
}

-(void)buildKeybindingCollection {
    _keyBindingsBySection = [[NSMutableArray alloc] init];

    [_keyBindingsBySection addObject:[[NSMutableArray alloc] init]];
    [_keyBindingsBySection addObject:[[NSMutableArray alloc] init]];
    [_keyBindingsBySection addObject:[[NSMutableArray alloc] init]];

    MainController *ctlr = (MainController *)_appController;

    NSMutableArray *keys = [[NSMutableArray alloc] init];
    NSDictionary *currentBindings = [ctlr keyBindingsDictionaryRepresentation];

    for (id idx in currentBindings) {
        [keys addObject:[currentBindings objectForKey:idx]];
    }

    NSSortDescriptor *sortByKeyCodeString = [NSSortDescriptor sortDescriptorWithKey:@"keyCodeString" ascending:YES];
    [keys sortUsingDescriptors:[NSArray arrayWithObject:sortByKeyCodeString]];

    for (MBOKeybinding *key in keys) {
        [_keyBindingsBySection[[self actionToSection:key.action]] addObject:key];
    }

    [_keyBindingsBySection[0] addObject:[MBOKeybinding unboundShortcutWithAction:[self sectionToAction:0]]];
    [_keyBindingsBySection[1] addObject:[MBOKeybinding unboundShortcutWithAction:[self sectionToAction:1]]];
    [_keyBindingsBySection[2] addObject:[MBOKeybinding unboundShortcutWithAction:[self sectionToAction:2]]];
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

-(void)observeRecordKeysButtonClicked:(NSNotification *)notification {
    if (![notification.name isEqualToString:kMBO_Notification_RecordKeysButtonClicked]) {
        NSLog(@"Unexpected name in observeRecordKeysButtonClicked:%@", notification.name);
        return;
    }

    [self stopRecordingKeys];

    NSNumber *state = notification.userInfo[@"state"];
    NSNumber *actionNumber = notification.userInfo[@"action"];
    _recordAction = (kMBOKeybindingAction)[actionNumber intValue];
    NSLog(@"observeRecordKeysButtonClicked: action=%@ state=%@", [MBOKeybinding NSStringWithMBOKeybindingAction:_recordAction], state);

    if ([state isGreaterThan:@(0)]) {
        [self startRecordingKeys];
    }
}

-(CGEventRef)recordEventType:(CGEventType)eventType event:(CGEventRef)event {
    if (!_isRecording) {
        return event;
    }

    if (eventType != kCGEventKeyDown) {
        return nil;
    }

    CGKeyCode keycode = (CGKeyCode)CGEventGetIntegerValueField(event, kCGKeyboardEventKeycode);
    CGEventFlags flags = CGEventGetFlags(event);

    MBOKeybinding *key = [MBOKeybinding shortcutWithKeyCode:keycode modifierFlags:flags bindingAction:_recordAction];
//    NSLog(@"recordEvent: type=%u event=%@ keycode=%d flags=0x%llx MBOKeybinding=%@", eventType, event, keycode, flags, key);

    if (![_recordedKeys containsObject:key]) {
        [_recordedKeys addObject:key];
        NSMutableArray *sectionKeys = _keyBindingsBySection[[self actionToSection:_recordAction]];
        MBOKeybinding *lastKey = [sectionKeys lastObject];
        [sectionKeys removeLastObject];
        [sectionKeys addObject:key];
        [sectionKeys addObject:lastKey];
        [_keyBindingsCollectionView reloadData];
        MainController *ctlr = (MainController *)_appController;
        [ctlr addKeyBinding:key];
    }

    return nil;
}

CGEventRef RecordKeyboardEventTapCallBack (CGEventTapProxy proxy, CGEventType type, CGEventRef event, void *refcon) {
    MBOPreferencesWindowController *controller = (__bridge MBOPreferencesWindowController *)refcon;
    return [controller recordEventType:type event:event];
}

-(void)startRecordingKeys {
    if (_isRecording) {
        NSLog(@"already recording!?");
        return;
    }

    NSLog(@"\n\n#####################\n## START RECORDING ##\n#####################\n\n");
    _recordedKeys = [[NSMutableOrderedSet alloc] init];

    NSArray *currentKeys = _keyBindingsBySection[[self actionToSection:_recordAction]];

    for (MBOKeybinding *key in currentKeys) {
        if (key.isBound) {
            [_recordedKeys addObject:key];
        }
    }

    if (_eventTap == NULL) {
        CGEventMask eventMask = CGEventMaskBit(kCGEventKeyDown) | CGEventMaskBit(kCGEventKeyUp) | CGEventMaskBit(kCGEventFlagsChanged);

        _eventTap = CGEventTapCreate(
            kCGSessionEventTap,
            kCGTailAppendEventTap,
            kCGEventTapOptionDefault,
            eventMask,
            RecordKeyboardEventTapCallBack,
            (__bridge void * _Nullable)(self)
        );

        _eventRunLoop = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, _eventTap, 0);

        CFRunLoopAddSource(CFRunLoopGetCurrent(), _eventRunLoop, kCFRunLoopDefaultMode);
    }

    _isRecording = YES;
}

-(void)stopRecordingKeys {
    NSLog(@"\n\n####################\n## STOP RECORDING ##\n####################\n\n");
    _isRecording = NO;

    if (_recordedKeys) {
#if DEBUG
        [_recordedKeys enumerateObjectsUsingBlock:^(id  _Nonnull obj, NSUInteger idx, BOOL * _Nonnull stop) {
            MBOKeybinding *key = (MBOKeybinding *)obj;
            NSLog(@"Key: %@", key.debugDescription);
        }];
#endif
        _recordedKeys = NULL;
        _recordAction = 0;
    }
}

#pragma mark NSCollectionViewDataSource Methods

-(NSInteger)numberOfSectionsInCollectionView:(NSCollectionView *)collectionView {
    return 3;
}

-(NSInteger)collectionView:(NSCollectionView *)collectionView numberOfItemsInSection:(NSInteger)section {
    return [_keyBindingsBySection[section] count];
}

-(NSCollectionViewItem *)collectionView:(NSCollectionView *)collectionView itemForRepresentedObjectAtIndexPath:(NSIndexPath *)indexPath {
    NSCollectionViewItem * __weak item = [collectionView makeItemWithIdentifier:@"MBOKeybindingViewItem" forIndexPath:indexPath];

    if (indexPath.item < [_keyBindingsBySection[indexPath.section] count]) {
        item.representedObject = _keyBindingsBySection[indexPath.section][indexPath.item];
    }

    return item;
}

- (nonnull NSView *)collectionView:(nonnull NSCollectionView *)collectionView viewForSupplementaryElementOfKind:(nonnull NSString *)kind atIndexPath:(nonnull NSIndexPath *)indexPath {
    if ([kind isEqual:NSCollectionElementKindSectionHeader]) {
        kMBOKeybindingAction sectionAction = [self sectionToAction:indexPath.section];
        NSView *view = [collectionView makeSupplementaryViewOfKind:kind withIdentifier:@"MBOKeybindingHeaderView" forIndexPath:indexPath];
        MBOKeybindingHeaderView *headerView = (MBOKeybindingHeaderView *)view;
        NSString *title = [NSString stringWithFormat:@"%@ Keys:", [MBOKeybinding NSStringWithMBOKeybindingAction:sectionAction]];
        [headerView setSectionTitle:title withAction:sectionAction isRecording:(_isRecording && sectionAction == _recordAction) ? YES : NO];
        return view;
    }

    return (id _Nonnull)nil;
}

#pragma mark NSCollectionViewDelegateFlowLayout Methods

- (NSSize)collectionView:(NSCollectionView *)collectionView layout:(NSCollectionViewLayout*)collectionViewLayout referenceSizeForHeaderInSection:(NSInteger)section {
    return NSMakeSize(10000, 40);
}

- (NSSize)collectionView:(NSCollectionView *)collectionView layout:(NSCollectionViewLayout *)collectionViewLayout referenceSizeForFooterInSection:(NSInteger)section {
    return NSZeroSize;
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
        [_targetAppVersionTextField setStringValue:[targetInfo objectForKey:@"CFBundleShortVersionString"]];
    }
}

#pragma mark Object Cleanup

-(BOOL)windowShouldClose:(id)sender {
    if (_isRecording) {
        [self stopRecordingKeys];
    }

    if (_eventRunLoop) {
        CFRunLoopRemoveSource(CFRunLoopGetCurrent(), _eventRunLoop, kCFRunLoopDefaultMode);
        CFRelease(_eventRunLoop);
        _eventRunLoop = NULL;
    }

    if (_eventTap) {
        CFRelease(_eventTap);
        _eventTap = NULL;
    }
    
    if (self->_appController)
        [(MainController *)_appController preferencesWindowWillClose:self];
    return YES;
}

-(void)dealloc {
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

@end
