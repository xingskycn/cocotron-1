/* Copyright (c) 2006-2007 Christopher J. W. Lloyd

Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE. */

// Original - David Young <daver@geeks.org>, Christopher Lloyd <cjwl@objc.net>
#import <Foundation/ObjCClass.h>
#import <Foundation/ObjCSelector.h>
#import "Protocol.h"
#import <Foundation/NSZone.h>
#import <Foundation/ObjCException.h>
#import <Foundation/ObjCModule.h>
#import <stdio.h>
#import "objc_cache.h"

#ifdef WIN32
#import <windows.h>
#endif
#ifdef SOLARIS
#import <stdarg.h>
#endif

#define INITIAL_CLASS_HASHTABLE_SIZE	256

static inline OBJCHashTable *OBJCClassTable(void) {
   static OBJCHashTable *allClasses=NULL;

   if(allClasses==NULL)
    allClasses=OBJCCreateHashTable(INITIAL_CLASS_HASHTABLE_SIZE);

   return allClasses;
}

Class OBJCClassFromString(const char *name) {
   return OBJCHashValueForKey(OBJCClassTable(),name);
}

id objc_getClass(const char *name) {
   return OBJCHashValueForKey(OBJCClassTable(),name);
}

Class objc_lookUpClass(const char *className) {
   return OBJCHashValueForKey(OBJCClassTable(),className);
}

void objc_addClass(Class class) {
   OBJCRegisterClass(class);
}

// I think this is generated by the compiler
// to get the class pre-posing, since we don't support posing
// just use the normal thing
id objc_getOrigClass(const char *name) {
   return OBJCHashValueForKey(OBJCClassTable(),name);
}

static void OBJCRegisterSelectorsInMethodList(OBJCMethodList *list){
  int i;

  for (i=0;i<list->method_count;i++)
    list->method_list[i].method_name=OBJCRegisterMethod(list->method_list+i);
}

static void OBJCRegisterSelectorsInClass(Class class) {
   OBJCMethodList *node;

   for(node=class->methodLists;node!=NULL;node=node->next)
    OBJCRegisterSelectorsInMethodList(node);
}

static void OBJCInitializeCacheEntry(OBJCMethodCacheEntry *entry){
   static OBJCMethod empty={
    0,NULL,NULL
   };
   
   entry->offsetToNextEntry=-((long)entry);
   entry->method=&empty;
}

static void OBJCCreateCacheForClass(Class class){
   if(class->cache==NULL){
    int i;
    
    class->cache=NSZoneCalloc(NULL,1,sizeof(OBJCMethodCache));
    
    for(i=0;i<OBJCMethodCacheNumberOfEntries;i++){
     OBJCInitializeCacheEntry(class->cache->table+i);
    }
   }
}


void OBJCRegisterClass(Class class) {
    
   OBJCHashInsertValueForKey(OBJCClassTable(), class->name, class);

   OBJCRegisterSelectorsInClass(class);
   OBJCRegisterSelectorsInClass(class->isa);

   {
    OBJCProtocolList *protocols;

    for(protocols=class->protocols;protocols!=NULL;protocols=protocols->next){
     unsigned i;

     for(i=0;i<protocols->count;i++){
      OBJCProtocolTemplate *template=(OBJCProtocolTemplate *)protocols->list[i];

      OBJCRegisterProtocol(template);
     }
    }
   }

   OBJCCreateCacheForClass(class);
   OBJCCreateCacheForClass(class->isa);

   if(class->super_class==NULL){
     // Root class
    class->isa->isa=class;
    class->isa->super_class=class;
    class->info|=CLASS_INFO_LINKED;
   }
}

static void OBJCAppendMethodListToClass(Class class, OBJCMethodList *methodList) {
   methodList->next=class->methodLists;
   class->methodLists=methodList;
   
   OBJCRegisterSelectorsInMethodList(methodList);
}

void OBJCRegisterCategoryInClass(OBJCCategory *category,Class class) {
   OBJCProtocolList *protos;

   if(category->instanceMethods!=NULL)
    OBJCAppendMethodListToClass(class,category->instanceMethods);
   if(category->classMethods!=NULL)
    OBJCAppendMethodListToClass(class->isa,category->classMethods);

   for(protos=category->protocols;protos!=NULL;protos=protos->next){
    unsigned i;

    for (i=0;i<protos->count;i++)
     OBJCRegisterProtocol((OBJCProtocolTemplate *)protos->list[i]);
   }
}

static void OBJCLinkClass(Class class) {
   if(!(class->info&CLASS_INFO_LINKED)){
    Class superClass=OBJCClassFromString((const char *)class->super_class);
	
    if(superClass!=NULL){
     class->super_class=superClass;
     class->info|=CLASS_INFO_LINKED;
     class->isa->super_class=class->super_class->isa;
     class->isa->info|=CLASS_INFO_LINKED;
	}
   }
}

void OBJCLinkClassTable(void) {
   OBJCHashTable *hashTable=OBJCClassTable();
   Class          class;
   OBJCHashEnumerator  state=OBJCEnumerateHashTable(hashTable);

   while((class=OBJCNextHashEnumeratorValue(&state))!=Nil)
    OBJCLinkClass(class);
}

static inline OBJCMethod *OBJCLookupUniqueIdInMethodList(OBJCMethodList *list,SEL uniqueId){
   int i;

   for(i=0;i<list->method_count;i++){
    if(((SEL)list->method_list[i].method_name)==uniqueId)
     return list->method_list+i;
   }

   return NULL;
}

