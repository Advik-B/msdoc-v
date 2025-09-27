module formatting

import structures

// UnderlineType represents the type of text underline.
pub enum UnderlineType {
	none
	single
	double
	thick
	dotted
	dashed
	dot_dash
	dot_dot_dash
	wave
}

// Color represents a text color.
pub struct Color {
pub mut:
	r u8
	g u8 
	b u8
	a u8  // Alpha channel
}

// CharacterProperties represents character-level formatting.
pub struct CharacterProperties {
pub mut:
	font_name      string        // Font name
	font_size      u16           // Font size in half-points
	bold           bool          // Bold text
	italic         bool          // Italic text
	underline      UnderlineType // Underline type
	strikethrough  bool          // Strikethrough
	color          Color         // Text color
	superscript    bool          // Superscript
	subscript      bool          // Subscript
	small_caps     bool          // Small capitals
	all_caps       bool          // All capitals
	hidden         bool          // Hidden text
}

// ParagraphProperties represents paragraph-level formatting.
pub struct ParagraphProperties {
pub mut:
	alignment         ParagraphAlignment // Text alignment
	left_indent       i32                // Left indent in twips
	right_indent      i32                // Right indent in twips
	first_line_indent i32                // First line indent in twips
	space_before      i32                // Space before paragraph in twips
	space_after       i32                // Space after paragraph in twips
	line_spacing      i32                // Line spacing
	keep_together     bool               // Keep lines together
	keep_with_next    bool               // Keep with next paragraph
	page_break_before bool               // Page break before
}

// ParagraphAlignment represents paragraph alignment options.
pub enum ParagraphAlignment {
	left
	center
	right
	justified
}

// TextRun represents a run of text with consistent formatting.
pub struct TextRun {
pub mut:
	text       string                   // Text content
	start_pos  u32                      // Starting character position
	end_pos    u32                      // Ending character position
	char_props ?&CharacterProperties    // Character formatting
	para_props ?&ParagraphProperties    // Paragraph formatting
}

// FormattingExtractor handles extraction of text formatting from .doc files.
pub struct FormattingExtractor {
mut:
	reader ?&structures.PLC  // Reference to piece table or formatting data
}

// new_formatting_extractor creates a new formatting extractor.
pub fn new_formatting_extractor() FormattingExtractor {
	return FormattingExtractor{}
}

// extract_character_properties extracts character properties from CHPX data.
pub fn (fe &FormattingExtractor) extract_character_properties(data []u8) !CharacterProperties {
	mut props := CharacterProperties{
		font_name: 'Times New Roman'
		font_size: 24  // 12 points = 24 half-points
		color: Color{r: 0, g: 0, b: 0, a: 255}
	}

	if data.len == 0 {
		return props
	}

	// Parse CHPX (Character Properties eXtended) data
	// This is a simplified parser - the actual format is quite complex
	mut i := 0
	for i < data.len {
		if i + 1 >= data.len {
			break
		}

		sprm_code := u16(data[i]) | (u16(data[i+1]) << 8)
		i += 2

		match sprm_code {
			0x0835 { // Bold
				if i < data.len {
					props.bold = data[i] != 0
					i++
				}
			}
			0x0836 { // Italic  
				if i < data.len {
					props.italic = data[i] != 0
					i++
				}
			}
			0x0837 { // Strikethrough
				if i < data.len {
					props.strikethrough = data[i] != 0
					i++
				}
			}
			0x4A30 { // Font size
				if i + 1 < data.len {
					props.font_size = u16(data[i]) | (u16(data[i+1]) << 8)
					i += 2
				}
			}
			else {
				// Skip unknown SPRM
				i++
			}
		}
	}

	return props
}

// extract_paragraph_properties extracts paragraph properties from PAPX data.
pub fn (fe &FormattingExtractor) extract_paragraph_properties(data []u8) !ParagraphProperties {
	mut props := ParagraphProperties{
		alignment: .left
		line_spacing: 240  // Single spacing in twips
	}

	if data.len == 0 {
		return props
	}

	// Parse PAPX (Paragraph Properties eXtended) data
	mut i := 0
	for i < data.len {
		if i + 1 >= data.len {
			break
		}

		sprm_code := u16(data[i]) | (u16(data[i+1]) << 8)
		i += 2

		match sprm_code {
			0x2403 { // Paragraph alignment
				if i < data.len {
					align_val := data[i]
					props.alignment = match align_val {
						0 { ParagraphAlignment.left }
						1 { ParagraphAlignment.center }
						2 { ParagraphAlignment.right }
						3 { ParagraphAlignment.justified }
						else { ParagraphAlignment.left }
					}
					i++
				}
			}
			0x840E { // Left indent
				if i + 3 < data.len {
					props.left_indent = i32(data[i]) | (i32(data[i+1]) << 8) |
					                   (i32(data[i+2]) << 16) | (i32(data[i+3]) << 24)
					i += 4
				}
			}
			0x840F { // Right indent
				if i + 3 < data.len {
					props.right_indent = i32(data[i]) | (i32(data[i+1]) << 8) |
					                    (i32(data[i+2]) << 16) | (i32(data[i+3]) << 24)
					i += 4
				}
			}
			else {
				// Skip unknown SPRM
				i++
			}
		}
	}

	return props
}

// apply_default_formatting applies default formatting to a text run.
pub fn apply_default_formatting(text string, start_pos u32, end_pos u32) TextRun {
	default_char_props := CharacterProperties{
		font_name: 'Times New Roman'
		font_size: 24
		bold: false
		italic: false
		underline: .none
		color: Color{r: 0, g: 0, b: 0, a: 255}
	}

	default_para_props := ParagraphProperties{
		alignment: .left
		line_spacing: 240
	}

	return TextRun{
		text: text
		start_pos: start_pos
		end_pos: end_pos
		char_props: &default_char_props
		para_props: &default_para_props
	}
}