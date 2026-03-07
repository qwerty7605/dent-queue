//
//  Generated file. Do not edit.
//

// clang-format off

#import "GeneratedPluginRegistrant.h"

#if __has_include(<flutter_secure_storage_darwin/FlutterSecureStorageDarwinPlugin.h>)
#import <flutter_secure_storage_darwin/FlutterSecureStorageDarwinPlugin.h>
#else
@import flutter_secure_storage_darwin;
#endif

#if __has_include(<image_picker_ios/FLTImagePickerPlugin.h>)
#import <image_picker_ios/FLTImagePickerPlugin.h>
#else
@import image_picker_ios;
#endif

#if __has_include(<network_info_plus/FPPNetworkInfoPlusPlugin.h>)
#import <network_info_plus/FPPNetworkInfoPlusPlugin.h>
#else
@import network_info_plus;
#endif

@implementation GeneratedPluginRegistrant

+ (void)registerWithRegistry:(NSObject<FlutterPluginRegistry>*)registry {
  [FlutterSecureStorageDarwinPlugin registerWithRegistrar:[registry registrarForPlugin:@"FlutterSecureStorageDarwinPlugin"]];
  [FLTImagePickerPlugin registerWithRegistrar:[registry registrarForPlugin:@"FLTImagePickerPlugin"]];
  [FPPNetworkInfoPlusPlugin registerWithRegistrar:[registry registrarForPlugin:@"FPPNetworkInfoPlusPlugin"]];
}

@end
