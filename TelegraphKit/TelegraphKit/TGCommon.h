/*
 * This is the source code of Telegram for iOS v. 1.1
 * It is licensed under GNU GPL v. 2 or later.
 * You should have received a copy of the license in this archive (see LICENSE).
 *
 * Copyright Peter Iakovlev, 2013.
 */

#ifndef Telegraph_TGCommon_h
#define Telegraph_TGCommon_h

#import <UIKit/UIKit.h>

//#define DISABLE_LOGGING

#define INTERNAL_RELEASE

//#define EXTERNAL_INTERNAL_RELEASE

#if (defined(DEBUG) || defined(INTERNAL_RELEASE)) && !defined(DISABLE_LOGGING)
#define TGLog TGLogToFile
#else
#define TGLog(x, ...) (void)x
#endif

#define TGAssert(expr) assert(expr)

#define UIColorRGB(rgb) ([[UIColor alloc] initWithRed:(((rgb >> 16) & 0xff) / 255.0f) green:(((rgb >> 8) & 0xff) / 255.0f) blue:(((rgb) & 0xff) / 255.0f) alpha:1.0f])
#define UIColorRGBA(rgb,a) ([[UIColor alloc] initWithRed:(((rgb >> 16) & 0xff) / 255.0f) green:(((rgb >> 8) & 0xff) / 255.0f) blue:(((rgb) & 0xff) / 255.0f) alpha:a])

#define TGRestrictedToMainThread {if(![[NSThread currentThread] isMainThread]) TGLog(@"***** Warning: main thread-bound operation is running in background! *****");}

#define TGLocalized(s) NSLocalizedString(s, nil)
#define TGLocalizedStatic(s) ({ static NSString *_localizedString = nil; if (_localizedString == nil) _localizedString = TGLocalized(s); _localizedString; })

#define TG_TIMESTAMP_DEFINE(s) CFAbsoluteTime tg_timestamp_##s = CFAbsoluteTimeGetCurrent(); int tg_timestamp_line_##s = __LINE__;
#define TG_TIMESTAMP_MEASURE(s) { CFAbsoluteTime tg_timestamp_current_time = CFAbsoluteTimeGetCurrent(); TGLog(@"%s %d-%d: %f ms", #s, tg_timestamp_line_##s, __LINE__, (tg_timestamp_current_time - tg_timestamp_##s) * 1000.0); tg_timestamp_##s = tg_timestamp_current_time; tg_timestamp_line_##s = __LINE__; }

#ifdef __cplusplus
extern "C" {
#endif
int cpuCoreCount();
int deviceMemorySize();
    
NSTimeInterval TGCurrentSystemTime();
    
void TGLogToFile(NSString *format, ...);
void TGLogSynchronize();
NSArray *TGGetPackedLogs();
    
NSString *TGStringMD5(NSString *string);
    
int iosMajorVersion();
    
void printMemoryUsage(NSString *tag);
    
void TGDumpViews(UIView *view, NSString *indent);
    
NSString *TGEncodeText(NSString *string, int key);
    
inline void TGDispatchAfter(double delay, dispatch_queue_t queue, dispatch_block_t block)
{
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)((delay) * NSEC_PER_SEC)), queue, block);
}
    
#ifdef __cplusplus
}
#endif

#endif
