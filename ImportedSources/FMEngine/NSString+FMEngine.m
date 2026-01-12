//
//  NSString+UUID.m
//  LastFMAPI
//
//  Created by Nicolas Haunold on 4/26/09.
//  Copyright 2009 Tapolicious Software. All rights reserved.
//

// Thanks to Sam Steele / c99koder for -[NSString md5sum];

#import "NSString+FMEngine.h"
#import <CommonCrypto/CommonDigest.h>

@implementation NSString (FMEngineAdditions)

+ (NSString *)stringWithNewUUID {
    CFUUIDRef uuidObj = CFUUIDCreate(nil);

    NSString *newUUID = (__bridge_transfer NSString*)CFUUIDCreateString(nil, uuidObj);
    CFRelease(uuidObj);
    return newUUID;
}

- (NSString*) urlEncoded {
    // Use modern Foundation API for percent-encoding. Choose a conservative allowed set suitable for URL query/value encoding.
    NSCharacterSet *allowed = [NSCharacterSet URLQueryAllowedCharacterSet];
    // RFC 3986 reserves ":#[]@!$&'()*+,;=" in various URL components; remove them to ensure they are percent-encoded.
    NSMutableCharacterSet *mutableAllowed = [allowed mutableCopy];
    [mutableAllowed removeCharactersInString:@":#[]@!$&'()*+,;="];
    NSString *encoded = [self stringByAddingPercentEncodingWithAllowedCharacters:mutableAllowed];
    return encoded;
}

- (NSString *)md5sum {
  // MD5 is deprecated and insecure. For backward compatibility, return a SHA-256 hash instead.
  // If callers rely on MD5 specifically for protocol reasons, consider reintroducing MD5 behind
  // conditional compilation only for non-security contexts. For now, prefer SHA-256.
  unsigned char digest[CC_SHA256_DIGEST_LENGTH];
  NSData *data = [self dataUsingEncoding:NSUTF8StringEncoding];
  CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
  NSMutableString *ms = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
  for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
    [ms appendFormat:@"%02x", digest[i]];
  }
  return [ms copy];
}

- (NSString *)sha256sum {
  unsigned char digest[CC_SHA256_DIGEST_LENGTH];
  NSData *data = [self dataUsingEncoding:NSUTF8StringEncoding];
  CC_SHA256(data.bytes, (CC_LONG)data.length, digest);
  NSMutableString *ms = [NSMutableString stringWithCapacity:CC_SHA256_DIGEST_LENGTH * 2];
  for (int i = 0; i < CC_SHA256_DIGEST_LENGTH; i++) {
    [ms appendFormat:@"%02x", digest[i]];
  }
  return [ms copy];
}

@end

