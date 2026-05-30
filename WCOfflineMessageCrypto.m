/* $Id$ */

/*
 *  Copyright (c) 2025 Jörg Märtin
 *  All rights reserved.
 */

#import "WCOfflineMessageCrypto.h"

static NSData *_WCKeyTagForServerID(NSString *serverID) {
    NSString *label = [NSString stringWithFormat:@"com.wired.offline.key.%@", serverID];
    return [label dataUsingEncoding:NSUTF8StringEncoding];
}

static SecKeyRef _WCCopyPrivateKey(NSData *tag) {
    NSDictionary *query = @{
        (id)kSecClass:              (id)kSecClassKey,
        (id)kSecAttrKeyType:        (id)kSecAttrKeyTypeRSA,
        (id)kSecAttrApplicationTag: tag,
        (id)kSecAttrKeyClass:       (id)kSecAttrKeyClassPrivate,
        (id)kSecAttrSynchronizable: (id)kCFBooleanTrue,
        (id)kSecReturnRef:          @YES,
    };
    SecKeyRef key = NULL;
    SecItemCopyMatching((__bridge CFDictionaryRef)query, (CFTypeRef *)&key);
    return key; // caller must CFRelease
}

@implementation WCOfflineMessageCrypto

+ (nullable NSData *)publicKeyDERForServerID:(NSString *)serverID {
    NSData *tag = _WCKeyTagForServerID(serverID);

    // Try to load existing private key
    SecKeyRef privKey = _WCCopyPrivateKey(tag);
    if(privKey) {
        SecKeyRef pubKey = SecKeyCopyPublicKey(privKey);
        CFRelease(privKey);
        if(pubKey) {
            CFErrorRef cfErr = NULL;
            NSData *der = (NSData *)CFBridgingRelease(SecKeyCopyExternalRepresentation(pubKey, &cfErr));
            CFRelease(pubKey);
            if(cfErr) { CFRelease(cfErr); return nil; }
            return der;
        }
        return nil;
    }

    // Generate new RSA-2048 key pair and store private key in Keychain
    NSDictionary *privateAttrs = @{
        (id)kSecAttrIsPermanent:    @YES,
        (id)kSecAttrApplicationTag: tag,
        (id)kSecAttrAccessible:     (id)kSecAttrAccessibleAfterFirstUnlock,
        (id)kSecAttrSynchronizable: @YES,
    };
    NSDictionary *params = @{
        (id)kSecAttrKeyType:        (id)kSecAttrKeyTypeRSA,
        (id)kSecAttrKeySizeInBits:  @2048,
        (id)kSecPrivateKeyAttrs:    privateAttrs,
    };
    CFErrorRef cfErr = NULL;
    SecKeyRef newPrivKey = SecKeyCreateRandomKey((__bridge CFDictionaryRef)params, &cfErr);
    if(!newPrivKey || cfErr) {
        if(cfErr) CFRelease(cfErr);
        if(newPrivKey) CFRelease(newPrivKey);
        return nil;
    }

    SecKeyRef newPubKey = SecKeyCopyPublicKey(newPrivKey);
    CFRelease(newPrivKey);
    if(!newPubKey) return nil;

    NSData *der = (NSData *)CFBridgingRelease(SecKeyCopyExternalRepresentation(newPubKey, &cfErr));
    CFRelease(newPubKey);
    if(cfErr) { CFRelease(cfErr); return nil; }
    return der;
}

+ (nullable NSData *)encryptMessage:(NSString *)plaintext withPublicKeyDER:(NSData *)pubKeyDER {
    if(!plaintext || !pubKeyDER) return nil;

    CFErrorRef cfErr = NULL;
    NSDictionary *attrs = @{
        (id)kSecAttrKeyType:  (id)kSecAttrKeyTypeRSA,
        (id)kSecAttrKeyClass: (id)kSecAttrKeyClassPublic,
    };
    SecKeyRef pubKey = SecKeyCreateWithData((__bridge CFDataRef)pubKeyDER,
                                            (__bridge CFDictionaryRef)attrs,
                                            &cfErr);
    if(!pubKey || cfErr) {
        if(cfErr) CFRelease(cfErr);
        if(pubKey) CFRelease(pubKey);
        return nil;
    }

    NSData *plaintextData = [plaintext dataUsingEncoding:NSUTF8StringEncoding];
    NSData *ciphertext = (NSData *)CFBridgingRelease(
        SecKeyCreateEncryptedData(pubKey,
                                  kSecKeyAlgorithmRSAEncryptionOAEPSHA256AESGCM,
                                  (__bridge CFDataRef)plaintextData,
                                  &cfErr));
    CFRelease(pubKey);
    if(cfErr) { CFRelease(cfErr); return nil; }
    return ciphertext;
}

+ (nullable NSString *)decryptCiphertext:(NSData *)ciphertext forServerID:(NSString *)serverID {
    if(!ciphertext) return nil;

    NSData *tag = _WCKeyTagForServerID(serverID);
    SecKeyRef privKey = _WCCopyPrivateKey(tag);
    if(!privKey) return nil;

    CFErrorRef cfErr = NULL;
    NSData *plaintextData = (NSData *)CFBridgingRelease(
        SecKeyCreateDecryptedData(privKey,
                                  kSecKeyAlgorithmRSAEncryptionOAEPSHA256AESGCM,
                                  (__bridge CFDataRef)ciphertext,
                                  &cfErr));
    CFRelease(privKey);
    if(cfErr) { CFRelease(cfErr); return nil; }
    if(!plaintextData) return nil;
    return [[NSString alloc] initWithData:plaintextData encoding:NSUTF8StringEncoding];
}

@end
