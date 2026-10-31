// SYNK iOS file picker: Godot 4.7 has no native file dialog on iOS, so its FileDialog only
// browses the app's own sandbox. This GDExtension opens the system Files app picker instead
// and returns local copies of the chosen files. Built by .github/workflows/ios-unsigned.yml.
#include <godot_cpp/classes/ref_counted.hpp>
#include <godot_cpp/core/class_db.hpp>
#include <godot_cpp/godot.hpp>
#include <godot_cpp/variant/packed_string_array.hpp>

#import <PhotosUI/PhotosUI.h>
#import <UIKit/UIKit.h>
#import <objc/runtime.h>

using namespace godot;

class IOSFilePicker;

@interface SynkPickerDelegate : NSObject <UIDocumentPickerDelegate, PHPickerViewControllerDelegate>
@property(nonatomic, assign) IOSFilePicker *owner;
@end

static UIViewController *top_controller() {
	UIWindow *window = nil;
	for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
		if (![scene isKindOfClass:UIWindowScene.class]) continue;
		for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
			if (candidate.isKeyWindow || window == nil) window = candidate;
		}
	}
	UIViewController *top = window.rootViewController;
	while (top.presentedViewController) top = top.presentedViewController;
	return top;
}

class IOSFilePicker : public RefCounted {
	GDCLASS(IOSFilePicker, RefCounted);
	SynkPickerDelegate *delegate = nil;

protected:
	static void _bind_methods() {
		ClassDB::bind_method(D_METHOD("open", "multiple"), &IOSFilePicker::open);
		ClassDB::bind_method(D_METHOD("open_image"), &IOSFilePicker::open_image);
		ClassDB::bind_method(D_METHOD("defer_system_gestures"), &IOSFilePicker::defer_system_gestures);
		ADD_SIGNAL(MethodInfo("picked", PropertyInfo(Variant::PACKED_STRING_ARRAY, "paths")));
	}

public:
	~IOSFilePicker() {
		if (delegate) delegate.owner = nullptr;
	}

	SynkPickerDelegate *ensure_delegate() {
		if (delegate == nil) {
			delegate = [SynkPickerDelegate new];
			delegate.owner = this;
		}
		return delegate;
	}

	void open(bool multiple) {
		open_documents(@[ @"public.item" ], multiple);
	}

	void open_documents(NSArray<NSString *> *types, bool multiple) {
		UIViewController *top = top_controller();
		if (top == nil) return;
		// Import mode copies each file into the app's tmp folder, so the game reads plain paths.
		UIDocumentPickerViewController *picker = [[UIDocumentPickerViewController alloc] initWithDocumentTypes:types inMode:UIDocumentPickerModeImport];
		picker.allowsMultipleSelection = multiple;
		picker.delegate = ensure_delegate();
		[top presentViewController:picker animated:YES completion:nil];
	}

