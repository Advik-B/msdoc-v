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
	// For now, return a basic implementation
	// In a full implementation, this would parse the piece table and extract formatted text
	text_length := d.get_text_length()
	if text_length == 0 {
		return ''
	}
	
	// Try to read the Data stream which might contain text
	if data_stream := d.reader.read_stream('Data') {
		// Convert bytes to string (simplified)
		mut text := ''
		for b in data_stream {
			if b >= 32 && b < 127 {  // ASCII printable characters
				text += b.ascii_str()
			} else if b == 13 || b == 10 {  // CR/LF
				text += '\n'
			}
		}
		return text
	} else {
		return error('failed to read document text')
	}
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
	for stream in doc.list_streams() {
		println('  $stream')
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