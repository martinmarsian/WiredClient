/* $Id$ */

/*
 *  Copyright (c) 2025 Jörg Märtin
 *  All rights reserved.
 *
 * Handles RSA-2048 key management and hybrid encryption/decryption for
 * end-to-end encrypted offline messages in WiredClient.
 *
 * Private keys are stored in the macOS Keychain, scoped per server identity.
 * Encryption uses RSA-OAEP-SHA256 with AES-256 (SecKeyAlgorithmRSAEncryptionOAEPSHA256AESManifold).
 */

#import <Foundation/Foundation.h>
#import <Security/Security.h>

NS_ASSUME_NONNULL_BEGIN

@interface WCOfflineMessageCrypto : NSObject

/**
 * Returns the DER-encoded RSA-2048 public key for the given server identity,
 * generating and storing a new key pair in the Keychain if none exists yet.
 * Returns nil on unrecoverable error.
 */
+ (nullable NSData *)publicKeyDERForServerID:(NSString *)serverID;

/**
 * Encrypts a plaintext string using the recipient's public key.
 * Uses RSA-OAEP-SHA256 with AES-256 hybrid encryption.
 * Returns nil if pubKeyDER is invalid or encryption fails.
 */
+ (nullable NSData *)encryptMessage:(NSString *)plaintext withPublicKeyDER:(NSData *)pubKeyDER;

/**
 * Decrypts a ciphertext blob using the private key stored in the Keychain
 * for the given server identity. Returns nil if the key is unavailable or
 * decryption fails (e.g. key was rotated or device changed).
 */
+ (nullable NSString *)decryptCiphertext:(NSData *)ciphertext forServerID:(NSString *)serverID;

@end

NS_ASSUME_NONNULL_END
