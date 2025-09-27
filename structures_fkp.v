module structures

// FKP (Formatted Disk Page) is a 512-byte page containing formatting data.
// There are different types of FKPs for different kinds of formatting:
// - CHPX FKP: Character properties (formatting like bold, italic, etc.)
// - PAPX FKP: Paragraph properties (formatting like alignment, spacing, etc.)
pub const fkp_size = 512

// FKPType indicates the type of formatting stored in the FKP.
pub enum FKPType {
	unknown
	chp  // Character properties
	pap  // Paragraph properties
}

// FKPEntry represents a single formatting entry within an FKP.
pub struct FKPEntry {
pub mut:
	fc     u32    // File character position
	offset u16    // Offset within the FKP to the formatting data
	data   []u8   // The actual formatting data
}

// FKP represents a formatted disk page containing formatting information.
pub struct FKP {
pub mut:
	data        []u8        // Raw 512-byte page data
	fkp_type    FKPType
	entries     []FKPEntry
	entry_count int
}

// parse_fkp parses an FKP from raw 512-byte page data.
pub fn parse_fkp(data []u8, fkp_type FKPType) !FKP {
	if data.len != fkp_size {
		return error('fkp: invalid data size ${data.len}, expected $fkp_size')
	}

	mut fkp := FKP{
		data: data.clone()
		fkp_type: fkp_type
		entries: []
		entry_count: 0
	}

	// The last byte contains the count of entries
	fkp.entry_count = int(data[fkp_size - 1])
	
	if fkp.entry_count > 127 {
		return error('fkp: invalid entry count ${fkp.entry_count}')
	}

	// Parse entries based on type
	match fkp_type {
		.chp { fkp.parse_chp_entries()! }
		.pap { fkp.parse_pap_entries()! }
		else { return error('fkp: unsupported FKP type') }
	}

	return fkp
}

// parse_chp_entries parses character property entries
fn (mut fkp FKP) parse_chp_entries() ! {
	// CHP FKPs have FC values at offsets 0, 4, 8, ... (4 bytes each)
	// followed by 1-byte offsets
	mut entries := []FKPEntry{}
	
	for i in 0 .. fkp.entry_count {
		// Read FC (4 bytes)
		fc_offset := i * 4
		if fc_offset + 4 > fkp.data.len - 1 {
			break
		}
		fc := u32(fkp.data[fc_offset]) | (u32(fkp.data[fc_offset+1]) << 8) |
		     (u32(fkp.data[fc_offset+2]) << 16) | (u32(fkp.data[fc_offset+3]) << 24)

		// Read offset (1 byte) - offsets are stored after all FCs
		offset_pos := (fkp.entry_count + 1) * 4 + i
		if offset_pos >= fkp.data.len - 1 {
			break
		}
		offset := u16(fkp.data[offset_pos]) * 2 // Offsets are stored as half-words

		// Extract formatting data
		mut entry_data := []u8{}
		if offset > 0 && offset < fkp_size {
			if offset < fkp.data.len {
				// First byte is length of formatting data
				data_len := int(fkp.data[offset])
				if data_len > 0 && offset + 1 + data_len <= fkp.data.len {
					entry_data = fkp.data[offset + 1..offset + 1 + data_len].clone()
				}
			}
		}

		entries << FKPEntry{
			fc: fc
			offset: offset
			data: entry_data
		}
	}

	fkp.entries = entries
}

// parse_pap_entries parses paragraph property entries
fn (mut fkp FKP) parse_pap_entries() ! {
	// PAP FKPs are similar to CHP but may have different data structure
	mut entries := []FKPEntry{}
	
	for i in 0 .. fkp.entry_count {
		// Read FC (4 bytes)
		fc_offset := i * 4
		if fc_offset + 4 > fkp.data.len - 1 {
			break
		}
		fc := u32(fkp.data[fc_offset]) | (u32(fkp.data[fc_offset+1]) << 8) |
		     (u32(fkp.data[fc_offset+2]) << 16) | (u32(fkp.data[fc_offset+3]) << 24)

		// Read offset (1 byte) - offsets are stored after all FCs
		offset_pos := (fkp.entry_count + 1) * 4 + i
		if offset_pos >= fkp.data.len - 1 {
			break
		}
		offset := u16(fkp.data[offset_pos]) * 2

		// Extract formatting data
		mut entry_data := []u8{}
		if offset > 0 && offset < fkp_size {
			if offset < fkp.data.len {
				// For PAP, data structure can be more complex
				data_len := int(fkp.data[offset])
				if data_len > 0 && offset + 1 + data_len <= fkp.data.len {
					entry_data = fkp.data[offset + 1..offset + 1 + data_len].clone()
				}
			}
		}

		entries << FKPEntry{
			fc: fc
			offset: offset
			data: entry_data
		}
	}

	fkp.entries = entries
}

// get_entry_at returns the FKP entry at the given index.
pub fn (fkp &FKP) get_entry_at(index int) !FKPEntry {
	if index < 0 || index >= fkp.entries.len {
		return error('fkp: invalid index $index')
	}
	return fkp.entries[index]
}

// find_entry_for_fc finds the FKP entry that covers the given FC.
pub fn (fkp &FKP) find_entry_for_fc(fc u32) ?FKPEntry {
	for i := 0; i < fkp.entries.len - 1; i++ {
		if fc >= fkp.entries[i].fc && fc < fkp.entries[i+1].fc {
			return fkp.entries[i]
		}
	}
	return none
}