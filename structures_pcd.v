module structures

// PCD (Piece Descriptor) describes a piece of text in the document.
// Each piece references a contiguous run of text in the WordDocument stream.
pub struct PCD {
pub mut:
	f_no_encryption bool   // If true, piece is not encrypted
	f_complex       bool   // If true, piece contains complex formatting
	fc              u32    // File Character position in WordDocument stream
	is_unicode      bool   // If true, text is Unicode; if false, text is ANSI
}

// parse_pcd parses a PCD structure from an 8-byte data element.
pub fn parse_pcd(data []u8) !PCD {
	if data.len != 8 {
		return error('pcd: invalid data size ${data.len}, expected 8')
	}

	mut pcd := PCD{}

	// First 2 bytes contain flags
	flags := u16(data[0]) | (u16(data[1]) << 8)
	pcd.f_no_encryption = (flags & 0x0001) != 0
	pcd.f_complex = (flags & 0x0002) != 0

	// Next 4 bytes contain the file character position
	fc := u32(data[2]) | (u32(data[3]) << 8) | (u32(data[4]) << 16) | (u32(data[5]) << 24)

	// Check if this is Unicode text
	pcd.is_unicode = (fc & 0x40000000) != 0

	// Clear the Unicode flag to get the actual file position
	pcd.fc = fc & 0x3FFFFFFF

	return pcd
}

// get_actual_fc returns the actual file position for reading text.
// For Unicode text, the position needs to be divided by 2.
pub fn (pcd &PCD) get_actual_fc() u32 {
	if pcd.is_unicode {
		return pcd.fc / 2
	}
	return pcd.fc
}

// is_encrypted returns true if this piece is encrypted.
pub fn (pcd &PCD) is_encrypted() bool {
	return !pcd.f_no_encryption
}

// has_complex_formatting returns true if this piece has complex formatting.
pub fn (pcd &PCD) has_complex_formatting() bool {
	return pcd.f_complex
}

// get_text_encoding returns the text encoding type.
pub fn (pcd &PCD) get_text_encoding() string {
	if pcd.is_unicode {
		return 'UTF-16LE'
	}
	return 'ANSI'
}

// get_char_size returns the number of bytes per character.
pub fn (pcd &PCD) get_char_size() u32 {
	if pcd.is_unicode {
		return 2
	}
	return 1
}

// to_bytes converts the PCD back to 8-byte representation.
pub fn (pcd &PCD) to_bytes() []u8 {
	mut data := []u8{len: 8}

	// Build flags
	mut flags := u16(0)
	if pcd.f_no_encryption {
		flags |= 0x0001
	}
	if pcd.f_complex {
		flags |= 0x0002
	}

	// Set flags in first 2 bytes
	data[0] = u8(flags & 0xFF)
	data[1] = u8((flags >> 8) & 0xFF)

	// Build FC with Unicode flag if needed
	mut fc := pcd.fc
	if pcd.is_unicode {
		fc |= 0x40000000
	}

	// Set FC in next 4 bytes
	data[2] = u8(fc & 0xFF)
	data[3] = u8((fc >> 8) & 0xFF)
	data[4] = u8((fc >> 16) & 0xFF)
	data[5] = u8((fc >> 24) & 0xFF)

	// Last 2 bytes are typically zero or contain additional flags
	data[6] = 0
	data[7] = 0

	return data
}

// calculate_text_length calculates the actual text length for this piece.
pub fn (pcd &PCD) calculate_text_length(char_count u32) u32 {
	return char_count * pcd.get_char_size()
}

// str returns a string representation of the PCD.
pub fn (pcd &PCD) str() string {
	mut info := 'PCD{fc: 0x${pcd.fc:x}, encoding: ${pcd.get_text_encoding()}'
	if pcd.f_no_encryption {
		info += ', unencrypted'
	} else {
		info += ', encrypted'
	}
	if pcd.f_complex {
		info += ', complex'
	}
	info += '}'
	return info
}