#import <UIKit/UIKit.h>
#import <AudioToolbox/AudioToolbox.h>

extern "C" void psych_ios_keep_screen_on(int value)
{
	BOOL enabled = value != 0;
	dispatch_async(dispatch_get_main_queue(), ^{
		[UIApplication sharedApplication].idleTimerDisabled = enabled;
	});
}

extern "C" int psych_ios_battery_level(void)
{
	UIDevice *device = [UIDevice currentDevice];
	device.batteryMonitoringEnabled = YES;
	float level = device.batteryLevel;
	if (level < 0) return -1;
	return (int)roundf(level * 100.0f);
}

extern "C" int psych_ios_is_charging(void)
{
	UIDevice *device = [UIDevice currentDevice];
	device.batteryMonitoringEnabled = YES;
	UIDeviceBatteryState state = device.batteryState;
	return state == UIDeviceBatteryStateCharging || state == UIDeviceBatteryStateFull ? 1 : 0;
}

extern "C" void psych_ios_vibrate(int duration)
{
	dispatch_async(dispatch_get_main_queue(), ^{
		if (duration >= 300) AudioServicesPlaySystemSound(kSystemSoundID_Vibrate);
		else
		{
			UIImpactFeedbackGenerator *generator = [[UIImpactFeedbackGenerator alloc] initWithStyle:duration >= 120 ? UIImpactFeedbackStyleHeavy : UIImpactFeedbackStyleMedium];
			[generator prepare];
			[generator impactOccurred];
		}
	});
}

static NSDictionary *psych_ios_fs_attributes(void)
{
	NSString *path = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES) firstObject];
	if (path == nil) path = NSHomeDirectory();
	return [[NSFileManager defaultManager] attributesOfFileSystemForPath:path error:nil];
}

extern "C" double psych_ios_free_space(void)
{
	if (@available(iOS 11.0, *))
	{
		NSURL *url = [NSURL fileURLWithPath:NSHomeDirectory()];
		NSDictionary *values = [url resourceValuesForKeys:@[NSURLVolumeAvailableCapacityForImportantUsageKey] error:nil];
		NSNumber *important = values[NSURLVolumeAvailableCapacityForImportantUsageKey];
		if (important != nil && [important longLongValue] > 0) return [important doubleValue];
	}
	NSNumber *free = psych_ios_fs_attributes()[NSFileSystemFreeSize];
	return free != nil ? [free doubleValue] : -1;
}

extern "C" double psych_ios_total_space(void)
{
	NSNumber *size = psych_ios_fs_attributes()[NSFileSystemSize];
	return size != nil ? [size doubleValue] : -1;
}
