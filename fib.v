module fib

// FileInformationBlock is the top-level structure for the FIB.
pub struct FileInformationBlock {
pub mut:
	base         FibBase
	csw          u16
	fib_rg_w     FibRgW97
	cslw         u16
	fib_rg_lw    FibRgLw97
	cb_rg_fc_lcb u16
	rg_fc_lcb_blob []u8  // Variable part, raw bytes for now
	// Parsed version for convenience
	rg_fc_lcb    FibRgFcLcb97
	csw_new      u16
}

// FibBase is the fixed-size (32 byte) header of the FIB.
pub struct FibBase {
pub mut:
	w_ident   u16
	n_fib     u16
	unused1   u16  // unused
	lid       u16
	pn_next   u16
	flags1    u16
	n_fib_back u16
	l_key     u32
	envr      u8
	flags2    u8
	reserved1 [2]u16  // reserved
	reserved2 [2]u32  // reserved
}

// FibRgW97 is the 16-bit value section of the FIB.
pub struct FibRgW97 {
pub mut:
	data [28]u8  // 14 values, stubbed for simplicity
}

// FibRgLw97 is the 32-bit value section of the FIB.
// We care about ccpText for text extraction.
pub struct FibRgLw97 {
pub mut:
	cb_mac     u32  // Size of main document text stream in bytes
	reserved1  u32  // reserved
	ccp_text   u32  // Count of characters in main document
	ccp_ftn    u32  // Count of characters in footnotes
	ccp_hdd    u32  // Count of characters in headers/footers
	reserved2  u32  // reserved
	ccp_atn    u32  // Count of characters in annotations
	ccp_edn    u32  // Count of characters in endnotes
	ccp_txbx   u32  // Count of characters in textboxes
	reserved3  [13]u32  // more reserved fields
}

// FibRgFcLcb97 contains file positions and lengths for various document parts.
pub struct FibRgFcLcb97 {
pub mut:
	fc_stsh_f       u32  // File position of stylesheet
	lcb_stsh_f      u32  // Length of stylesheet
	fc_clx          u32  // File position of complex (piece table)
	lcb_clx         u32  // Length of complex
	fc_plc_f_hdr    u32  // File position of header stories PLC
	lcb_plc_f_hdr   u32  // Length of header stories PLC
	// Many more fields exist, but we'll focus on the essentials
	other_fields   [200]u8  // Placeholder for remaining fields
}

// is_encrypted returns true if the document is encrypted.
pub fn (f &FileInformationBlock) is_encrypted() bool {
	return f.base.flags1 & 0x0100 != 0
}

// has_macros returns true if the document has VBA macros.
pub fn (f &FileInformationBlock) has_macros() bool {
	return f.base.flags1 & 0x0008 != 0
}

// get_text_length returns the length of the main document text.
pub fn (f &FileInformationBlock) get_text_length() u32 {
	return f.fib_rg_lw.ccp_text
}

