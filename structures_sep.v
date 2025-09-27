module structures

// SEPX (Section Property eXtension) contains section-level formatting information.
pub struct SEPX {
pub mut:
	data   []u8 // Raw SEPX data
	length u16  // Length of the SEPX data
}

// SEP (Section Properties) contains parsed section formatting information.
pub struct SEP {
pub mut:
	// Page setup
	xa_page       u16 // Page width in twips
	ya_page       u16 // Page height in twips
	dxa_left      u16 // Left margin in twips
	dxa_right     u16 // Right margin in twips
	dya_top       u16 // Top margin in twips
	dya_bottom    u16 // Bottom margin in twips
	dya_hdr_top   u16 // Header top margin in twips
	dya_hdr_bottom u16 // Header bottom margin in twips

	// Page orientation and layout
	f_landscape   bool // True if landscape orientation
	f_continuous  bool // True if continuous section break
	f_title_page  bool // True if different first page
	f_pgn_restart bool // True if restart page numbering
	pgn_start     u16  // Starting page number

	// Column layout
	ccol_m1         u16  // Number of columns minus 1
	f_evenly_spaced bool // True if columns are evenly spaced
	dxa_columns     u16  // Space between columns in twips

	// Line numbering
	lnc     u8  // Line number count
	dxa_lnn u16 // Distance from text to line numbers
	lnn_min u16 // Starting line number

	// Headers and footers
	grpf_ihdt u8 // Header/footer flags
}

// parse_sepx parses a SEPX structure from raw data.
pub fn parse_sepx(data []u8) !SEPX {
	if data.len < 2 {
		return error('sepx: data too short for length field')
	}

	length := u16(data[0]) | (u16(data[1]) << 8)
	
	if data.len < int(length) + 2 {
		return error('sepx: data shorter than specified length')
	}

	return SEPX{
		data: data[2..length + 2].clone()
		length: length
	}
}

// parse_sep parses a SEP structure from SEPX data.
pub fn parse_sep(sepx SEPX) !SEP {
	if sepx.data.len < 120 { // Minimum SEP size
		return error('sep: data too short for complete SEP structure')
	}

	data := sepx.data
	mut sep := SEP{}

	// Parse page dimensions and margins
	sep.xa_page = u16(data[4]) | (u16(data[5]) << 8)
	sep.ya_page = u16(data[6]) | (u16(data[7]) << 8)
	sep.dxa_left = u16(data[8]) | (u16(data[9]) << 8)
	sep.dxa_right = u16(data[10]) | (u16(data[11]) << 8)
	sep.dya_top = u16(data[12]) | (u16(data[13]) << 8)
	sep.dya_bottom = u16(data[14]) | (u16(data[15]) << 8)

	// Parse header/footer margins
	sep.dya_hdr_top = u16(data[16]) | (u16(data[17]) << 8)
	sep.dya_hdr_bottom = u16(data[18]) | (u16(data[19]) << 8)

	// Parse flags
	if data.len > 20 {
		flags := u16(data[20]) | (u16(data[21]) << 8)
		sep.f_landscape = (flags & 0x0001) != 0
		sep.f_continuous = (flags & 0x0002) != 0
		sep.f_title_page = (flags & 0x0004) != 0
		sep.f_pgn_restart = (flags & 0x0008) != 0
	}

	// Parse page numbering
	if data.len > 22 {
		sep.pgn_start = u16(data[22]) | (u16(data[23]) << 8)
	}

	// Parse column information
	if data.len > 24 {
		sep.ccol_m1 = u16(data[24]) | (u16(data[25]) << 8)
		sep.f_evenly_spaced = (data[26] & 0x01) != 0
		sep.dxa_columns = u16(data[27]) | (u16(data[28]) << 8)
	}

	// Parse line numbering
	if data.len > 29 {
		sep.lnc = data[29]
		sep.dxa_lnn = u16(data[30]) | (u16(data[31]) << 8)
		sep.lnn_min = u16(data[32]) | (u16(data[33]) << 8)
	}

	// Parse header/footer flags
	if data.len > 34 {
		sep.grpf_ihdt = data[34]
	}

	return sep
}

// get_page_width_inches returns the page width in inches.
pub fn (sep &SEP) get_page_width_inches() f64 {
	return f64(sep.xa_page) / 1440.0 // 1440 twips per inch
}

// get_page_height_inches returns the page height in inches.
pub fn (sep &SEP) get_page_height_inches() f64 {
	return f64(sep.ya_page) / 1440.0
}

// get_left_margin_inches returns the left margin in inches.
pub fn (sep &SEP) get_left_margin_inches() f64 {
	return f64(sep.dxa_left) / 1440.0
}

// get_right_margin_inches returns the right margin in inches.
pub fn (sep &SEP) get_right_margin_inches() f64 {
	return f64(sep.dxa_right) / 1440.0
}

// get_top_margin_inches returns the top margin in inches.
pub fn (sep &SEP) get_top_margin_inches() f64 {
	return f64(sep.dya_top) / 1440.0
}

// get_bottom_margin_inches returns the bottom margin in inches.
pub fn (sep &SEP) get_bottom_margin_inches() f64 {
	return f64(sep.dya_bottom) / 1440.0
}

// get_column_count returns the number of columns.
pub fn (sep &SEP) get_column_count() int {
	return int(sep.ccol_m1) + 1
}

// is_portrait returns true if the page is in portrait orientation.
pub fn (sep &SEP) is_portrait() bool {
	return !sep.f_landscape
}

// has_different_first_page returns true if the section has a different first page.
pub fn (sep &SEP) has_different_first_page() bool {
	return sep.f_title_page
}

// has_line_numbering returns true if line numbering is enabled.
pub fn (sep &SEP) has_line_numbering() bool {
	return sep.lnc > 0
}

// get_orientation returns the page orientation as a string.
pub fn (sep &SEP) get_orientation() string {
	if sep.f_landscape {
		return 'landscape'
	}
	return 'portrait'
}

// str returns a string representation of the section properties.
pub fn (sep &SEP) str() string {
	return 'SEP{${sep.get_page_width_inches():.1}x${sep.get_page_height_inches():.1} in, ${sep.get_orientation()}, ${sep.get_column_count()} cols}'
}