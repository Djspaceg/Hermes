//
//  Keychain.h
//  Hermes
//
//  Created by Alex Crichton on 11/19/11.
//

#import "Keychain.h"
#import <Security/Security.h>

// Suppress deprecation warnings for legacy Keychain APIs
// These APIs are deprecated but still functional and widely used
// Modernizing to the new Keychain API would require significant refactoring
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"

BOOL KeychainSetItem(NSString* username, NSString* password) {
  if (!username || !password) { return NO; }

  NSData *passwordData = [password dataUsingEncoding:NSUTF8StringEncoding];

  // Query to find existing item
  NSDictionary *query = @{
    (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
    (__bridge id)kSecAttrService: [[NSString alloc] initWithBytes:KEYCHAIN_SERVICE_NAME length:strlen(KEYCHAIN_SERVICE_NAME) encoding:NSUTF8StringEncoding],
    (__bridge id)kSecAttrAccount: username
  };

  OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, NULL);
  if (status == errSecSuccess) {
    // Update existing item
    NSDictionary *attributesToUpdate = @{
      (__bridge id)kSecValueData: passwordData
    };
    status = SecItemUpdate((__bridge CFDictionaryRef)query, (__bridge CFDictionaryRef)attributesToUpdate);
  } else if (status == errSecItemNotFound) {
    // Add new item
    NSMutableDictionary *addQuery = [query mutableCopy];
    addQuery[(__bridge id)kSecValueData] = passwordData;
    status = SecItemAdd((__bridge CFDictionaryRef)addQuery, NULL);
  }

  return (status == errSecSuccess);
}

NSString *KeychainGetPassword(NSString* username) {
  if (!username) { return nil; }

  NSDictionary *query = @{
    (__bridge id)kSecClass: (__bridge id)kSecClassGenericPassword,
    (__bridge id)kSecAttrService: [[NSString alloc] initWithBytes:KEYCHAIN_SERVICE_NAME length:strlen(KEYCHAIN_SERVICE_NAME) encoding:NSUTF8StringEncoding],
    (__bridge id)kSecAttrAccount: username,
    (__bridge id)kSecReturnData: @YES,
    (__bridge id)kSecMatchLimit: (__bridge id)kSecMatchLimitOne
  };

  CFTypeRef resultData = NULL;
  OSStatus status = SecItemCopyMatching((__bridge CFDictionaryRef)query, &resultData);
  if (status != errSecSuccess || !resultData) {
    if (resultData) CFRelease(resultData);
    return nil;
  }

  NSData *passwordData = (__bridge_transfer NSData *)resultData;
  NSString *password = [[NSString alloc] initWithData:passwordData encoding:NSUTF8StringEncoding];
  return password;
}