static inline OBJCMethod *OBJCLookupUniqueIdInOnlyThisClass(Class class,SEL uniqueId){
   OBJCMethod     *result=NULL;
   OBJCMethodList *check;

   for(check=class->methodLists;check!=NULL;check=check->next)
    if((result=OBJCLookupUniqueIdInMethodList(check,uniqueId))!=NULL)
     break;

   return result;
}

inline OBJCMethod *OBJCLookupUniqueIdInClass(Class class,SEL uniqueId) {
   OBJCMethod *result=NULL;

   for(;class!=NULL;class=class->super_class)
    if((result=OBJCLookupUniqueIdInOnlyThisClass(class,uniqueId))!=NULL)
     break;

   return result;
}

void OBJCInitializeClass(Class class) {
   if(!(class->info&CLASS_INFO_INITIALIZED)){
    if(class->super_class!=NULL)
     OBJCInitializeClass(class->super_class);

    if(!(class->info&CLASS_INFO_INITIALIZED)) {
     SEL         selector=@selector(initialize);
     OBJCMethod *method=OBJCLookupUniqueIdInOnlyThisClass(class->isa,OBJCSelectorUniqueId(selector));

     class->info|=CLASS_INFO_INITIALIZED;

     if(method!=NULL)
      method->method_imp(class,selector);
    }
   }
}

// both of these suck, we should be using NSMethodSignature types to extract the frame and create the NSInvocation here
#ifdef SOLARIS
id objc_msgForward(id object,SEL message,...){
   Class       class=object->isa;
   OBJCMethod *method;
   va_list     arguments;
   unsigned    i,frameLength,limit;
   unsigned   *frame;
   
   if((method=OBJCLookupUniqueIdInClass(class,OBJCSelectorUniqueId(@selector(_frameLengthForSelector:))))==NULL){
    OBJCRaiseException("OBJCDoesNotRecognizeSelector","%c[%s %s(%d)]", class->info & CLASS_INFO_META ? '+' : '-', class->name,sel_getName(message),message);
    return nil;
   }
   frameLength=method->method_imp(object,@selector(_frameLengthForSelector:),message);
   frame=__builtin_alloca(frameLength);
   
   va_start(arguments,message);
   frame[0]=object;
   frame[1]=message;
   for(i=2;i<frameLength/sizeof(unsigned);i++)
    frame[i]=va_arg(arguments,unsigned);
   
   if((method=OBJCLookupUniqueIdInClass(class,OBJCSelectorUniqueId(@selector(forwardSelector:arguments:))))!=NULL)
    return method->method_imp(object,@selector(forwardSelector:arguments:),message,frame);
   else {
    OBJCRaiseException("OBJCDoesNotRecognizeSelector","%c[%s %s(%d)]", class->info & CLASS_INFO_META ? '+' : '-', class->name,sel_getName(message),message);
    return nil;
   }
}
#else
id objc_msgForward(id object,SEL message,...){
   Class       class=object->isa;
   OBJCMethod *method;
   void       *arguments=&object;

   if((method=OBJCLookupUniqueIdInClass(class,OBJCSelectorUniqueId(@selector(forwardSelector:arguments:))))!=NULL)
    return method->method_imp(object,@selector(forwardSelector:arguments:),message,arguments);
   else {
    OBJCRaiseException("OBJCDoesNotRecognizeSelector","%c[%s %s(%d)]", class->info & CLASS_INFO_META ? '+' : '-', class->name,sel_getName(message),message);
    return nil;
   }
}
#endif

id OBJCMessageNil(id object,SEL message,...){
   return nil;
}

// FIX, better allocator
static OBJCMethodCacheEntry *allocateCacheEntry(){
   OBJCMethodCacheEntry *result=NSZoneCalloc(NULL,1,sizeof(OBJCMethodCacheEntry));
   
   OBJCInitializeCacheEntry(result);
   
   return result;
}

static inline void OBJCCacheMethodInClass(Class class,OBJCMethod *method) {
   SEL          uniqueId=method->method_name;
   unsigned              index=(unsigned)uniqueId&OBJCMethodCacheMask;
   OBJCMethodCacheEntry *check=((void *)class->cache->table)+index;

   if(check->method->method_name==OBJCNilSelector)
    check->method=method;
   else {
    OBJCMethodCacheEntry *entry=allocateCacheEntry();
    
    entry->method=method;
    
    while(((void *)check)+check->offsetToNextEntry!=NULL)
     check=((void *)check)+check->offsetToNextEntry;
     
    check->offsetToNextEntry=((void *)entry)-((void *)check);
   }
}

IMP OBJCLookupAndCacheUniqueIdInClass(Class class,SEL uniqueId){
   OBJCMethod *method;

   if((method=OBJCLookupUniqueIdInClass(class,uniqueId))!=NULL){
    OBJCCacheMethodInClass(class,method);
    return method->method_imp;
   }

   return objc_msgForward;
}

static id nil_message(id object,SEL message,...){
   return nil;
}

IMP OBJCInitializeLookupAndCacheUniqueIdForObject(id object,SEL uniqueId){
   if(object==nil)
    return nil_message;
   else {
    Class class=object->isa;
    Class checkInit=(class->info&CLASS_INFO_META)?object:class;

    if(!(checkInit->info&CLASS_INFO_INITIALIZED))
     OBJCInitializeClass(checkInit);

    return OBJCLookupAndCacheUniqueIdInClass(class,uniqueId);
   }
}

void OBJCLogMsg(id object,SEL message){
#if 1
   if(object==nil)
    fprintf(stderr,"-[*nil* %s]\n",(char *)message);
   else
    fprintf(stderr,"%c[%s %s]\n",(object->isa->info&CLASS_INFO_META)?'+':'-', object->isa->name,(char *)message);
   fflush(stderr);
#endif
}

void OBJCReportStatistics() {
#if 0
#endif
}