	// Asks where an image comes from: the photo library or the Files app.
	void open_image() {
		UIViewController *top = top_controller();
		if (top == nil) return;
		UIAlertController *sheet = [UIAlertController alertControllerWithTitle:@"Choose an image" message:nil preferredStyle:UIAlertControllerStyleActionSheet];
		[sheet addAction:[UIAlertAction actionWithTitle:@"Photo Library" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
			this->open_photos();
		}]];
		[sheet addAction:[UIAlertAction actionWithTitle:@"Files" style:UIAlertActionStyleDefault handler:^(UIAlertAction *action) {
			this->open_documents(@[ @"public.image" ], false);
		}]];
		[sheet addAction:[UIAlertAction actionWithTitle:@"Cancel" style:UIAlertActionStyleCancel handler:nil]];
		// iPad shows action sheets as popovers, which need an anchor.
		sheet.popoverPresentationController.sourceView = top.view;
		sheet.popoverPresentationController.sourceRect = CGRectMake(CGRectGetMidX(top.view.bounds), CGRectGetMidY(top.view.bounds), 1, 1);
		sheet.popoverPresentationController.permittedArrowDirections = 0;
		[top presentViewController:sheet animated:YES completion:nil];
	}

	// The system photo picker needs no photo permission; only the chosen picture is shared.
	void open_photos() {
		UIViewController *top = top_controller();
		if (top == nil) return;
		PHPickerConfiguration *config = [PHPickerConfiguration new];
		config.filter = [PHPickerFilter imagesFilter];
		config.selectionLimit = 1;
		PHPickerViewController *picker = [[PHPickerViewController alloc] initWithConfiguration:config];
		picker.delegate = ensure_delegate();
		[top presentViewController:picker animated:YES completion:nil];
	}

	// Keeps a swipe at the screen edges in the game: the home bar and Control Centre need a
	// second swipe. iOS ignores this deferral while the home bar auto-hides, so the bar stays
	// shown (dimmed). The root controller's class answers the system's questions directly.
	void defer_system_gestures() {
		UIViewController *root = nil;
		for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
			if (![scene isKindOfClass:UIWindowScene.class]) continue;
			for (UIWindow *candidate in ((UIWindowScene *)scene).windows) {
				if (candidate.rootViewController && (candidate.isKeyWindow || root == nil)) root = candidate.rootViewController;
			}
		}
		if (root == nil) return;
		Class type = object_getClass(root);
		class_replaceMethod(type, @selector(preferredScreenEdgesDeferringSystemGestures), imp_implementationWithBlock(^UIRectEdge(id self) {
			return UIRectEdgeAll;
		}), "Q@:");
		class_replaceMethod(type, @selector(prefersHomeIndicatorAutoHidden), imp_implementationWithBlock(^BOOL(id self) {
			return NO;
		}), "B@:");
		class_replaceMethod(type, @selector(childViewControllerForScreenEdgesDeferringSystemGestures), imp_implementationWithBlock(^UIViewController *(id self) {
			return nil;
		}), "@@:");
		class_replaceMethod(type, @selector(childViewControllerForHomeIndicatorAutoHidden), imp_implementationWithBlock(^UIViewController *(id self) {
			return nil;
		}), "@@:");
		[root setNeedsUpdateOfScreenEdgesDeferringSystemGestures];
		[root setNeedsUpdateOfHomeIndicatorAutoHidden];
	}

	void finish_paths(PackedStringArray paths) {
		if (!paths.is_empty()) call_deferred("emit_signal", "picked", paths);
	}

	void finish(NSArray<NSURL *> *urls) {
		PackedStringArray paths;
		for (NSURL *url in urls) {
			if (url.isFileURL) paths.push_back(String::utf8(url.path.UTF8String));
		}
		finish_paths(paths);
	}
};

@implementation SynkPickerDelegate
- (void)documentPicker:(UIDocumentPickerViewController *)controller didPickDocumentsAtURLs:(NSArray<NSURL *> *)urls {
	if (self.owner) self.owner->finish(urls);
}
- (void)documentPickerWasCancelled:(UIDocumentPickerViewController *)controller {
}
- (void)picker:(PHPickerViewController *)picker didFinishPicking:(NSArray<PHPickerResult *> *)results {
	[picker dismissViewControllerAnimated:YES completion:nil];
	NSItemProvider *provider = results.firstObject.itemProvider;
	if (provider == nil || ![provider canLoadObjectOfClass:UIImage.class]) return;
	// Photos are often HEIC, which Godot cannot read: re-encode as JPEG in the tmp folder.
	[provider loadObjectOfClass:UIImage.class completionHandler:^(id<NSItemProviderReading> object, NSError *error) {
		NSData *jpeg = [object isKindOfClass:UIImage.class] ? UIImageJPEGRepresentation((UIImage *)object, 0.92) : nil;
		if (jpeg == nil) return;
		NSString *name = [NSString stringWithFormat:@"synk-photo-%@.jpg", NSUUID.UUID.UUIDString];
		NSString *path = [NSTemporaryDirectory() stringByAppendingPathComponent:name];
		if (![jpeg writeToFile:path atomically:YES]) return;
		dispatch_async(dispatch_get_main_queue(), ^{
			if (self.owner == nullptr) return;
			PackedStringArray paths;
			paths.push_back(String::utf8(path.UTF8String));
			self.owner->finish_paths(paths);
		});
	}];
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
