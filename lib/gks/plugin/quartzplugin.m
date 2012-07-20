
#import <Foundation/Foundation.h>
#import <ApplicationServices/ApplicationServices.h>

#include "gks.h"
#include "gkscore.h"
#include "gksquartz.h"

#ifndef MAXPATHLEN
#define MAXPATHLEN 1024
#endif

#ifdef _WIN32

#include <windows.h>
#define DLLEXPORT __declspec(dllexport)

#ifdef __cplusplus
extern "C"
{
#endif
  
#else
  
#ifdef __cplusplus
#define DLLEXPORT extern "C"
#else
#define DLLEXPORT
#endif
  
#endif
  
DLLEXPORT void gks_quartzplugin(
  int fctid, int dx, int dy, int dimx, int *i_arr,
  int len_f_arr_1, float *f_arr_1, int len_f_arr_2, float *f_arr_2,
  int len_c_arr, char *c_arr, void **ptr);
  
#ifdef _WIN32
#ifdef __cplusplus
}
#endif
#endif

static
gks_state_list_t *gkss;

static
ws_state_list *wss;

NSAutoreleasePool *pool;
id displayList;
id plugin;
NSLock *mutex;

static
int inactivity_counter = -1;

@interface gks_quartz_thread : NSObject
+ (void) update: (id) param;
@end

@implementation gks_quartz_thread
+ (void) update: (id) param
{
  NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
  for (;;)
    {
      [mutex lock];
      if (inactivity_counter == 3)
	{
          [displayList initWithBytesNoCopy:
           wss->dl.buffer length: wss->dl.nbytes freeWhenDone: NO];
          [plugin GKSQuartzDraw: wss->win displayList: displayList];
	  inactivity_counter = -1;
        }
      if (inactivity_counter >= 0)
        inactivity_counter++;
      [mutex unlock];
      usleep(100000);
    }
  [pool release];
}
@end

static
BOOL gks_terminal(void)
{
  NSURL *url;
  OSStatus status;

  NSString *path = [NSString stringWithFormat:@"%s/Applications/GKSTerm.app",
                    GRDIR];
  url = [NSURL fileURLWithPath: path];
  status = LSOpenCFURLRef((CFURLRef) url, NULL);
  
  return (status == noErr);
}

void gks_quartzplugin(
  int fctid, int dx, int dy, int dimx, int *ia,
  int lr1, float *r1, int lr2, float *r2,
  int lc, char *chars, void **ptr)
{
  wss = (ws_state_list *) *ptr;

  switch (fctid)
    {
    case 2:
      gkss = (gks_state_list_t *) *ptr;      

      wss = (ws_state_list *) calloc(1, sizeof(ws_state_list));
      pool = [[NSAutoreleasePool alloc] init];
      displayList = [[NSData alloc] init];  
      plugin = [NSConnection rootProxyForConnectionWithRegisteredName:
                @"GKSQuartz" host: nil];
      mutex = [[NSLock alloc] init];

      if (plugin == nil)
        {
          if (!gks_terminal())
            NSLog(@"Launching GKSTerm failed.");          
          else
            {
              int counter = 10;
              while (--counter && !plugin)
                {
                  [NSThread sleepUntilDate:[NSDate dateWithTimeIntervalSinceNow: 1.0]];
                  plugin = [NSConnection rootProxyForConnectionWithRegisteredName:
                            @"GKSQuartz" host: nil];
                }            
            }
        }

      if (plugin)
        {
          [NSThread detachNewThreadSelector: @selector(update:) toTarget:[gks_quartz_thread class] withObject:nil];
          [plugin setProtocolForProxy: @protocol(gks_protocol)];
        }

      wss->win = [plugin GKSQuartzCreateWindow];

      *ptr = wss;
      break;
  
    case 3:
      [plugin GKSQuartzCloseWindow: wss->win];
      [mutex release];
      [plugin release];
      [displayList release];

      free(wss);
      wss = NULL;
      break;

    case 8:
      if (ia[1] == GKS_K_PERFORM_FLAG)
        {
          [mutex lock];
          [displayList initWithBytesNoCopy:
           wss->dl.buffer length: wss->dl.nbytes freeWhenDone: NO];
          [plugin GKSQuartzDraw: wss->win displayList: displayList];
          inactivity_counter = -1;
          [mutex unlock];
        }
      break;

    case 12:
    case 13:
    case 14:
    case 15:
    case 16:
    case DRAW_IMAGE:
      [mutex lock];
      inactivity_counter = 0;
      [mutex unlock];
      break;
    }

  if (wss != NULL)
    gks_dl_write_item(&wss->dl,
      fctid, dx, dy, dimx, ia, lr1, r1, lr2, r2, lc, chars, gkss);
}
