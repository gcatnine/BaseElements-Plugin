/*
 BEMacFunctions.cpp
 BaseElements Plug-In
 
 Copyright 2010-2014 Goya. All rights reserved.
 For conditions of distribution and use please see the copyright notice in BEPlugin.cpp
 
 http://www.goya.com.au/baseelements/plugin
 
 */

#import "BEMacFunctions.h"
#import "BEPluginGlobalDefines.h"
#import "BEPluginUtilities.h"
#import "ProgressDialogWindowController.h"

#import <Cocoa/Cocoa.h>

#if TARGET_RT_BIG_ENDIAN
	#define ENCODING kCFStringEncodingUTF32BE
#else
	#define ENCODING kCFStringEncodingUTF32LE
#endif


using namespace std;


const NSStringEncoding kEncoding_wchar_t = CFStringConvertEncodingToNSStringEncoding ( ENCODING );


NSString * NSStringFromStringAutoPtr ( StringAutoPtr text );
NSString * NSStringFromWStringAutoPtr ( const WStringAutoPtr text );
WStringAutoPtr WStringAutoPtrFromNSString ( const NSString * text );


WStringAutoPtr SelectFileOrFolder ( WStringAutoPtr prompt, WStringAutoPtr in_folder, bool choose_file );


ProgressDialogWindowController* progressDialog;


void InitialiseForPlatform ( )
{
	progressDialog = nil;
}


#pragma mark -
#pragma mark String Utilities
#pragma mark -

NSString * NSStringFromStringAutoPtr ( StringAutoPtr text )
{
	NSString * new_string = [NSString stringWithCString: text->c_str() encoding: NSUTF8StringEncoding];
	
	return new_string;
}


/*
 NSStringFromWStringAutoPtr & WStringAutoPtrFromNSString from code at
 
 http://www.cocoabuilder.com/archive/cocoa/200434-nsstring-from-wstring.html
 */

NSString * NSStringFromWStringAutoPtr ( const WStringAutoPtr text )
{
	char * string_data = (char *)text->data();
	unsigned long size = text->size() * sizeof ( wchar_t );
	
	NSString* new_string = [[NSString alloc] initWithBytes: string_data length: size encoding: kEncoding_wchar_t];

	return [new_string autorelease];
}


WStringAutoPtr WStringAutoPtrFromNSString ( const NSString * text )
{
	NSData * string_data = [text dataUsingEncoding: kEncoding_wchar_t];
	size_t size = [string_data length] / sizeof ( wchar_t );
	
	return WStringAutoPtr ( new wstring ( (wchar_t *)[string_data bytes], size ) );
}


#pragma mark -
#pragma mark Clipboard
#pragma mark -

WStringAutoPtr ClipboardFormats ( void )
{
	NSArray *types = [[[NSPasteboard generalPasteboard] types] copy];
	NSMutableString *formats = [NSMutableString stringWithCapacity: 1];
	
	for ( NSString *type in types ) {
		[formats appendString: type];
		[formats appendString: @FILEMAKER_END_OF_LINE];
	}
	
	[types release];
	
	return WStringAutoPtrFromNSString ( (NSString*)formats );
	
} // ClipboardFormats


StringAutoPtr ClipboardData ( WStringAutoPtr atype )
{
	NSString * pasteboard_type = NSStringFromWStringAutoPtr ( atype );
	NSData * pasteboard_data = [[[[NSPasteboard generalPasteboard] dataForType: pasteboard_type] copy] autorelease];
	NSString * clipboard_data = [[[NSString alloc] initWithData: pasteboard_data encoding: NSUTF8StringEncoding] autorelease];
	
	return StringAutoPtr ( new string ( [clipboard_data cStringUsingEncoding: NSUTF8StringEncoding] ) );
	
} // ClipboardData


bool SetClipboardData ( StringAutoPtr data, WStringAutoPtr atype )
{
	NSString * data_to_copy = NSStringFromStringAutoPtr ( data );
	NSString * data_type = NSStringFromWStringAutoPtr ( atype );
	NSArray * new_types = [NSArray arrayWithObject: data_type];
	
	[[NSPasteboard generalPasteboard] declareTypes: new_types owner: nil];
	
	//	[new_types release];
	
	return [[NSPasteboard generalPasteboard] setString: data_to_copy forType: data_type];
	
} // Set_ClipboardData


#pragma mark -
#pragma mark Dialogs
#pragma mark -

