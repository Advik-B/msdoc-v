module writer

import os
import time
import ole2
import fib
import formatting

// DocumentWriter provides functionality for creating new .doc files.
pub struct DocumentWriter {
mut:
	title       string
	author      string
	subject     string
	keywords    string
	comments    string
	text_buffer string
	paragraphs  []string
	formatting_runs []formatting.TextRun
	created     time.Time
	modified    time.Time
}

// new_document_writer creates a new document writer.
pub fn new_document_writer() DocumentWriter {
	now := time.now()
	return DocumentWriter{
		created: now
		modified: now
		text_buffer: ''
		paragraphs: []
		formatting_runs: []
	}
}

// set_title sets the document title.
pub fn (mut dw DocumentWriter) set_title(title string) {
	dw.title = title
	dw.modified = time.now()
}

// set_author sets the document author.
pub fn (mut dw DocumentWriter) set_author(author string) {
	dw.author = author
	dw.modified = time.now()
}

// set_subject sets the document subject.
pub fn (mut dw DocumentWriter) set_subject(subject string) {
	dw.subject = subject
	dw.modified = time.now()
}

// set_keywords sets the document keywords.
pub fn (mut dw DocumentWriter) set_keywords(keywords string) {
	dw.keywords = keywords
	dw.modified = time.now()
}

// set_comments sets the document comments.
pub fn (mut dw DocumentWriter) set_comments(comments string) {
	dw.comments = comments
	dw.modified = time.now()
}

// add_text adds plain text to the document.
pub fn (mut dw DocumentWriter) add_text(text string) {
	dw.text_buffer += text
	dw.modified = time.now()
}

// add_paragraph adds a new paragraph to the document.
pub fn (mut dw DocumentWriter) add_paragraph(text string) {
	dw.paragraphs << text
	dw.text_buffer += text + '\r'  // Add carriage return for paragraph break
	dw.modified = time.now()
}

// add_formatted_text adds formatted text to the document.
pub fn (mut dw DocumentWriter) add_formatted_text(text string, char_props &formatting.CharacterProperties, para_props &formatting.ParagraphProperties) {
	start_pos := u32(dw.text_buffer.len)
	dw.text_buffer += text
	end_pos := u32(dw.text_buffer.len)
	
	text_run := formatting.TextRun{
		text: text
		start_pos: start_pos
		end_pos: end_pos
		char_props: char_props
		para_props: para_props
	}
	
	dw.formatting_runs << text_run
	dw.modified = time.now()
}

// save saves the document to the specified file.
pub fn (mut dw DocumentWriter) save(filename string) ! {
	// Create the OLE2 compound document structure
	dw.write_ole2_document(filename)!
}

// write_ole2_document writes the complete OLE2 compound document.
fn (mut dw DocumentWriter) write_ole2_document(filename string) ! {
	// This is a simplified implementation
	// A complete implementation would build the full OLE2 structure
	
	// For now, create a basic file with the text content
	mut file := os.create(filename)!
	defer { file.close() }

	// Build minimal document structure
	fib_data := dw.build_minimal_fib()
	word_document := dw.build_word_document_stream()
	
	// Write OLE2 header
	ole2_header := dw.build_ole2_header()
	file.write(ole2_header)!

	// Write WordDocument stream
	file.write(word_document)!

	// Write minimal table stream
	table_stream := dw.build_minimal_table_stream()
	file.write(table_stream)!
}

// build_minimal_fib builds a minimal File Information Block.
fn (dw &DocumentWriter) build_minimal_fib() []u8 {
	mut fib_data := []u8{len: 1472} // Standard FIB size

	// Set basic FIB fields
	// Word identifier
	fib_data[0] = 0xEC
	fib_data[1] = 0xA5
	
	// FIB version (Word 2003)
	fib_data[2] = 0x12
	fib_data[3] = 0x01

	// Text length
	text_len := u32(dw.text_buffer.len)
	fib_data[44] = u8(text_len)
	fib_data[45] = u8(text_len >> 8)
	fib_data[46] = u8(text_len >> 16)
	fib_data[47] = u8(text_len >> 24)

	return fib_data
}

// build_word_document_stream builds the WordDocument stream.
fn (dw &DocumentWriter) build_word_document_stream() []u8 {
	mut stream := []u8{}
	
	// Add FIB
	fib_data := dw.build_minimal_fib()
	stream << fib_data

	// Add text content (simplified - should use piece table)
	text_bytes := dw.text_buffer.bytes()
	stream << text_bytes

	return stream
}

// build_minimal_table_stream builds a minimal table stream.
fn (dw &DocumentWriter) build_minimal_table_stream() []u8 {
	mut stream := []u8{}
	
	// Add minimal piece table (CLX)
	// This is highly simplified - real piece tables are complex
	clx_data := dw.build_minimal_clx()
	stream << clx_data

	return stream
}

// build_minimal_clx builds a minimal CLX (piece table) structure.
fn (dw &DocumentWriter) build_minimal_clx() []u8 {
	mut clx := []u8{}
	
	// CLX header
	clx << [u8(0x02), 0x00]  // clxt = 2 (piece table)
	
	// Text length
	text_len := u32(dw.text_buffer.len)
	clx << u8(text_len)
	clx << u8(text_len >> 8) 
	clx << u8(text_len >> 16)
	clx << u8(text_len >> 24)

	// Minimal piece descriptor
	// CP start (0)
	clx << [u8(0x00), 0x00, 0x00, 0x00]
	// CP end (text length)
	clx << u8(text_len)
	clx << u8(text_len >> 8)
	clx << u8(text_len >> 16) 
	clx << u8(text_len >> 24)

	// PCD (Piece Descriptor)
	clx << [u8(0x00), 0x00]  // flags
	clx << [u8(0x00), 0x00, 0x00, 0x00]  // fc (file character position)
	clx << [u8(0x00), 0x00]  // prm (formatting info)

	return clx
}

// build_ole2_header builds a minimal OLE2 compound document header.
fn (dw &DocumentWriter) build_ole2_header() []u8 {
	mut header := []u8{len: 512}

	// OLE2 signature
	ole2_sig := [u8(0xD0), 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1]
	for i, b in ole2_sig {
		header[i] = b
	}

	// Minor version
	header[24] = 0x3E
	header[25] = 0x00

	// Major version  
	header[26] = 0x03
	header[27] = 0x00

	// Byte order
	header[28] = 0xFE
	header[29] = 0xFF

	// Sector size (512 bytes = 2^9)
	header[30] = 0x09
	header[31] = 0x00

	// Directory sectors count (1)
	header[44] = 0x01
	header[48] = 0x00

	// First directory sector (sector 1)
	header[48] = 0x01
	
	// Fill remaining with appropriate values for minimal document
	// This is highly simplified - a complete implementation would
	// build proper FAT, DIFAT, and directory structures

	return header
}