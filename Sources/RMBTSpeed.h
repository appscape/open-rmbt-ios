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

// Returns position of the measured speed in percentage of the 0-100 Mbit/s range.
// Note that the function can return values higher than 1 for values above 100 Mbit/s.
extern double RMBTSpeedLogValue(uint32_t kbps);

extern NSString* RMBTSpeedMbpsSuffix(void);
extern NSString* RMBTSpeedMbpsStringWithSuffix(uint32_t kbps, BOOL suffix);
extern NSString* RMBTSpeedMbpsString(uint32_t kbps);
