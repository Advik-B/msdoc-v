module streams

import fib

// DataStream represents the optional Data stream containing additional document data.
pub struct DataStream {
pub mut:
	data []u8
}

// new_data_stream creates a new Data stream processor.
pub fn new_data_stream(data []u8) DataStream {
	return DataStream{
		data: data.clone()
	}
}

// get_data extracts data from the specified range within the Data stream.
pub fn (ds &DataStream) get_data(offset u32, length u32) ![]u8 {
	if length == 0 {
		return []u8{}
	}

	if offset + length > u32(ds.data.len) {
		return error('data: requested range out of bounds')
	}

	mut result := []u8{len: int(length)}
	for i in 0 .. length {
		result[i] = ds.data[offset + i]
	}
	return result
}

// size returns the total size of the Data stream.
pub fn (ds &DataStream) size() u32 {
	return u32(ds.data.len)
}

// is_empty returns true if the Data stream has no content.
pub fn (ds &DataStream) is_empty() bool {
	return ds.data.len == 0
}

// TableStream represents the Table stream (0Table or 1Table) containing document structure data.
pub struct TableStream {
pub mut:
	data   []u8
	name   string // "0Table" or "1Table"
	fib    &fib.FileInformationBlock
}

// new_table_stream creates a new Table stream processor.
pub fn new_table_stream(data []u8, name string, fib &fib.FileInformationBlock) TableStream {
	return TableStream{
		data: data.clone()
		name: name
		fib: fib
	}
}

// get_clx_data extracts the CLX (piece table) data from the table stream.
pub fn (ts &TableStream) get_clx_data() ![]u8 {
	clx_offset := ts.fib.rg_fc_lcb.fc_clx
	clx_size := ts.fib.rg_fc_lcb.lcb_clx

	if clx_size == 0 {
		return []u8{}
	}

	if u32(ts.data.len) < clx_offset + clx_size {
		return error('table stream too small for CLX data')
	}

	return ts.data[clx_offset..clx_offset + clx_size].clone()
}

// get_style_data extracts stylesheet data from the table stream.
pub fn (ts &TableStream) get_style_data() ![]u8 {
	stsh_offset := ts.fib.rg_fc_lcb.fc_stsh_f
	stsh_size := ts.fib.rg_fc_lcb.lcb_stsh_f

	if stsh_size == 0 {
		return []u8{}
	}

	if u32(ts.data.len) < stsh_offset + stsh_size {
		return error('table stream too small for style data')
	}

	return ts.data[stsh_offset..stsh_offset + stsh_size].clone()
}

// get_field_data extracts field PLC data from the table stream.
pub fn (ts &TableStream) get_field_data() ![]u8 {
	// For now, return empty data as the exact field offset calculation
	// would require complete FIB structure implementation
	return []u8{}
}

// get_section_data extracts section properties data from the table stream.
pub fn (ts &TableStream) get_section_data() ![]u8 {
	// For now, return empty data as the exact field offset calculation
	// would require complete FIB structure implementation
	return []u8{}
}

// extract_data extracts data from specified offset and length.
pub fn (ts &TableStream) extract_data(offset u32, length u32) ![]u8 {
	if length == 0 {
		return []u8{}
	}

	if offset + length > u32(ts.data.len) {
		return error('table: requested range out of bounds')
	}

	return ts.data[offset..offset + length].clone()
}

// size returns the total size of the Table stream.
pub fn (ts &TableStream) size() u32 {
	return u32(ts.data.len)
}

// WordDocumentStream represents the main WordDocument stream containing document text and formatting.
pub struct WordDocumentStream {
pub mut:
	data []u8
	fib  &fib.FileInformationBlock
}

// new_word_document_stream creates a new WordDocument stream processor.
pub fn new_word_document_stream(data []u8, fib_data &fib.FileInformationBlock) WordDocumentStream {
	return WordDocumentStream{
		data: data.clone()
		fib: unsafe { fib_data }
	}
}

// get_text_data extracts text data from the specified range.
pub fn (wds &WordDocumentStream) get_text_data(offset u32, length u32) ![]u8 {
	if length == 0 {
		return []u8{}
	}

	if offset + length > u32(wds.data.len) {
		return error('worddocument: requested range out of bounds')
	}

	return wds.data[offset..offset + length].clone()
}

// get_main_text_range returns the range of the main document text.
pub fn (wds &WordDocumentStream) get_main_text_range() (u32, u32) {
	// Main text starts after the FIB
	start_offset := u32(1024) // Typical FIB size
	text_length := wds.fib.get_text_length()

	// For Unicode text, multiply by 2
	if wds.is_unicode() {
		return start_offset, text_length * 2
	}
	return start_offset, text_length
}

// is_unicode returns true if the document contains Unicode text.
pub fn (wds &WordDocumentStream) is_unicode() bool {
	// Check FIB flags for Unicode indicator
	return wds.fib.base.flags1 & 0x1000 != 0
}

// extract_text_at extracts text from a specific position and length.
pub fn (wds &WordDocumentStream) extract_text_at(position u32, length u32) !string {
	data := wds.get_text_data(position, length)!
	
	if wds.is_unicode() {
		// Convert UTF-16LE to string
		mut result := ''
		for i := 0; i < data.len; i += 2 {
			if i + 1 < data.len {
				code_unit := u16(data[i]) | (u16(data[i + 1]) << 8)
				if code_unit >= 32 && code_unit < 127 {
					result += code_unit.str()
				} else if code_unit == 13 || code_unit == 10 {
					result += '\n'
				} else if code_unit == 9 {
					result += '\t'
				}
			}
		}
		return result
	} else {
		// ANSI text
		mut result := ''
		for b in data {
			if b >= 32 && b < 127 {
				result += b.ascii_str()
			} else if b == 13 || b == 10 {
				result += '\n'
			} else if b == 9 {
				result += '\t'
			}
		}
		return result
	}
}

// size returns the total size of the WordDocument stream.
pub fn (wds &WordDocumentStream) size() u32 {
	return u32(wds.data.len)
}

// get_formatting_data_at extracts formatting data from a specific position.
pub fn (wds &WordDocumentStream) get_formatting_data_at(position u32, length u32) ![]u8 {
	if position + length > u32(wds.data.len) {
		return error('worddocument: formatting data out of bounds')
	}

	return wds.data[position..position + length].clone()
}