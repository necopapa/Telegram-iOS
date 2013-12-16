#import "TGCommon.h"

#include <sys/sysctl.h>
#include <mach/mach.h>
#include <mach/mach_time.h>

#import <UIKit/UIKit.h>

#import <CommonCrypto/CommonDigest.h>

#import "NSData+GZip.h"

int cpuCoreCount()
{
    static int count = 0;
    if (count == 0)
    {
        size_t len;
        unsigned int ncpu;
        
        len = sizeof(ncpu);
        sysctlbyname("hw.ncpu", &ncpu, &len, NULL, 0);
        count = ncpu;
    }
    
    return count;
}

int deviceMemorySize()
{
    static int memorySize = 0;
    if (memorySize == 0)
    {
        size_t len;
        __int64_t nmem;
        
        len = sizeof(nmem);
        sysctlbyname("hw.memsize", &nmem, &len, NULL, 0);
        memorySize = (int)(nmem / (1024 * 1024));
    }
    return memorySize;
}

NSTimeInterval TGCurrentSystemTime()
{
    static mach_timebase_info_data_t timebase;
    if (timebase.denom == 0)
        mach_timebase_info(&timebase);
    
    return ((double)mach_absolute_time()) * ((double)timebase.numer) / ((double)timebase.denom) / 1e9;
}

int iosMajorVersion()
{
    static bool initialized = false;
    static int version = 6;
    if (!initialized)
    {
        switch ([[[UIDevice currentDevice] systemVersion] intValue])
        {
            case 4:
                version = 4;
                break;
            case 5:
                version = 5;
                break;
            case 6:
                version = 6;
                break;
            case 7:
                version = 7;
                break;
            default:
                version = 6;
                break;
        }
        
        initialized = true;
    }
    return version;
}

void printMemoryUsage(NSString *tag)
{
    struct task_basic_info info;
    
    mach_msg_type_number_t size = sizeof(info);
    
    kern_return_t kerr = task_info(mach_task_self(),
                                   
                                   TASK_BASIC_INFO,
                                   
                                   (task_info_t)&info,
                                   
                                   &size);
    if( kerr == KERN_SUCCESS )
    {
        TGLog(@"===== %@: Memory used: %u", tag, info.resident_size / 1024 / 1024);
    }
    else
    {
        TGLog(@"===== %@: Error: %s", tag, mach_error_string(kerr));
    }
}

void TGDumpViews(UIView *view, NSString *indent)
{
    TGLog(@"%@%@", indent, view);
    NSString *newIndent = [[NSString alloc] initWithFormat:@"%@    ", indent];
    for (UIView *child in view.subviews)
        TGDumpViews(child, newIndent);
}

NSString *TGEncodeText(NSString *string, int key)
{
    NSMutableString *result = [[NSMutableString alloc] init];
    
    for (int i = 0; i < [string length]; i++)
    {
        unichar c = [string characterAtIndex:i];
        c += key;
        [result appendString:[NSString stringWithCharacters:&c length:1]];
    }
    
    return result;
}

NSString *TGStringMD5(NSString *string)
{
    const char *ptr = [string UTF8String];
    unsigned char md5Buffer[16];
    CC_MD5(ptr, [string lengthOfBytesUsingEncoding:NSUTF8StringEncoding], md5Buffer);
    NSString *output = [[NSString alloc] initWithFormat:@"%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x%02x", md5Buffer[0], md5Buffer[1], md5Buffer[2], md5Buffer[3], md5Buffer[4], md5Buffer[5], md5Buffer[6], md5Buffer[7], md5Buffer[8], md5Buffer[9], md5Buffer[10], md5Buffer[11], md5Buffer[12], md5Buffer[13], md5Buffer[14], md5Buffer[15]];

    return output;
}

static dispatch_queue_t TGLogQueue()
{
    static dispatch_queue_t queue = NULL;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        queue = dispatch_queue_create("com.telegraphkit.logging", 0);
    });
    return queue;
}

static NSFileHandle *TGLogFileHandle()
{
    static NSFileHandle *fileHandle = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^
    {
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        
        NSString *currentFilePath = [documentsDirectory stringByAppendingPathComponent:@"application-0.log"];
        NSString *oldestFilePath = [documentsDirectory stringByAppendingPathComponent:@"application-30.log"];
        
        if ([fileManager fileExistsAtPath:oldestFilePath])
            [fileManager removeItemAtPath:oldestFilePath error:nil];

        for (int i = 30 - 1; i >= 0; i--)
        {
            NSString *filePath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"application-%d.log", i]];
            NSString *nextFilePath = [documentsDirectory stringByAppendingPathComponent:[NSString stringWithFormat:@"application-%d.log", i + 1]];
            if ([fileManager fileExistsAtPath:filePath])
            {
                [fileManager moveItemAtPath:filePath toPath:nextFilePath error:nil];
            }
        }
        
        [fileManager createFileAtPath:currentFilePath contents:nil attributes:nil];
        fileHandle = [NSFileHandle fileHandleForWritingAtPath:currentFilePath];
        [fileHandle truncateFileAtOffset:0];
    });
    
    return fileHandle;
}

void TGLogSynchronize()
{
    dispatch_async(TGLogQueue(), ^
    {
        [TGLogFileHandle() synchronizeFile];
    });
}

void TGLogToFile(NSString *format, ...)
{
    va_list L;
    va_start(L, format);
    NSString *message = [[NSString alloc] initWithFormat:format arguments:L];
    va_end(L);
    
    NSLog(@"%@", message);
    
    dispatch_async(TGLogQueue(), ^
    {
        NSFileHandle *output = TGLogFileHandle();
        
        if (output != nil)
        {
            time_t rawtime;
            struct tm timeinfo;
            char buffer[64];
            time(&rawtime);
            localtime_r(&rawtime, &timeinfo);
            struct timeval curTime;
            gettimeofday(&curTime, NULL);
            int milliseconds = curTime.tv_usec / 1000;
            strftime(buffer, 64, "%Y-%m-%d %H:%M", &timeinfo);
            char fullBuffer[128] = { 0 };
            snprintf(fullBuffer, 128, "%s:%2d.%.3d ", buffer, timeinfo.tm_sec, milliseconds);
            
            [output writeData:[[[NSString alloc] initWithCString:fullBuffer encoding:NSASCIIStringEncoding] dataUsingEncoding:NSUTF8StringEncoding]];
            
            [output writeData:[message dataUsingEncoding:NSUTF8StringEncoding]];
            
            static NSData *returnData = nil;
            if (returnData == nil)
                returnData = [@"\n" dataUsingEncoding:NSUTF8StringEncoding];
            [output writeData:returnData];
        }
    });
}

NSArray *TGGetPackedLogs()
{
    NSMutableArray *resultFiles = [[NSMutableArray alloc] init];
    
    dispatch_sync(TGLogQueue(), ^
    {
        [TGLogFileHandle() synchronizeFile];
        
        NSFileManager *fileManager = [[NSFileManager alloc] init];
        
        NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, true);
        NSString *documentsDirectory = [paths objectAtIndex:0];
        
        for (int i = 0; i <= 4; i++)
        {
            NSString *fileName = [NSString stringWithFormat:@"application-%d.log", i];
            NSString *filePath = [documentsDirectory stringByAppendingPathComponent:fileName];
            if ([fileManager fileExistsAtPath:filePath])
            {
                NSData *fileData = [[NSData alloc] initWithContentsOfFile:filePath];
                if (fileData != nil)
                    [resultFiles addObject:fileData];
            }
        }
    });
    
    return resultFiles;
}
