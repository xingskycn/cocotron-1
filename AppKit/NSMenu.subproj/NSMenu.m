/* Copyright (c) 2006-2007 Christopher J. W. Lloyd

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

// Original - Christopher Lloyd <cjwl@objc.net>, David Young <daver@geeks.org>
#import <AppKit/NSMenu.h>
#import <AppKit/NSMenuItem.h>
#import <AppKit/NSApplication.h>
#import <AppKit/NSWindow.h>
#import <AppKit/NSEvent.h>
#import <AppKit/NSMenuWindow.h>
#import <AppKit/NSMenuView.h>
#import <AppKit/NSNibKeyedUnarchiver.h>

@implementation NSMenu

+(void)popUpContextMenu:(NSMenu *)menu withEvent:(NSEvent *)event forView:(NSView *)view {
   if([[menu itemArray] count]>0){
    NSPoint       point=[event locationInWindow];
    NSWindow     *window=[event window];
    NSMenuWindow *menuWindow=[[NSMenuWindow alloc] initWithMenu:menu];
    NSMenuView   *menuView=[menuWindow menuView];
    NSMenuItem   *item;

    [menuWindow setReleasedWhenClosed:YES];
    [menuWindow setFrameTopLeftPoint:[window convertBaseToScreen:point]];
    [menuWindow orderFront:nil];

    item=[menuView trackForEvent:event];
 
    [menuWindow close];

    if(item!=nil)
     [NSApp sendAction:[item action] to:[item target] from:item];
   }
}

-(void)encodeWithCoder:(NSCoder *)coder {
   [coder encodeObject:_title forKey:@"NSMenu title"];
   [coder encodeObject:_itemArray forKey:@"NSMenu itemArray"];
   [coder encodeBool:_autoenablesItems forKey:@"NSMenu autoenablesItems"];
}

-initWithCoder:(NSCoder *)coder {
   if([coder isKindOfClass:[NSNibKeyedUnarchiver class]]){
    NSNibKeyedUnarchiver *keyed=(NSNibKeyedUnarchiver *)coder;
    
    _title=[[keyed decodeObjectForKey:@"NSTitle"] copy];
    _itemArray=[[NSMutableArray alloc] initWithArray:[keyed decodeObjectForKey:@"NSMenuItems"]];
    _autoenablesItems=![keyed decodeBoolForKey:@"NSNoAutoenable"];
   }
   else {
    _title=[[coder decodeObjectForKey:@"NSMenu title"] retain];
    _itemArray=[[coder decodeObjectForKey:@"NSMenu itemArray"] retain];
    _autoenablesItems=[coder decodeBoolForKey:@"NSMenu autoenablesItems"];
   }
   return self;
}

-initWithTitle:(NSString *)title {
   _title=[title copy];
   _itemArray=[NSMutableArray new];
   _autoenablesItems=YES;
   return self;
}

-init {
   return [self initWithTitle:@""];
}

-(void)dealloc {
   [_title release];
   [_itemArray release];
   [super dealloc];
}

-copyWithZone:(NSZone *)zone {
   return [self retain];
}

-(NSString *)title {
   return _title;
}

-(int)numberOfItems {
   return [_itemArray count];
}

-(NSArray *)itemArray {
   return _itemArray;
}

-(BOOL)autoenablesItems {
   return _autoenablesItems;
}

-(NSMenuItem *)itemAtIndex:(int)index {
   return [_itemArray objectAtIndex:index];
}

-(NSMenuItem *)itemWithTag:(int)tag {
    int i,count=[_itemArray count];

    for(i=0;i<count;i++){
        NSMenuItem *item=[_itemArray objectAtIndex:i];

        if ([item tag] == tag)
            return item;
    }

    return nil;
}

-(NSMenuItem *)itemWithTitle:(NSString *)title {
   int i,count=[_itemArray count];

   for(i=0;i<count;i++){
    NSMenuItem *item=[_itemArray objectAtIndex:i];

    if([[item title] isEqualToString:title])
     return item;
   }

   return nil;
}

-(int)indexOfItem:(NSMenuItem *)item {
    return [_itemArray indexOfObjectIdenticalTo:item];
}

-(int)indexOfItemWithTag:(int)tag {
    int i,count=[_itemArray count];

    for (i=0; i<count; ++i)
        if ([[_itemArray objectAtIndex:i] tag] == tag)
            return i;

    return -1;
}

-(int)indexOfItemWithTitle:(NSString *)title {
    int i,count=[_itemArray count];

    for (i=0;i<count;i++)
        if ([[[_itemArray objectAtIndex:i] title] isEqualToString:title])
            return i;

    return -1;
}

-(int)indexOfItemWithRepresentedObject:(id)object {
    NSUnimplementedMethod();	// hmmm...
    return -1;
}

// needed this for NSApplication windowsMenu stuff, so i did 'em all..
-(int)indexOfItemWithTarget:(id)target andAction:(SEL)action {
    int i,count=[_itemArray count];

    for (i=0; i<count; ++i) {
        NSMenuItem *item = [_itemArray objectAtIndex:i];

        if ([item target] == target) {
            if (action == NULL)
                return i;
            else if ([item action] == action)
                return i;
        }
    }

    return -1;
}

-(int)indexOfItemWithSubmenu:(NSMenu *)submenu {
    int i, count=[_itemArray count];

    for (i = 0; i < count; ++i) 
        if ([[_itemArray objectAtIndex:i] submenu] == submenu)
            return i;

    return -1;
}

-(void)setAutoenablesItems:(BOOL)flag {
   _autoenablesItems=flag;
}

-(void)addItem:(NSMenuItem *)item {
   [_itemArray addObject:item];
}

-(NSMenuItem *)addItemWithTitle:(NSString *)title action:(SEL)action keyEquivalent:(NSString *)keyEquivalent {
   NSMenuItem *item=[[[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:keyEquivalent] autorelease];

   [self addItem:item];

   return item;
}

-(void)removeAllItems {
   while([_itemArray count]>0)
    [self removeItem:[_itemArray lastObject]];
}

-(void)removeItem:(NSMenuItem *)item {
   [_itemArray removeObjectIdenticalTo:item];
}

-(void)removeItemAtIndex:(int)index {
   [self removeItem:[_itemArray objectAtIndex:index]];
}

-(void)insertItem:(NSMenuItem *)item atIndex:(int)index {
   [_itemArray insertObject:item atIndex:index];
}

-(NSMenuItem *)insertItemWithTitle:(NSString *)title action:(SEL)action keyEquivalent:(NSString *)keyEquivalent atIndex:(int)index {
   NSMenuItem *item=[[[NSMenuItem alloc] initWithTitle:title action:action keyEquivalent:keyEquivalent] autorelease];

   [self insertItem:item atIndex:index];

   return item;
}

-(void)setSubmenu:(NSMenu *)submenu forItem:(NSMenuItem *)item {
   [item setSubmenu:submenu];
}

-(void)update {
   int i,count=[_itemArray count];

   for(i=0;i<count;i++){
    NSMenuItem *item=[_itemArray objectAtIndex:i];

    if(_autoenablesItems){
     BOOL enabled=NO;

     if([item action]!=NULL){
      id target=[item target];

      if(target==nil)
       target=[NSApp targetForAction:[item action]];

      if(target!=nil){
       if(![target respondsToSelector:@selector(validateMenuItem:)])
        enabled=YES;
       else
        enabled=[target validateMenuItem:item];
      }
     }

     if(enabled!=[item isEnabled]){
      [item setEnabled:enabled];
      [self itemChanged:item];
     }
    }

    [[item submenu] update];
   }
}

-(void)itemChanged:(NSMenuItem *)item {
}

-(BOOL)performKeyEquivalent:(NSEvent *)event {
   int       i,count=[_itemArray count];
   NSString *characters=[event charactersIgnoringModifiers];
   unsigned  modifiers=[event modifierFlags];

   if (_autoenablesItems)
    [self update];

   for(i=0;i<count;i++){
    NSMenuItem *item=[_itemArray objectAtIndex:i];
    unsigned    itemModifiers=[item keyEquivalentModifierMask];

    if((modifiers&(NSCommandKeyMask|NSAlternateKeyMask))==itemModifiers){
     NSString *key=[item keyEquivalent];

     if([key isEqualToString:characters]){
      if ([item isEnabled])
       [NSApp sendAction:[item action] to:[item target] from:item];
      else
       NSBeep();
      return YES;
     }
    }
    
    if([[item submenu] performKeyEquivalent:event])
     return YES;
   }

   return NO;
}

@end