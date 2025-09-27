module main

import os
import ole2
import fib

// Document represents a loaded Microsoft Word .doc file.
pub struct Document {
mut:
	filename string
	reader   &ole2.Reader
	fib_data &fib.FileInformationBlock
}

// open reads and parses the given .doc file.
pub fn open(filename string) !&Document {
	reader := ole2.new_reader(filename)!
	
	// Read the WordDocument stream to get the FIB
	word_doc_data := reader.read_stream('WordDocument')!
	
	fib_data := fib.parse_fib(word_doc_data)!
	
	return &Document{
		filename: filename
		reader: &reader
		fib_data: &fib_data
	}
}

// is_encrypted returns true if the document is encrypted.
pub fn (d &Document) is_encrypted() bool {
	return d.fib_data.is_encrypted()
}

// has_macros returns true if the document contains VBA macros.
pub fn (d &Document) has_macros() bool {
	return d.fib_data.has_macros()
}

// get_text_length returns the length of the main document text.
pub fn (d &Document) get_text_length() u32 {
	return d.fib_data.get_text_length()
}

// list_streams returns all streams in the document (for debugging).
pub fn (d &Document) list_streams() []string {
	return d.reader.list_streams()
}

// Basic text extraction (simplified version)
pub fn (d &Document) text() !string {
	// Get text length from FIB
	text_length := d.get_text_length()
	if text_length == 0 {
		return ''
	}
	
	// Read the WordDocument stream again (we already have FIB from it)
	word_doc_data := d.reader.read_stream('WordDocument')!
	
	// The text typically starts after the FIB
	// For a basic implementation, we'll start reading after a reasonable FIB offset
	fib_size := 1472  // Typical FIB size for Word 97+
	
	if word_doc_data.len <= fib_size {
		return error('WordDocument stream too small')
	}
	
	// Try to extract text starting after the FIB
	text_data := word_doc_data[fib_size..]
	
	// Convert to string, handling both ANSI and potential Unicode
	mut text := ''
	mut i := 0
	
	// Limit extraction to reasonable length to avoid reading garbage
	max_chars := 10000
	mut chars_processed := 0
	
	for i < text_data.len && chars_processed < max_chars {
		if i + 1 < text_data.len {
			// Try to handle Unicode (UTF-16)
			low_byte := text_data[i]
			high_byte := text_data[i + 1]
			
			if high_byte == 0 && low_byte > 0 {
				// Likely ANSI/ASCII character
				if low_byte >= 32 && low_byte < 127 {
					text += low_byte.ascii_str()
				} else if low_byte == 13 {
					text += '\n'
				} else if low_byte == 10 {
					// Skip LF if we already handled CR
				} else if low_byte == 9 {
					text += '\t'
				}
				i += 2
				chars_processed++
			} else if low_byte == 0 && high_byte == 0 {
				// Double null - might be end of text
				break
			} else {
				// Skip unknown bytes
				i++
			}
		} else {
			// Single byte left
			if text_data[i] >= 32 && text_data[i] < 127 {
				text += text_data[i].ascii_str()
			}
			i++
			chars_processed++
		}
	}
	
	if text.len == 0 {
		return error('no readable text found')
	}
	
	return text.trim_space()
}

fn main() {
	if os.args.len < 2 {
		println('Usage: msdoc <filename.doc>')
		return
	}
	
	filename := os.args[1]
	
	doc := open(filename) or {
		eprintln('Error opening document: $err')
		return
	}
	
	println('Document: $filename')
	println('Encrypted: ${doc.is_encrypted()}')
	println('Has macros: ${doc.has_macros()}')
	println('Text length: ${doc.get_text_length()}')
	
	println('Streams:')
	streams := doc.list_streams()
	for stream in streams {
		println('  $stream')
	}
	
	if streams.len == 0 {
		println('  No streams found!')
	}
	
	text := doc.text() or {
		eprintln('Error reading text: $err')
		return
	}
	
	println('\nText content:')
	if text.len > 200 {
		println('${text[..200]}...')
	} else {
		println(text)
	}
}