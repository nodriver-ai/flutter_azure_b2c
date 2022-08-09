#import "FlutterAzureB2cPlugin.h"
#if __has_include(<flutter_azure_b2c/flutter_azure_b2c-Swift.h>)
#import <flutter_azure_b2c/flutter_azure_b2c-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "flutter_azure_b2c-Swift.h"
#endif

@implementation FlutterAzureB2cPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftFlutterAzureB2cPlugin registerWithRegistrar:registrar];
}
@end