// parse_fib parses a FIB from raw bytes.
pub fn parse_fib(data []u8) !FileInformationBlock {
	if data.len < 68 {  // Minimum FIB size
		return error('fib: data too short for FIB')
	}
	
	// Parse FibBase (first 32 bytes)
	base := FibBase{
		w_ident: u16(data[0]) | (u16(data[1]) << 8)
		n_fib: u16(data[2]) | (u16(data[3]) << 8)
		unused1: u16(data[4]) | (u16(data[5]) << 8)
		lid: u16(data[6]) | (u16(data[7]) << 8)
		pn_next: u16(data[8]) | (u16(data[9]) << 8)
		flags1: u16(data[10]) | (u16(data[11]) << 8)
		n_fib_back: u16(data[12]) | (u16(data[13]) << 8)
		l_key: u32(data[14]) | (u32(data[15]) << 8) | (u32(data[16]) << 16) | (u32(data[17]) << 24)
		envr: data[18]
		flags2: data[19]
		reserved1: [u16(data[20]) | (u16(data[21]) << 8), u16(data[22]) | (u16(data[23]) << 8)]!
		reserved2: [u32(data[24]) | (u32(data[25]) << 8) | (u32(data[26]) << 16) | (u32(data[27]) << 24),
		            u32(data[28]) | (u32(data[29]) << 8) | (u32(data[30]) << 16) | (u32(data[31]) << 24)]!
	}
	
	if data.len < 34 {
		return error('fib: data too short for csw')
	}
	
	csw := u16(data[32]) | (u16(data[33]) << 8)
	
	// Parse FibRgW (skip for now, just read as raw bytes)
	mut fib_rg_w := FibRgW97{}
	if data.len >= 34 + int(csw * 2) {
		for i in 0..28 {
			if 34 + i < data.len {
				fib_rg_w.data[i] = data[34 + i]
			}
		}
	}
	
	mut offset := 34 + int(csw * 2)
	if data.len < offset + 2 {
		return error('fib: data too short for cslw')
	}
	
	cslw := u16(data[offset]) | (u16(data[offset + 1]) << 8)
	offset += 2
	
	// Parse FibRgLw (32-bit values)
	mut fib_rg_lw := FibRgLw97{}
	if data.len >= offset + int(cslw * 4) {
		if cslw > 0 && offset + 4 <= data.len {
			fib_rg_lw.cb_mac = u32(data[offset]) | (u32(data[offset + 1]) << 8) |
			                  (u32(data[offset + 2]) << 16) | (u32(data[offset + 3]) << 24)
		}
		if cslw > 2 && offset + 12 <= data.len {
			fib_rg_lw.ccp_text = u32(data[offset + 8]) | (u32(data[offset + 9]) << 8) |
			                    (u32(data[offset + 10]) << 16) | (u32(data[offset + 11]) << 24)
		}
		if cslw > 3 && offset + 16 <= data.len {
			fib_rg_lw.ccp_ftn = u32(data[offset + 12]) | (u32(data[offset + 13]) << 8) |
			                   (u32(data[offset + 14]) << 16) | (u32(data[offset + 15]) << 24)
		}
		if cslw > 4 && offset + 20 <= data.len {
			fib_rg_lw.ccp_hdd = u32(data[offset + 16]) | (u32(data[offset + 17]) << 8) |
			                   (u32(data[offset + 18]) << 16) | (u32(data[offset + 19]) << 24)
		}
		if cslw > 6 && offset + 28 <= data.len {
			fib_rg_lw.ccp_atn = u32(data[offset + 24]) | (u32(data[offset + 25]) << 8) |
			                   (u32(data[offset + 26]) << 16) | (u32(data[offset + 27]) << 24)
		}
		if cslw > 7 && offset + 32 <= data.len {
			fib_rg_lw.ccp_edn = u32(data[offset + 28]) | (u32(data[offset + 29]) << 8) |
			                   (u32(data[offset + 30]) << 16) | (u32(data[offset + 31]) << 24)
		}
		if cslw > 8 && offset + 36 <= data.len {
			fib_rg_lw.ccp_txbx = u32(data[offset + 32]) | (u32(data[offset + 33]) << 8) |
			                    (u32(data[offset + 34]) << 16) | (u32(data[offset + 35]) << 24)
		}
	}
	
	offset += int(cslw * 4)
	
	// Parse cbRgFcLcb
	mut cb_rg_fc_lcb := u16(0)
	if data.len > offset + 1 {
		cb_rg_fc_lcb = u16(data[offset]) | (u16(data[offset + 1]) << 8)
		offset += 2
	}
	
	// Read RgFcLcb blob (variable length section)
	mut rg_fc_lcb_blob := []u8{}
	blob_size := int(cb_rg_fc_lcb * 8)  // Each entry is 8 bytes (4 byte FC + 4 byte LCB)
	if data.len >= offset + blob_size {
		rg_fc_lcb_blob = data[offset..offset + blob_size].clone()
	}
	
	// Parse some important FcLcb entries
	mut rg_fc_lcb := FibRgFcLcb97{}
	if blob_size >= 8 {
		rg_fc_lcb.fc_stsh_f = u32(rg_fc_lcb_blob[0]) | (u32(rg_fc_lcb_blob[1]) << 8) |
		                     (u32(rg_fc_lcb_blob[2]) << 16) | (u32(rg_fc_lcb_blob[3]) << 24)
		rg_fc_lcb.lcb_stsh_f = u32(rg_fc_lcb_blob[4]) | (u32(rg_fc_lcb_blob[5]) << 8) |
		                      (u32(rg_fc_lcb_blob[6]) << 16) | (u32(rg_fc_lcb_blob[7]) << 24)
	}
	if blob_size >= 16 {
		rg_fc_lcb.fc_clx = u32(rg_fc_lcb_blob[8]) | (u32(rg_fc_lcb_blob[9]) << 8) |
		                  (u32(rg_fc_lcb_blob[10]) << 16) | (u32(rg_fc_lcb_blob[11]) << 24)
		rg_fc_lcb.lcb_clx = u32(rg_fc_lcb_blob[12]) | (u32(rg_fc_lcb_blob[13]) << 8) |
		                   (u32(rg_fc_lcb_blob[14]) << 16) | (u32(rg_fc_lcb_blob[15]) << 24)
	}
	
	return FileInformationBlock{
		base: base
		csw: csw
		fib_rg_w: fib_rg_w
		cslw: cslw
		fib_rg_lw: fib_rg_lw
		cb_rg_fc_lcb: cb_rg_fc_lcb
		rg_fc_lcb_blob: rg_fc_lcb_blob
		rg_fc_lcb: rg_fc_lcb
		csw_new: 0
	}
}