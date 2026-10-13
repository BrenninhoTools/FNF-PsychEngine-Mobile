#import <UIKit/UIKit.h>
#include <string.h>

#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

enum
{
	PSYCH_STATUS_IDLE = 0,
	PSYCH_STATUS_WAITING = 1,
	PSYCH_STATUS_DONE = 2,
	PSYCH_STATUS_CANCELLED = 3,
	PSYCH_STATUS_ERROR = 4
};

static volatile int psychDialogStatus = PSYCH_STATUS_IDLE;
static char psychDialogResult[4096] = {0};
static char psychDialogCacheDir[2048] = {0};
static BOOL psychDialogOpening = NO;

static void psychSetResult(const char *value)
{
	strncpy(psychDialogResult, value ? value : "", sizeof(psychDialogResult) - 1);
	psychDialogResult[sizeof(psychDialogResult) - 1] = 0;
}

static UIViewController *psychTopController(void)
{
	UIWindow *window = nil;
	for (UIWindow *candidate in [UIApplication sharedApplication].windows)
	{
		if (candidate.isKeyWindow)
		{
			window = candidate;
			break;
		}
	}
	if (window == nil) window = [UIApplication sharedApplication].windows.firstObject;

	UIViewController *controller = window.rootViewController;
	while (controller.presentedViewController != nil)
		controller = controller.presentedViewController;
	return controller;
}

@interface PsychDocumentDelegate : NSObject <UIDocumentPickerDelegate>
@end

@implementation PsychDocumentDelegate

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls
{
	NSURL *url = urls.firstObject;
	if (url == nil)
	{
		psychDialogStatus = PSYCH_STATUS_CANCELLED;
		return;
	}

	if (!psychDialogOpening)
	{
		psychSetResult(url.path.UTF8String);
		psychDialogStatus = PSYCH_STATUS_DONE;
		return;
	}

	BOOL scoped = [url startAccessingSecurityScopedResource];
	NSFileManager *manager = [NSFileManager defaultManager];
	NSString *cacheDir = [NSString stringWithUTF8String:psychDialogCacheDir];
	[manager createDirectoryAtPath:cacheDir withIntermediateDirectories:YES attributes:nil error:nil];
	NSString *target = [cacheDir stringByAppendingPathComponent:url.lastPathComponent];
	[manager removeItemAtPath:target error:nil];

	NSError *error = nil;
	BOOL copied = [manager copyItemAtPath:url.path toPath:target error:&error];
	if (scoped) [url stopAccessingSecurityScopedResource];

	if (copied)
	{
		psychSetResult(target.UTF8String);
		psychDialogStatus = PSYCH_STATUS_DONE;
	}
	else psychDialogStatus = PSYCH_STATUS_ERROR;
}

- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentAtURL:(NSURL *)url
{
	[self documentPicker:controller didPickDocumentsAtURLs:@[url]];
}

- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller
{
	psychDialogStatus = PSYCH_STATUS_CANCELLED;
}

@end

static PsychDocumentDelegate *psychDocumentDelegate = nil;

static void psychPresentPicker(UIDocumentPickerViewController *picker)
{
	if (psychDocumentDelegate == nil) psychDocumentDelegate = [[PsychDocumentDelegate alloc] init];
	picker.delegate = psychDocumentDelegate;
	picker.modalPresentationStyle = UIModalPresentationFormSheet;

	UIViewController *top = psychTopController();
	if (top == nil)
	{
		psychDialogStatus = PSYCH_STATUS_ERROR;
		return;
	}
	[top presentViewController:picker animated:YES completion:nil];
	#if !__has_feature(objc_arc)
	[picker release];
	#endif
}

extern "C" void psych_ios_dialog_reset(void)
{
	psychDialogStatus = PSYCH_STATUS_IDLE;
	psychSetResult("");
}

extern "C" int psych_ios_dialog_status(void)
{
	return psychDialogStatus;
}

extern "C" const char *psych_ios_dialog_result(void)
{
	return psychDialogResult;
}

extern "C" void psych_ios_dialog_save(const char *sourcePath)
{
	psychDialogStatus = PSYCH_STATUS_WAITING;
	psychDialogOpening = NO;
	NSString *path = [NSString stringWithUTF8String:sourcePath];
	dispatch_async(dispatch_get_main_queue(), ^{
		NSURL *url = [NSURL fileURLWithPath:path];
		UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithURL:url inMode:UIDocumentPickerModeExportToService];
		psychPresentPicker(picker);
	});
}

extern "C" void psych_ios_dialog_open(const char *cacheDir)
{
	psychDialogStatus = PSYCH_STATUS_WAITING;
	psychDialogOpening = YES;
	strncpy(psychDialogCacheDir, cacheDir ? cacheDir : "", sizeof(psychDialogCacheDir) - 1);
	dispatch_async(dispatch_get_main_queue(), ^{
		UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[@"public.item"] inMode:UIDocumentPickerModeImport];
		psychPresentPicker(picker);
	});
}

#pragma clang diagnostic pop
