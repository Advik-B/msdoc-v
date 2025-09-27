module structures

// CP (Character Position) is an unsigned 32-bit integer that specifies
// a zero-based index of a character in the document text.
pub type CP = u32

// MaxCP is the maximum valid character position value.
pub const max_cp = CP(0x7FFFFFFF)

// is_valid returns true if the CP value is within valid range.
pub fn (cp CP) is_valid() bool {
	return cp <= max_cp
}

// to_int returns the CP as a regular int for array indexing.
// This is safe as long as the CP has been validated.
pub fn (cp CP) to_int() int {
	return int(cp)
}

// distance calculates the number of characters between two CPs.
// Returns 0 if start >= end.
pub fn (cp CP) distance(end CP) u32 {
	if cp >= end {
		return 0
	}
	return u32(end - cp)
}