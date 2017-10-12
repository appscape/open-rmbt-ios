/*
 * Copyright 2013 appscape gmbh
 *
 * Licensed under the Apache License, Version 2.0 (the "License");
 * you may not use this file except in compliance with the License.
 * You may obtain a copy of the License at
 *
 *   http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software
 * distributed under the License is distributed on an "AS IS" BASIS,
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
 * See the License for the specific language governing permissions and
 * limitations under the License.
 *
 */

#import <Foundation/Foundation.h>

extern NSString *RMBTPreferredLanguage(void);

// Removes all trailing \n or \r
extern NSString *RMBTChomp(NSString* string);

extern NSUInteger RMBTPercent(NSInteger count, NSInteger totalCount);

// Format a number to two significant digits. See https://trac.rtr.at/iosrtrnetztest/ticket/17
extern NSString* RMBTFormatNumber(NSNumber *number);
extern BOOL RMBTIsRunningGermanLocale(void);

typedef NS_ENUM(NSInteger, RMBTFormFactor) {
    RMBTFormFactoriPhone4,
    RMBTFormFactoriPhone5,
    RMBTFormFactoriPhone6,
    RMBTFormFactoriPhone6Plus
};
extern RMBTFormFactor RMBTGetFormFactor(void);


// Normalize hexadecimal identifier, i.e. 0:1:c -> 00:01:0c
extern NSString* RMBTReformatHexIdentifier(NSString *identifier);

// Returns bundle name from Info.plist (i.e. RTR-NetTest or RTR-Netztest)
extern NSString* RMBTAppTitle(void);

NS_INLINE id RMBTValueOrNull(id value) { return value ?: [NSNull null]; }
NS_INLINE id RMBTValueOrString(id value, NSString *result) { return value ?: result; }

NSString* RMBTMillisecondsStringWithNanos(uint64_t nanos);
NSString* RMBTSecondsStringWithNanos(uint64_t nanos);

// Returns mm:ss string from time interval
NSString* RMBTMMSSStringWithInterval(NSTimeInterval interval);

NSString *RMBTMegabytesString(uint64_t bytes);

NSNumber* RMBTTimestampWithNSDate(NSDate* date);
uint64_t RMBTCurrentNanos(void);

// Returns a string containing git commit, branch and commit count from Info.plist fields
// written by the build script
NSString* RMBTBuildInfoString(void);
NSString* RMBTBuildDateString(void);

// Replaces $lang in template with de if current local is german, en otherwise
NSString* RMBTLocalizeURLString(NSString* urlString);

NSNumber* RMBTMedian(NSArray<NSNumber*>* values);


#define RMBTAssertValidPort(p) NSAssert(p > 0 && p < 65536, @"Invalid port")
