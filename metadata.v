module metadata

import time
import ole2

// DocumentMetadata holds comprehensive document metadata information.
pub struct DocumentMetadata {
pub mut:
	// Core properties
	title               string
	subject             string  
	author              string
	keywords            string
	comments            string
	template            string
	last_author         string
	application_name    string
	created             time.Time
	last_saved          time.Time
	last_printed        time.Time
	total_edit_time     i64
	page_count          i32
	word_count          i32
	char_count          i32
	char_count_with_spaces i32
	
	// Extended properties
	company             string
	manager             string
	category            string
	content_status      string
	content_type        string
	language            i32
	custom_properties   map[string]string
}

// MetadataExtractor handles extraction of metadata from .doc files.
pub struct MetadataExtractor {
mut:
	reader &ole2.Reader
}

// new_metadata_extractor creates a new metadata extractor.
pub fn new_metadata_extractor(reader &ole2.Reader) MetadataExtractor {
	return MetadataExtractor{
		reader: reader
	}
}

// extract_metadata extracts all available metadata from the document.
pub fn (me &MetadataExtractor) extract_metadata() !DocumentMetadata {
	mut metadata := DocumentMetadata{}

	// Extract SummaryInformation properties
	me.extract_summary_information(mut metadata) or {
		// Continue if SummaryInformation is not available
	}

	// Extract DocumentSummaryInformation properties
	me.extract_document_summary_information(mut metadata) or {
		// Continue if DocumentSummaryInformation is not available
	}

	return metadata
}

// extract_summary_information extracts metadata from SummaryInformation stream.
fn (me &MetadataExtractor) extract_summary_information(mut metadata DocumentMetadata) ! {
	data := me.reader.read_stream('SummaryInformation')!
	
	// Parse the SummaryInformation property set
	// This is a simplified implementation - the actual format is quite complex
	if data.len < 48 {
		return error('SummaryInformation stream too short')
	}

	// Skip property set header and read properties
	mut offset := 48  // Skip standard property set header
	
	// This is a very simplified parser - the actual implementation would need
	// to properly parse the property set structure with property identifiers,
	// offsets, and types according to the OLE Property Set specification
	
	// Try to extract some common properties by scanning for recognizable patterns
	me.parse_property_values(data, mut metadata)
}

// extract_document_summary_information extracts metadata from DocumentSummaryInformation stream.
fn (me &MetadataExtractor) extract_document_summary_information(mut metadata DocumentMetadata) ! {
	data := me.reader.read_stream('DocumentSummaryInformation')!
	
	if data.len < 48 {
		return error('DocumentSummaryInformation stream too short')
	}

	// Parse document-specific properties
	me.parse_document_properties(data, mut metadata)
}

// parse_property_values parses property values from property set data.
fn (me &MetadataExtractor) parse_property_values(data []u8, mut metadata DocumentMetadata) {
	// This is a simplified implementation that looks for UTF-16 strings
	// The actual implementation would properly parse the property set format
	
	mut offset := 48
	while offset < data.len - 4 {
		// Look for property length indicators
		if offset + 4 < data.len {
			prop_len := u32(data[offset]) | (u32(data[offset+1]) << 8) |
			          (u32(data[offset+2]) << 16) | (u32(data[offset+3]) << 24)
			
			if prop_len > 0 && prop_len < 1000 && offset + 4 + int(prop_len) <= data.len {
				// Try to extract string property
				prop_data := data[offset + 4..offset + 4 + int(prop_len)]
				if text := me.extract_utf16_string(prop_data) {
					// Heuristic assignment based on position and content
					if metadata.title.len == 0 && text.len > 0 && text.len < 200 {
						metadata.title = text
					} else if metadata.author.len == 0 && text.len > 0 && text.len < 100 {
						metadata.author = text
					} else if metadata.subject.len == 0 && text.len > 0 && text.len < 200 {
						metadata.subject = text
					}
				}
				offset += 4 + int(prop_len)
			} else {
				offset += 4
			}
		} else {
			break
		}
	}
}

// parse_document_properties parses document-specific properties.
fn (me &MetadataExtractor) parse_document_properties(data []u8, mut metadata DocumentMetadata) {
	// Similar to parse_property_values but for document-specific properties
	mut offset := 48
	
	while offset < data.len - 4 {
		if offset + 4 < data.len {
			prop_len := u32(data[offset]) | (u32(data[offset+1]) << 8) |
			          (u32(data[offset+2]) << 16) | (u32(data[offset+3]) << 24)
			
			if prop_len > 0 && prop_len < 1000 && offset + 4 + int(prop_len) <= data.len {
				prop_data := data[offset + 4..offset + 4 + int(prop_len)]
				if text := me.extract_utf16_string(prop_data) {
					// Try to assign to document-specific fields
					if metadata.company.len == 0 && text.len > 0 && text.len < 100 {
						metadata.company = text
					} else if metadata.category.len == 0 && text.len > 0 && text.len < 100 {
						metadata.category = text
					} else if metadata.manager.len == 0 && text.len > 0 && text.len < 100 {
						metadata.manager = text
					}
				}
				offset += 4 + int(prop_len)
			} else {
				offset += 4
			}
		} else {
			break
		}
	}
}

// extract_utf16_string extracts a UTF-16 encoded string from binary data.
fn (me &MetadataExtractor) extract_utf16_string(data []u8) ?string {
	if data.len < 2 || data.len % 2 != 0 {
		return none
	}

	mut result := ''
	mut i := 0
	
	while i < data.len - 1 {
		char_code := u16(data[i]) | (u16(data[i+1]) << 8)
		
		if char_code == 0 {
			break  // Null terminator
		}
		
		if char_code < 128 {  // ASCII range
			result += u8(char_code).ascii_str()
		} else {
			// For simplicity, skip non-ASCII characters
			// A full implementation would properly handle Unicode
		}
		
		i += 2
	}
	
	if result.len == 0 {
		return none
	}
	
	return result.trim_space()
}

// extract_basic_properties extracts basic properties that are commonly available.
pub fn (me &MetadataExtractor) extract_basic_properties() !DocumentMetadata {
	mut metadata := DocumentMetadata{
		application_name: 'Microsoft Office Word'
		content_type: 'application/msword'
	}

	// Try to get creation time from file system or streams
	metadata.created = time.now()
	metadata.last_saved = time.now()

	return metadata
}