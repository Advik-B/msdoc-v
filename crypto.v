module crypto

import crypto.md5

// RC4 represents an RC4 cipher context.
pub struct RC4 {
mut:
	s    [256]u8
	i    u8
	j    u8
}

// new_rc4 creates a new RC4 cipher with the given key.
pub fn new_rc4(key []u8) !RC4 {
	if key.len == 0 {
		return error('rc4: key cannot be empty')
	}

	mut rc4 := RC4{}

	// Key-scheduling algorithm (KSA)
	for i in 0..256 {
		rc4.s[i] = u8(i)
	}

	mut j := u8(0)
	for i in 0..256 {
		j = j + rc4.s[i] + key[i % key.len]
		rc4.s[i], rc4.s[j] = rc4.s[j], rc4.s[i]
	}

	rc4.i = 0
	rc4.j = 0

	return rc4
}

// decrypt decrypts the given data using RC4.
// RC4 is symmetric, so this function can also be used for encryption.
pub fn (mut rc4 RC4) decrypt(data []u8) []u8 {
	mut output := []u8{len: data.len}

	for k in 0..data.len {
		rc4.i++
		rc4.j += rc4.s[rc4.i]
		rc4.s[rc4.i], rc4.s[rc4.j] = rc4.s[rc4.j], rc4.s[rc4.i]
		output[k] = data[k] ^ rc4.s[rc4.s[rc4.i] + rc4.s[rc4.j]]
	}

	return output
}

// generate_password_hash creates a password hash compatible with Word documents.
// This implements the Word 97-2003 password hashing algorithm.
pub fn generate_password_hash(password string) []u8 {
	if password.len == 0 {
		return []
	}

	// Convert password to UTF-16LE
	mut utf16_password := []u8{}
	for r in password.runes() {
		utf16_password << u8(r)
		utf16_password << u8(r >> 8)
	}

	// Generate MD5 hash
	hash := md5.sum(utf16_password)
	return hash
}

// generate_decryption_key creates the decryption key from password and document salt.
// This follows the MS-DOC specification for password-based encryption.
pub fn generate_decryption_key(password string, salt []u8) ![]u8 {
	if password.len == 0 {
		return error('password cannot be empty')
	}

	if salt.len < 16 {
		return error('salt must be at least 16 bytes, got ${salt.len}')
	}

	// Generate password hash
	password_hash := generate_password_hash(password)

	// Combine password hash with document salt
	mut combined := password_hash.clone()
	combined << salt[..16]

	// Generate final key hash
	final_hash := md5.sum(combined)
	return final_hash
}

// verify_password checks if the given password matches the document's password hash.
pub fn verify_password(password string, expected_hash []u8, salt []u8) !bool {
	if expected_hash.len != 16 {
		return error('expected hash must be 16 bytes')
	}

	key := generate_decryption_key(password, salt)!

	// Compare the generated key with expected hash
	for i in 0..16 {
		if key[i] != expected_hash[i] {
			return false
		}
	}

	return true
}

// EncryptionHeader represents the encryption information stored in the table stream
// for encrypted Word documents.
pub struct EncryptionHeader {
pub mut:
	version            u16    // Encryption version
	encryption_flags   u32    // Encryption flags
	header_size        u32    // Size of encryption header
	provider_type      u32    // Cryptographic provider type
	alg_id             u32    // Algorithm identifier
	alg_hash_id        u32    // Hash algorithm identifier
	key_size           u32    // Key size in bits
	provider_name      string // Cryptographic provider name
	salt               []u8   // Random salt for key derivation
	encrypted_verifier []u8   // Encrypted verifier for password validation
	verifier_hash      []u8   // Hash of the verifier
}

// parse_encryption_header parses the encryption header from table stream data.
pub fn parse_encryption_header(data []u8) !EncryptionHeader {
	if data.len < 32 {
		return error('encryption header too small')
	}

	mut header := EncryptionHeader{}
	mut offset := 0

	// Read basic header fields
	header.version = u16(data[offset]) | (u16(data[offset+1]) << 8)
	offset += 2

	header.encryption_flags = u32(data[offset]) | (u32(data[offset+1]) << 8) |
	                         (u32(data[offset+2]) << 16) | (u32(data[offset+3]) << 24)
	offset += 4

	header.header_size = u32(data[offset]) | (u32(data[offset+1]) << 8) |
	                    (u32(data[offset+2]) << 16) | (u32(data[offset+3]) << 24)
	offset += 4

	header.provider_type = u32(data[offset]) | (u32(data[offset+1]) << 8) |
	                      (u32(data[offset+2]) << 16) | (u32(data[offset+3]) << 24)
	offset += 4

	header.alg_id = u32(data[offset]) | (u32(data[offset+1]) << 8) |
	               (u32(data[offset+2]) << 16) | (u32(data[offset+3]) << 24)
	offset += 4

	header.alg_hash_id = u32(data[offset]) | (u32(data[offset+1]) << 8) |
	                    (u32(data[offset+2]) << 16) | (u32(data[offset+3]) << 24)
	offset += 4

	header.key_size = u32(data[offset]) | (u32(data[offset+1]) << 8) |
	                 (u32(data[offset+2]) << 16) | (u32(data[offset+3]) << 24)
	offset += 4

	// Skip reserved bytes and read provider name, salt, etc.
	// This is a simplified version - full implementation would handle
	// variable-length fields properly
	
	if data.len > offset + 16 {
		header.salt = data[offset..offset + 16].clone()
		offset += 16
	}

	return header
}