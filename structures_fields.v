module structures

// Field represents a field in a Word document (used for hyperlinks, etc.)
pub struct Field {
pub mut:
	start       CP     // Character position where field starts
	end         CP     // Character position where field ends
	field_type  u8     // Field type (19h for HYPERLINK)
	field_code  string // The field code (e.g., "HYPERLINK \"url\"")
	display_text string // The display text for the field
}

// HyperlinkField represents a parsed hyperlink field
pub struct HyperlinkField {
pub mut:
	url          string
	display_text string
	start        CP
	end          CP
}

// format_as_markdown formats the hyperlink as markdown [text](url)
pub fn (hf &HyperlinkField) format_as_markdown() string {
	if hf.url.len > 0 && hf.display_text.len > 0 {
		return '[${hf.display_text}](${hf.url})'
	} else if hf.url.len > 0 {
		return '[${hf.url}](${hf.url})'
	}
	return hf.display_text
}

// FieldType represents different field types in Word documents
pub enum FieldType {
	unknown = 0
	hyperlink = 0x13  // HYPERLINK field
	page_ref = 0x25   // PAGEREF field
	ref = 0x03        // REF field
	seq = 0x1A        // SEQ field
	time = 0x20       // TIME field
	date = 0x1F       // DATE field
	filename = 0x08   // FILENAME field
}

// get_field_type_name returns the name of the field type
pub fn get_field_type_name(field_type u8) string {
	match unsafe { FieldType(field_type) } {
		.hyperlink { return 'HYPERLINK' }
		.page_ref { return 'PAGEREF' }
		.ref { return 'REF' }
		.seq { return 'SEQ' }
		.time { return 'TIME' }
		.date { return 'DATE' }
		.filename { return 'FILENAME' }
		else { return 'UNKNOWN' }
	}
}

// FieldPLC represents a field PLC (Piece Location Collection)
pub struct FieldPLC {
	plc ?&PLC
}

// parse_field_plc creates a FieldPLC from raw bytes
pub fn parse_field_plc(data []u8) !FieldPLC {
	// Field PLCs have 2-byte data elements (FLD structure)
	plc := parse_plc(data, 2)!
	
	return FieldPLC{
		plc: &plc
	}
}

// get_fields extracts all fields from the PLC
pub fn (fplc &FieldPLC) get_fields() ![]Field {
	plc_ref := fplc.plc or { return error('no PLC data available') }

	mut fields := []Field{}

	// Fields come in pairs: field start and field end
	mut i := 0
	for i < plc_ref.count() {
		if i + 1 >= plc_ref.count() {
			break
		}

		// Get field start
		if start_cp, _ := plc_ref.get_range(i) {
			start_data := plc_ref.get_data_at(i) or { []u8{} }
			field_type := if start_data.len >= 1 { start_data[0] } else { u8(0) }

			// Get field end  
			if end_cp, _ := plc_ref.get_range(i + 1) {

				field := Field{
					start: start_cp
					end: end_cp
					field_type: field_type
					field_code: ''
					display_text: ''
				}

				fields << field
			}
		}
		i += 2
	}

	return fields
}

// extract_hyperlinks extracts hyperlink fields from text and field data
pub fn extract_hyperlinks(text string, fields []Field) ![]HyperlinkField {
	mut hyperlinks := []HyperlinkField{}

	for field in fields {
		if field.field_type == u8(FieldType.hyperlink) {
			// Extract URL and display text from the field
			hyperlink := parse_hyperlink_field(field, text)!
			hyperlinks << hyperlink
		}
	}

	return hyperlinks
}

// parse_hyperlink_field parses a hyperlink field to extract URL and display text
fn parse_hyperlink_field(field Field, text string) !HyperlinkField {
	// Get the text content of this field range
	start_pos := field.start.to_int()
	end_pos := field.end.to_int()
	
	if start_pos < 0 || end_pos > text.len || start_pos >= end_pos {
		return error('invalid field range')
	}

	field_text := text[start_pos..end_pos]
	
	// Parse HYPERLINK field code
	// Format: HYPERLINK "url" \o "tooltip"
	mut url := ''
	mut display_text := ''

	if field_text.contains('HYPERLINK') {
		// Extract URL from quotes
		parts := field_text.split('"')
		if parts.len >= 2 {
			url = parts[1].trim_space()
		}
		
		// Use remaining text as display text, or URL if no separate display text
		display_text = field_text.replace('HYPERLINK', '').replace('"$url"', '').trim_space()
		if display_text.len == 0 {
			display_text = url
		}
	} else {
		// Simple case: the field text itself might be the URL
		if field_text.starts_with('http') || field_text.contains('@') {
			url = field_text
			display_text = field_text
		}
	}

	return HyperlinkField{
		url: url
		display_text: display_text
		start: field.start
		end: field.end
	}
}

// is_hyperlink_field returns true if the field is a hyperlink field
pub fn (field &Field) is_hyperlink_field() bool {
	return field.field_type == u8(FieldType.hyperlink)
}

// get_field_type_enum returns the field type as an enum
pub fn (field &Field) get_field_type_enum() FieldType {
	return unsafe { FieldType(field.field_type) }
}

// str returns a string representation of the field
pub fn (field &Field) str() string {
	return 'Field{${get_field_type_name(field.field_type)}, ${field.start}-${field.end}}'
}

// FieldCollection manages a collection of fields in a document
pub struct FieldCollection {
mut:
	fields []Field
}

// new_field_collection creates a new field collection
pub fn new_field_collection() FieldCollection {
	return FieldCollection{
		fields: []Field{}
	}
}

// add_field adds a field to the collection
pub fn (mut fc FieldCollection) add_field(field Field) {
	fc.fields << field
}

// get_hyperlinks returns all hyperlink fields
pub fn (fc &FieldCollection) get_hyperlinks() []Field {
	mut hyperlinks := []Field{}
	for field in fc.fields {
		if field.is_hyperlink_field() {
			hyperlinks << field
		}
	}
	return hyperlinks
}

// get_fields_by_type returns all fields of a specific type
pub fn (fc &FieldCollection) get_fields_by_type(field_type FieldType) []Field {
	mut result := []Field{}
	for field in fc.fields {
		if field.get_field_type_enum() == field_type {
			result << field
		}
	}
	return result
}

// count returns the total number of fields
pub fn (fc &FieldCollection) count() int {
	return fc.fields.len
}