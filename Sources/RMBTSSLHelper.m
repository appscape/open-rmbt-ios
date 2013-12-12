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

#import "RMBTSSLHelper.h"

@implementation RMBTSSLHelper

+(NSString*)encryptionStringForSSLContext:(SSLContextRef)sslContext {
    return [NSString stringWithFormat:@"%@ (%@)", [self encryptionProtocolStringForSSLContext:sslContext], [self encryptionCipherStringForSSLContext:sslContext]];
}

+(NSString*)encryptionProtocolStringForSSLContext:(SSLContextRef)sslContext {
    SSLProtocol protocol;
    SSLGetNegotiatedProtocolVersion(sslContext, &protocol);
    switch (protocol)
    {
        case kSSLProtocolUnknown: return @"No Protocol";
        case kSSLProtocol2:       return @"SSLv2";
        case kSSLProtocol3:       return @"SSLv3";
        case kSSLProtocol3Only:   return @"SSLv3 Only";
        case kTLSProtocol1:       return @"TLSv1";
        case kTLSProtocol11:      return @"TLSv1.1";
        case kTLSProtocol12:      return @"TLSv1.2";
        default:                  return [NSString stringWithFormat:@"%d", protocol];
    }
}

+(NSString*)encryptionCipherStringForSSLContext:(SSLContextRef)sslContext {
    SSLCipherSuite cipher;
    SSLGetNegotiatedCipher(sslContext, &cipher);

    switch (cipher)
    {
        case SSL_RSA_WITH_RC4_128_MD5:                return @"SSL_RSA_WITH_RC4_128_MD5";
        case SSL_NO_SUCH_CIPHERSUITE:                 return @"No Cipher";
        default:                                      return [NSString stringWithFormat:@"%X", cipher];
    }
}

@end