WStringAutoPtr SelectFileOrFolder ( WStringAutoPtr prompt, WStringAutoPtr in_folder, bool choose_file )
{
	
	NSOpenPanel* file_dialog = [NSOpenPanel openPanel];
	
	NSString * prompt_string = NSStringFromWStringAutoPtr ( prompt );
	[file_dialog setTitle: prompt_string ];

	NSString * default_directory = NSStringFromWStringAutoPtr ( in_folder );
	if ( [default_directory length] != 0 ) {
		NSURL *directory_url = [NSURL fileURLWithPath: default_directory];
		[file_dialog setDirectoryURL: directory_url];
	}
	
	[file_dialog setCanChooseFiles: choose_file];
	[file_dialog setCanChooseDirectories: !choose_file];

	// allow new directories to be created when selecting directories
	if ( !choose_file ) {
		[file_dialog setCanCreateDirectories: YES];
	}
	
	if ( choose_file ) {
		[file_dialog setAllowsMultipleSelection: YES];
	}
	
	NSMutableString * file_path = [NSMutableString stringWithString: @""];
	
	if ( [file_dialog runModal ] == NSFileHandlingPanelOKButton ) {
		
		NSArray* files = [file_dialog URLs];
		NSUInteger number_of_files = [files count];
		
		// return the file paths as a value list
		
		for ( NSUInteger i = 0 ; i < number_of_files ; i++ ) {
			[file_path appendString: [[files objectAtIndex: i] path]];
			if ( i + 1 != number_of_files ) {
				[file_path appendString: @FILEMAKER_END_OF_LINE];
			}
		}
		
		// [files release];
		
	} else {
//		[file_path stringWithString: @""]; // the user cancelled
	}
	
	//	[prompt_string release];
	
	return WStringAutoPtrFromNSString ( file_path );
	
} // SelectFileOrFolder


WStringAutoPtr SelectFile ( WStringAutoPtr prompt, WStringAutoPtr in_folder )
{
	return SelectFileOrFolder ( prompt, in_folder, YES );
}


WStringAutoPtr SelectFolder ( WStringAutoPtr prompt, WStringAutoPtr in_folder )
{
	return SelectFileOrFolder ( prompt, in_folder, NO );
}


WStringAutoPtr SaveFileDialog ( WStringAutoPtr prompt, WStringAutoPtr fileName, WStringAutoPtr inFolder )
{
	NSSavePanel* file_dialog = [NSSavePanel savePanel];
	
	NSString * prompt_string = NSStringFromWStringAutoPtr ( prompt );
	[file_dialog setTitle: prompt_string ];

	NSString * filename_string = NSStringFromWStringAutoPtr ( fileName );
	[file_dialog setNameFieldStringValue: filename_string ];
		
	NSString * default_directory = NSStringFromWStringAutoPtr ( inFolder );
	if ( [default_directory length] != 0 ) {
		NSURL *directory_url = [NSURL fileURLWithPath: default_directory];
		[file_dialog setDirectoryURL: directory_url];
	}
	
	[file_dialog setCanCreateDirectories: YES];
	
	NSMutableString * file_path = [NSMutableString stringWithString: @""];
	
	if ( [file_dialog runModal ] == NSFileHandlingPanelOKButton ) {
		file_path = (NSMutableString *)[[file_dialog URL] path];
	} else {
		// the user cancelled
	}
	
	//	[prompt_string release];
	//	[filename_string release];

	return WStringAutoPtrFromNSString ( file_path );
	
} // SaveFileDialog


int DisplayDialog ( WStringAutoPtr title, WStringAutoPtr message, WStringAutoPtr ok_button, WStringAutoPtr cancel_button, WStringAutoPtr alternate_button )
{
	int button_pressed = 0;
	
	NSString * title_string = NSStringFromWStringAutoPtr ( title );
	NSString * ok_button_string = NSStringFromWStringAutoPtr ( ok_button );
	NSString * cancel_button_string = NSStringFromWStringAutoPtr ( cancel_button );
	NSString * alternate_button_string = NSStringFromWStringAutoPtr ( alternate_button );
	NSString * message_string = NSStringFromWStringAutoPtr ( message );
	
	NSInteger response = NSRunAlertPanel (  ( title_string ),
									@"%@", 
									( ok_button_string ), 
									( cancel_button_string ), 
									( alternate_button_string ), 
									( message_string )
									);
	
	//	[title_string release];
	//	[ok_button_string release];
	//	[cancel_button_string release];
	//	[alternate_button_string release];
	//	[message_string release];
	
	/*
	 translate the response so that the plug-in returns the same value for the same action
	 on both OS X and Windows
	 */
	
	switch ( response ) {
			
		case NSAlertDefaultReturn:    /* user pressed OK */
			button_pressed = kBE_OKButton;
			break;
			
		case NSAlertAlternateReturn:  /* user pressed Cancel */
			button_pressed = kBE_CancelButton;
			break;
			
		case NSAlertOtherReturn:      /* user pressed the third button */
			button_pressed = kBE_AlternateButton;
			break;
			
		case NSAlertErrorReturn:      /* an error occurred */
			break;
			
	}
	
	return button_pressed;
	
} // DisplayDialog



