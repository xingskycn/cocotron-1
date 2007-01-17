/* Copyright (c) 2006-2007 Christopher J. W. Lloyd

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

// Original - Christopher Lloyd <cjwl@objc.net>, David Young <daver@geeks.org>
#import <AppKit/NSScroller.h>
#import <AppKit/NSApplication.h>
#import <AppKit/NSGraphics.h>
#import <AppKit/NSColor.h>
#import <AppKit/NSImage.h>
#import <AppKit/NSEvent.h>
#import <AppKit/NSWindow.h>
#import <AppKit/NSInterfaceGraphics.h>
#import <AppKit/NSDisplay.h>
#import <AppKit/NSInterfacePart.h>
#import <AppKit/NSNibKeyedUnarchiver.h>

@implementation NSScroller

+(float)scrollerWidth {
   return [[NSDisplay currentDisplay] scrollerWidth];
}

-(void)encodeWithCoder:(NSCoder *)coder {
   NSUnimplementedMethod();
}

-initWithCoder:(NSCoder *)coder {
   [super initWithCoder:coder];

   if([coder isKindOfClass:[NSNibKeyedUnarchiver class]]){
    NSNibKeyedUnarchiver *keyed=(NSNibKeyedUnarchiver *)coder;

    _isVertical=(_bounds.size.width<_bounds.size.height)?YES:NO;
    _floatValue=0;
    _knobProportion=0;
   }
   else {
    [NSException raise:NSInvalidArgumentException format:@"-[%@ %s] is not implemented for coder %@",isa,SELNAME(_cmd),coder];
   }
   return self;
}

-initWithFrame:(NSRect)frame {
   [super initWithFrame:frame];
   _isVertical=(_bounds.size.width<_bounds.size.height)?YES:NO;
   _floatValue=0;
   _knobProportion=0;
   [self checkSpaceForParts];
   return self;
}

-(BOOL)isOpaque {
   return YES;
}

-(BOOL)isFlipped {
   return YES;
}

-(BOOL)refusesFirstResponder {
   return YES;
}

-(BOOL)acceptsFirstResponder {
   return NO;
}

-(void)setFrame:(NSRect)frame {
   [super setFrame:frame];
   [self checkSpaceForParts];
}

-(id)target {
   return _target;
}

-(void)setTarget:(id)target {
   _target=target;
}

-(SEL)action {
   return _action;
}

-(void)setAction:(SEL)action {
   _action=action;
}

-(BOOL)isEnabled {
   return _isEnabled;
}

-(void)setEnabled:(BOOL)flag {
   _isEnabled=flag;
   [self setNeedsDisplay:YES];
}

-(BOOL)isVertical {
   return _isVertical;
}

-(float)floatValue {
   return _floatValue;
}

-(float)knobProportion {
   return _knobProportion;
}

-(NSScrollArrowPosition)arrowsPosition {
   return _arrowsPosition;
}

-(void)setFloatValue:(float)zeroToOneValue knobProportion:(float)zeroToOneKnob {
   _floatValue=zeroToOneValue;
   if(_floatValue>1)
    _floatValue=1;

   _knobProportion=zeroToOneKnob;
   if(_knobProportion>1)
    _knobProportion=1;

   [self setNeedsDisplay:YES];
}

-(void)setArrowsPosition:(NSScrollArrowPosition)position {
   _arrowsPosition=position;
}

-(NSInterfacePart *)minPart {
   if([self isVertical])
    return [NSInterfacePart interfacePartScrollerArrowUpEnabled:[self isEnabled]];
   else
    return [NSInterfacePart interfacePartScrollerArrowLeftEnabled:[self isEnabled]];
}

-(NSInterfacePart *)maxPart {
   if([self isVertical])
    return [NSInterfacePart interfacePartScrollerArrowDownEnabled:[self isEnabled]];
   else
    return [NSInterfacePart interfacePartScrollerArrowRightEnabled:[self isEnabled]];
}

-(NSRect)frameOfDecrementPage {
   NSRect knobSlot=[self rectForPart:NSScrollerKnobSlot];
   NSRect knob=[self rectForPart:NSScrollerKnob];
   NSRect result=knobSlot;

   if(NSIsEmptyRect(knob))
    return NSZeroRect;

   if([self isVertical]){
    result.size.height=(knob.origin.y-knobSlot.origin.y);
    if(result.size.height<=0)
     result=NSZeroRect;
   }
   else {
    result.size.width=(knob.origin.x-knobSlot.origin.x);
    if(result.size.width<=0)
     result=NSZeroRect;
   }

   return result;
}

-(NSRect)frameOfIncrementPage {
   NSRect knobSlot=[self rectForPart:NSScrollerKnobSlot];
   NSRect knob=[self rectForPart:NSScrollerKnob];
   NSRect result=knobSlot;

   if(NSIsEmptyRect(knob))
    return NSZeroRect;

   if([self isVertical]){
    result.origin.y=knob.origin.y+knob.size.height;
    result.size.height=((knobSlot.origin.y+knobSlot.size.height)
        -result.origin.y);
    if(result.size.height<=0)
     result=NSZeroRect;
   }
   else {
    result.origin.x=knob.origin.x+knob.size.width;
    result.size.width=((knobSlot.origin.x+knobSlot.size.width)
        -result.origin.x);
    if(result.size.width<=0)
     result=NSZeroRect;
   }

   return result;
}

static inline float roundFloat(float value){
   value+=0.5;

   return (int)value;
}

-(NSRect)rectForPart:(NSScrollerPart)part {
   NSRect bounds=[self bounds];
   NSRect decLine=bounds;
   NSRect incLine;
   NSRect knobSlot=bounds;
   NSRect knob;
   NSRect result=NSZeroRect;

   if([self isVertical]){
    if(_arrowsPosition==NSScrollerArrowsNone){
     decLine=NSZeroRect;
     incLine=NSZeroRect;
    }
    else {
     decLine.size.height=decLine.size.width;
     if(decLine.size.height*2>bounds.size.height)
      decLine.size.height=floor(bounds.size.height/2);

     incLine=decLine;
     incLine.origin.y=bounds.size.height-incLine.size.height;
    }

    knobSlot.origin.y+=decLine.size.height;
    knobSlot.size.height-=decLine.size.height+incLine.size.height;

    knob=knobSlot;
    knob.size.height=roundFloat(knobSlot.size.height*_knobProportion);
    if(knob.size.height<knob.size.width)
     knob.size.height=knob.size.width;
    knob.origin.y+=floor((knobSlot.size.height-knob.size.height)*_floatValue);

    if(floor(knob.size.height)>=floor(knobSlot.size.height))
     knob=NSZeroRect;
   }
   else {
    if(_arrowsPosition==NSScrollerArrowsNone){
     decLine=NSZeroRect;
     incLine=NSZeroRect;
    }
    else {
     decLine.size.width=decLine.size.height;
     if(decLine.size.width*2>bounds.size.width)
      decLine.size.width=floor(bounds.size.width/2);

     incLine=decLine;
     incLine.origin.x=bounds.size.width-incLine.size.width;
    }

    knobSlot.origin.x+=decLine.size.width;
    knobSlot.size.width-=decLine.size.width+incLine.size.width;

    knob=knobSlot;
    knob.size.width=roundFloat(knobSlot.size.width*_knobProportion);
    if(knob.size.width<knob.size.height)
     knob.size.width=knob.size.height;
    knob.origin.x+=floor((knobSlot.size.width-knob.size.width)*_floatValue);
    if(floor(knob.size.width)>=floor(knobSlot.size.width))
     knob=NSZeroRect;
   }

   switch(part){
    case NSScrollerNoPart:
     result=NSZeroRect;
     break;

    case NSScrollerKnob:
     result=[self isEnabled]?knob:NSZeroRect;
     break;

    case NSScrollerKnobSlot:
     result=knobSlot;
     break;

    case NSScrollerIncrementLine:
     result=incLine;
     break;

    case NSScrollerDecrementLine:
     result=decLine;
     break;
     
    case NSScrollerIncrementPage:
     result=[self frameOfIncrementPage];
     break;
     
    case NSScrollerDecrementPage:
     result=[self frameOfDecrementPage];
     break;
   }

   result=[self centerScanRect:result];

   return result;
}

-(void)checkSpaceForParts {
   _usableParts=NSAllScrollerParts;
}

-(NSUsableScrollerParts)usableParts {
   return _usableParts;
}

-(void)highlight:(BOOL)flag {
   if(_isHighlighted!=flag){
    _isHighlighted=flag;
    [self setNeedsDisplay:YES];
   }
}


-(void)drawParts {
   // do nothing
}

-(void)drawKnob {
   NSRect knob=[self rectForPart:NSScrollerKnob];

   if(!NSIsEmptyRect(knob))
    NSDrawButton(knob,knob);
}

-(void)drawArrow:(NSScrollerArrow)arrow highlight:(BOOL)highlight {
   if(arrow==NSScrollerIncrementArrow){
    NSRect max=[self rectForPart:NSScrollerIncrementLine];

    if(!NSIsEmptyRect(max)){
     NSInterfacePart *maxPart=[self maxPart];
     NSSize           maxPartSize=[maxPart size];

     if(highlight)
      NSInterfaceDrawDepressedScrollerButton(max,max);
     else
      NSInterfaceDrawScrollerButton(max,max);

     if(max.size.height>8 && max.size.width>8){
      NSPoint point=max.origin;

      point.x+=floor((max.size.width-maxPartSize.width)/2);
      point.y+=floor((max.size.height-maxPartSize.height)/2);
      [maxPart drawAtPoint:point];
     }
    }
   }
   else {
    NSRect min=[self rectForPart:NSScrollerDecrementLine];

    if(!NSIsEmptyRect(min)){
     NSInterfacePart *minPart=[self minPart];
     NSSize           minPartSize=[minPart size];

     if(highlight)
      NSInterfaceDrawDepressedScrollerButton(min,min);
     else
      NSInterfaceDrawScrollerButton(min,min);

     if(min.size.height>8 && min.size.width>8){
      NSPoint point=min.origin;

      point.x+=floor((min.size.width-minPartSize.width)/2);
      point.y+=floor((min.size.height-minPartSize.height)/2);
      [minPart drawAtPoint:point];
     }
    }
   }
}


-(void)drawRect:(NSRect)rect {
   NSRect decPage=[self rectForPart:NSScrollerDecrementPage];
   NSRect incPage=[self rectForPart:NSScrollerIncrementPage];
   NSRect slot=[self rectForPart:NSScrollerKnobSlot];
   NSRect knob=[self rectForPart:NSScrollerKnob];
   BOOL   high;

   high=(_hitPart==NSScrollerIncrementLine) && _isHighlighted;
   [self drawArrow:NSScrollerIncrementArrow highlight:high];
   high=(_hitPart==NSScrollerDecrementLine) && _isHighlighted;
   [self drawArrow:NSScrollerDecrementArrow highlight:high];

   if(!NSIsEmptyRect(decPage)){
    [[NSColor colorWithCalibratedWhite:0.9 alpha:1] set];
    NSRectFill(decPage);
   }

   if(!NSIsEmptyRect(incPage)){
    [[NSColor colorWithCalibratedWhite:0.9 alpha:1] set];
    NSRectFill(incPage);
   }

   if(NSIsEmptyRect(knob) && !NSIsEmptyRect(slot)){
    [[NSColor colorWithCalibratedWhite:0.9 alpha:1] set];
    NSRectFill(slot);
   }

   [self drawKnob];
}

-(NSScrollerPart)hitPart {
   return _hitPart;
}

-(NSScrollerPart)testPart:(NSPoint)point {
   int part;

   _hitPart=NSScrollerNoPart;

   for(part=NSScrollerIncrementLine;part<=NSScrollerKnobSlot;part++){
    NSRect rect=[self rectForPart:part];

    if(NSMouseInRect(point,rect,[self isFlipped])){
     _hitPart=part;
     break;
    }
   }

   return _hitPart;
}

-(void)trackKnob:(NSEvent *)event {
   NSPoint firstPoint=[self convertPoint:[event locationInWindow] fromView:nil];
   NSRect  slotRect=[self rectForPart:NSScrollerKnobSlot];
   NSRect  knobRect=[self rectForPart:NSScrollerKnob];
   float   totalSize;
   float   startFloatValue=_floatValue;

   if([self isVertical])
    totalSize=slotRect.size.height-knobRect.size.height;
   else
    totalSize=slotRect.size.width-knobRect.size.width;

   do{
    NSPoint point;
    float   delta;

    [[self window] flushWindow];
    event=[[self window] nextEventMatchingMask:NSLeftMouseUpMask|
                          NSLeftMouseDraggedMask];

    point=[self convertPoint:[event locationInWindow] fromView:nil];

    if([self isVertical])
     delta=point.y-firstPoint.y;
    else
     delta=point.x-firstPoint.x;

    if(totalSize==0)
     _floatValue=0;
    else
     _floatValue=startFloatValue+(delta/totalSize);
    if(_floatValue<0)
     _floatValue=0;
    else if(_floatValue>1.0)
     _floatValue=1.0;

    [self setNeedsDisplay:YES];

    [self sendAction:_action to:_target];

   }while([event type]!=NSLeftMouseUp);
}

-(void)trackScrollButtons:(NSEvent *)event {
   NSRect  rect=[self rectForPart:[self hitPart]];
   NSPoint point=[self convertPoint:[event locationInWindow] fromView:nil];

   // fixup to make paging behavior available via the Alt key, like NEXTSTEP
   if (([event modifierFlags] & NSAlternateKeyMask) && (_hitPart == NSScrollerIncrementLine))
       _hitPart=NSScrollerIncrementPage;
   else if (([event modifierFlags] & NSAlternateKeyMask) && (_hitPart == NSScrollerDecrementLine))
       _hitPart=NSScrollerDecrementPage;

   // scroll every 1/2 second...
   [NSEvent startPeriodicEventsAfterDelay:0.0 withPeriod:0.05];

   do{
       if([event type] != NSPeriodic)	// periodic events have location of 0,0
           point=[self convertPoint:[event locationInWindow] fromView:nil];

       [self highlight:NSMouseInRect(point,rect,[self isFlipped])];
       if (NSMouseInRect(point,rect,[self isFlipped]))
           [self sendAction:_action to:_target];

       [[self window] flushWindow];
       event=[[self window] nextEventMatchingMask:NSPeriodicMask|NSLeftMouseUpMask|NSLeftMouseDraggedMask];
   }while([event type]!=NSLeftMouseUp);

   [NSEvent stopPeriodicEvents];

   [self highlight:NO];
}

-(void)trackPageSlots:(NSEvent *)event {
   do{
    NSPoint point=[self convertPoint:[event locationInWindow] fromView:nil];
    NSRect  knobRect=[self rectForPart:NSScrollerKnob];
    NSRect knobSlotRect=[self rectForPart:NSScrollerKnobSlot];
    float   roundingThreshold;

    // rounding to edges when distance from edge < size of knob
    if ([self isVertical])
        roundingThreshold=knobRect.size.height/knobSlotRect.size.height;
    else
        roundingThreshold=knobRect.size.width/knobSlotRect.size.width;

    if (NSMouseInRect(point,knobSlotRect,[self isFlipped]) && !NSMouseInRect(point,knobRect,[self isFlipped])) {
        // correct for knobSlot origin
        point.x -= knobSlotRect.origin.x;
        point.y -= knobSlotRect.origin.y;
        
        if ([self isVertical])
            _floatValue = point.y/knobSlotRect.size.height;
        else
            _floatValue = point.x/knobSlotRect.size.width;

        if (_floatValue < roundingThreshold)
            _floatValue = 0;
        else if (_floatValue > 1.0 - roundingThreshold)
            _floatValue = 1.0;

        // knobRect may now be different
        knobRect=[self rectForPart:NSScrollerKnob];
        _hitPart=NSScrollerKnobSlot;			// for scroll-to-click

        [self highlight:YES];
        [self sendAction:_action to:_target];
    }

    [[self window] flushWindow];
    event=[[self window] nextEventMatchingMask:NSLeftMouseUpMask|NSLeftMouseDraggedMask];

   }while([event type]!=NSLeftMouseUp);

   [self highlight:NO];
}

-(void)mouseDown:(NSEvent *)event {
   NSPoint        point=[self convertPoint:[event locationInWindow] fromView:nil];
   NSScrollerPart part=[self testPart:point];

   if(![self isEnabled])
    return;

   switch(part){
    case NSScrollerNoPart:
     return;

    case NSScrollerKnob:
     [self trackKnob:event];
     break;

    case NSScrollerKnobSlot:
     break;

    case NSScrollerIncrementLine:
    case NSScrollerDecrementLine:
     [self trackScrollButtons:event];
     break;
     
    case NSScrollerIncrementPage:
    case NSScrollerDecrementPage:
     [self trackPageSlots:event];
     break;
   }

}

@end