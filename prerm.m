// prerm.mm
// based on substrate's postrm.mm

#include <Foundation/Foundation.h>

static NSString * const TLSubstrateBootstrapPath = @"/Library/Frameworks/CydiaSubstrate.framework/Libraries/SubstrateBootstrap.dylib";

int main(int argc, char **argv) {
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];

	// Try /System/Library/LaunchDaemons/
	NSString *appIndexerPlist = @"/System/Library/LaunchDaemons/com.apple.search.appindexer.plist";
	NSMutableDictionary *appIndexerJobOptions = [NSMutableDictionary dictionaryWithContentsOfFile:appIndexerPlist];

	// Try /Library/LaunchDaemons/
	if (appIndexerJobOptions == nil) {
		appIndexerPlist = @"/Library/LaunchDaemons/com.apple.search.appindexer.plist";
		appIndexerJobOptions = [NSMutableDictionary dictionaryWithContentsOfFile:appIndexerPlist];

		// Give up
		if (appIndexerJobOptions == nil) 
			return 1;
	}

	NSMutableDictionary *environmentVariables = [[[appIndexerJobOptions objectForKey:@"EnvironmentVariables"] mutableCopy] autorelease];

	if (environmentVariables != nil) {
		NSString *libraryList = [environmentVariables objectForKey:@"DYLD_INSERT_LIBRARIES"];

		if (libraryList != nil) {
			NSMutableArray *insertedLibraries = [NSMutableArray arrayWithArray:[libraryList componentsSeparatedByString:@":"]];
			
			// Check if the bootstrap library is set to be inserted
			NSUInteger bootstrapIndex = [insertedLibraries indexOfObject:TLSubstrateBootstrapPath];
			if (bootstrapIndex == NSNotFound)
				return 0;

			// If so, remove it
			[insertedLibraries removeObject:TLSubstrateBootstrapPath];

			if ([insertedLibraries count] > 0)
				[environmentVariables setObject:[insertedLibraries componentsJoinedByString:@":"] forKey:@"DYLD_INSERT_LIBRARIES"];
			else
				[environmentVariables removeObjectForKey:@"DYLD_INSERT_LIBRARIES"];
		}

		if ([environmentVariables count] > 0)
			[appIndexerJobOptions setObject:environmentVariables forKey:@"EnvironmentVariables"];
		else
			[appIndexerJobOptions removeObjectForKey:@"EnvironmentVariables"];

		if (![appIndexerJobOptions writeToFile:appIndexerPlist atomically:YES])
			return 1;
	
		// Reload AppIndexer.
		system([[NSString stringWithFormat:@"launchctl unload %@", appIndexerPlist] UTF8String]);
		system([[NSString stringWithFormat:@"launchctl load %@", appIndexerPlist] UTF8String]);

	}

	[pool drain];

	return 0;
}