#pragma mark -
#pragma mark Progress Dialog
#pragma mark -


fmx::errcode DisplayProgressDialog ( WStringAutoPtr title, WStringAutoPtr description, const long maximum, const bool can_cancel )
{
	
	fmx::errcode error = kNoError;

	if ( (progressDialog != nil) && ([progressDialog closed] == YES) ) {
			[progressDialog release];
			progressDialog = nil;
	}
	
	if ( progressDialog == nil ) {
		
		progressDialog = [[ProgressDialogWindowController alloc] initWithWindowNibName: @"ProgressDialog"];

		NSString * title_string = NSStringFromWStringAutoPtr ( title );
		NSString * description_string = NSStringFromWStringAutoPtr ( description );
	
		[progressDialog show: title_string description: description_string maximumValue: maximum canCancel: can_cancel];

	} else {
		error = kFileOrObjectIsInUse;
	}
	
	return error;
}


fmx::errcode UpdateProgressDialog ( const long value, WStringAutoPtr description )
{
	fmx::errcode error = kNoError;
	
	if ( progressDialog != nil ) {
		
		NSString * description_string;
		
		if ( !description->empty() ) {
			description_string = NSStringFromWStringAutoPtr ( description );
		} else {
			description_string = NULL;
		}
		
		error = [progressDialog update: value description: description_string];
		
		if ( [progressDialog closed] == YES ) {
			[progressDialog release];
			progressDialog = nil;
		}
		
	} else {
		error = kWindowIsMissingError;
	}
	
	return error;
}



#pragma mark -
#pragma mark User Preferences
#pragma mark -


bool SetPreference ( WStringAutoPtr key, WStringAutoPtr value, WStringAutoPtr domain )
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
	
	bool result = true;
	
	if ( standardUserDefaults ) {

		NSString * domain_name = NSStringFromWStringAutoPtr ( domain );
		NSDictionary * preferences = [standardUserDefaults persistentDomainForName: domain_name];		
		
		NSString * preference_key = NSStringFromWStringAutoPtr ( key );
		NSString * preference_value = NSStringFromWStringAutoPtr ( value );
		
		NSMutableDictionary * new_preferences = [NSMutableDictionary dictionaryWithCapacity: [preferences count] + 1];
		[new_preferences addEntriesFromDictionary: preferences];
		[new_preferences setObject: preference_value forKey: preference_key];
		
		[standardUserDefaults setPersistentDomain: new_preferences forName: domain_name];
		[standardUserDefaults synchronize];
		
	} else {
		result = false;
	}
	
	[pool drain];
	
	return result;
}


WStringAutoPtr GetPreference ( WStringAutoPtr key, WStringAutoPtr domain )
{
	NSAutoreleasePool* pool = [[NSAutoreleasePool alloc] init];
	
	NSUserDefaults *standardUserDefaults = [NSUserDefaults standardUserDefaults];
	NSString * preference_value = nil;
	
	if ( standardUserDefaults ) {
		
		[standardUserDefaults synchronize];
		
		NSString * domain_name = NSStringFromWStringAutoPtr ( domain );
		NSDictionary * preferences = [standardUserDefaults persistentDomainForName: domain_name];		

		NSString * preference_key = NSStringFromWStringAutoPtr ( key );
		preference_value = [preferences objectForKey: preference_key];
	}
	
	WStringAutoPtr preference = WStringAutoPtrFromNSString ( preference_value );
	
	[pool drain];
	
	return preference;
}



#pragma mark -
#pragma mark Other
#pragma mark -


bool OpenURL ( WStringAutoPtr url )
{	
	return [[NSWorkspace sharedWorkspace] openURL: [NSURL URLWithString: NSStringFromWStringAutoPtr ( url ) ]];
}


bool OpenFile ( WStringAutoPtr path )
{	
	return [[NSWorkspace sharedWorkspace] openFile: NSStringFromWStringAutoPtr ( path ) ];
}


