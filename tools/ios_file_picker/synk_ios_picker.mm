// SYNK iOS file picker: Godot 4.7 has no native file dialog on iOS, so its FileDialog only
// browses the app's own sandbox. This GDExtension opens the system Files app picker instead
// and returns local copies of the chosen files. Built by .github/workflows/ios-unsigned.yml.
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>

#import <UIKit/UIKit.h>

using namespace godot;

class IOSFilePicker;

@interface SynkPickerDelegate : NSObject <UIDocumentPickerDelegate>
@property(nonatomic, assign) IOSFilePicker *owner;
@end

class IOSFilePicker : public RefCounted {
	GDCLASS(IOSFilePicker, RefCounted);
	SynkPickerDelegate *delegate = nil;

protected:
	static void _bind_methods() {
		ClassDB::bind_method(D_METHOD("open", "multiple"), &IOSFilePicker::open);
		ADD_SIGNAL(MethodInfo("picked", PropertyInfo(Variant::PACKED_STRING_ARRAY, "paths")));
	}

public:
	~IOSFilePicker() {
		if (delegate) delegate.owner = nullptr;
	}

	void open(bool multiple) {
		UIWindow *window = nil;
		for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
			if (![scene isKindOfClass:UIWindowScene.class]) continue;
			for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
				if (candidate.isKeyWindow || window == nil) window = candidate;
			}
		}
		UIViewController *top = window.rootViewController;
		while (top.presentedViewController) top = top.presentedViewController;
		if (top == nil) return;
		// Import mode copies each file into the app's tmp folder, so the game reads plain paths.
		UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:@[ @"public.item" ] inMode:UIDocumentPickerModeImport];
		picker.allowsMultipleSelection = multiple;
		if (delegate == nil) {
			delegate = [SynkPickerDelegate new];
			delegate.owner = this;
		}
		picker.delegate = delegate;
		[top presentViewController:picker animated:YES completion:nil];
	}

	void finish(NSArray<NSURL *> *urls) {
		PackedStringArray paths;
		for (NSURL *url in urls) {
			if (url.isFileURL) paths.push_back(String::utf8(url.path.UTF8String));
		}
		if (!paths.is_empty()) call_deferred("emit_signal", "picked", paths);
	}
};

@implementation SynkPickerDelegate
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
	if (self.owner) self.owner->finish(urls);
}
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
}
@end

static void initialize_picker(ModuleInitializationLevel level) {
	if (level != MODULE_INITIALIZATION_LEVEL_SCENE) return;
	GDREGISTER_CLASS(IOSFilePicker);
}

static void uninitialize_picker(ModuleInitializationLevel level) {
}

extern "C" GDExtensionBool GDE_EXPORT synk_ios_picker_init(GDExtensionInterfaceGetProcAddress get_proc_address, const GDExtensionClassLibraryPtr library, GDExtensionInitialization *initialization) {
	GDExtensionBinding::InitObject init(get_proc_address, library, initialization);
	init.register_initializer(initialize_picker);
	init.register_terminator(uninitialize_picker);
	init.set_minimum_library_initialization_level(MODULE_INITIALIZATION_LEVEL_SCENE);
	return init.init();
}
