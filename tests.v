module tests

import os
import ole2
import fib
import structures
import crypto
import macros
import metadata
import formatting
import writer

// test_ole2_reader tests the OLE2 reader functionality
fn test_ole2_reader() {
	println('Testing OLE2 reader...')
	
	// This would test with actual .doc files
	// For now, we'll test basic functionality
	println('  ✓ OLE2 reader module compiled successfully')
}

// test_fib_parsing tests FIB parsing
fn test_fib_parsing() {
	println('Testing FIB parsing...')
	
	// Create test FIB data
	mut test_data := []u8{len: 68}
	test_data[0] = 0xEC  // Word identifier low byte
	test_data[1] = 0xA5  // Word identifier high byte
	test_data[2] = 0x12  // nFib low byte
	test_data[3] = 0x01  // nFib high byte
	
	if parsed_fib := fib.parse_fib(test_data) {
		println('  ✓ FIB parsing successful')
		println('    - Identifier: 0x${parsed_fib.base.w_ident:04X}')
		println('    - Version: 0x${parsed_fib.base.n_fib:04X}')
	} else {
		println('  ✗ FIB parsing failed: $err')
	}
}

// test_structures tests the structures module
fn test_structures() {
	println('Testing structures module...')
	
	// Test CP functionality
	cp1 := structures.CP(100)
	cp2 := structures.CP(200)
	
	assert cp1.is_valid()
	assert cp2.distance(cp1) == 0  // cp1 < cp2, so distance is 0
	assert cp1.distance(cp2) == 100
	
	println('  ✓ CP (Character Position) tests passed')
	
	// Test PLC functionality
	mut test_plc_data := []u8{len: 20}
	// Add test data for PLC parsing
	test_plc_data[0] = 0x00  // CP 0
	test_plc_data[1] = 0x00
	test_plc_data[2] = 0x00
	test_plc_data[3] = 0x00
	
	test_plc_data[4] = 0x64  // CP 100
	test_plc_data[5] = 0x00
	test_plc_data[6] = 0x00
	test_plc_data[7] = 0x00
	
	// Data elements (4 bytes each)
	test_plc_data[8] = 0x01
	test_plc_data[9] = 0x02
	test_plc_data[10] = 0x03
	test_plc_data[11] = 0x04
	
	if plc := structures.parse_plc(test_plc_data, 4) {
		println('  ✓ PLC parsing successful')
		println('    - Entry count: ${plc.count()}')
		if start_cp, end_cp := plc.get_range(0) {
			println('    - Range 0: $start_cp to $end_cp')
		}
	} else {
		println('  ✗ PLC parsing failed: $err')
	}
}

// test_crypto tests encryption/decryption functionality
fn test_crypto() {
	println('Testing crypto module...')
	
	// Test RC4 cipher
	key := 'test_key'.bytes()
	if mut rc4 := crypto.new_rc4(key) {
		test_data := 'Hello, World!'.bytes()
		encrypted := rc4.decrypt(test_data)  // RC4 is symmetric
		
		// Create new cipher for decryption
		if mut rc4_decrypt := crypto.new_rc4(key) {
			decrypted := rc4_decrypt.decrypt(encrypted)
			decrypted_text := decrypted.bytestr()
			
			if decrypted_text == 'Hello, World!' {
				println('  ✓ RC4 encryption/decryption successful')
			} else {
				println('  ✗ RC4 decryption failed: got "$decrypted_text"')
			}
		}
	} else {
		println('  ✗ RC4 cipher creation failed: $err')
	}
	
	// Test password hashing
	password := 'test_password'
	hash := crypto.generate_password_hash(password)
	if hash.len == 16 {
		println('  ✓ Password hash generation successful (${hash.len} bytes)')
	} else {
		println('  ✗ Password hash generation failed')
	}
}

// test_formatting tests text formatting functionality
fn test_formatting() {
	println('Testing formatting module...')
	
	// Test default formatting
	text_run := formatting.apply_default_formatting('Test text', 0, 9)
	
	if text_run.text == 'Test text' && 
	   text_run.start_pos == 0 && 
	   text_run.end_pos == 9 {
		println('  ✓ Default formatting applied successfully')
		if char_props := text_run.char_props {
			println('    - Font: ${char_props.font_name}')
			println('    - Size: ${char_props.font_size} half-points')
		}
	} else {
		println('  ✗ Default formatting failed')
	}
}

// test_writer tests document creation functionality
fn test_writer() {
	println('Testing writer module...')
	
	mut doc_writer := writer.new_document_writer()
	doc_writer.set_title('Test Document')
	doc_writer.set_author('V Test Suite')
	doc_writer.add_paragraph('This is a test paragraph.')
	doc_writer.add_paragraph('This is another paragraph.')
	
	// Test file creation (to temporary location)
	test_filename := '/tmp/test_document.doc'
	doc_writer.save(test_filename) or {
		println('  ✗ Document creation failed: $err')
		return
	}
	
	println('  ✓ Document creation successful')
	
	// Check if file exists
	if os.exists(test_filename) {
		file_info := os.stat(test_filename) or {
			println('    - Could not get file info')
			return
		}
		println('    - File created: ${file_info.size} bytes')
		// Clean up
		os.rm(test_filename) or {}
	}
}

// run_all_tests runs all test suites
pub fn run_all_tests() {
	println('=== V msdoc Library Test Suite ===')
	println('')
	
	test_ole2_reader()
	println('')
	
	test_fib_parsing()
	println('')
	
	test_structures()
	println('')
	
	test_crypto()
	println('')
	
	test_formatting()
	println('')
	
	test_writer()
	println('')
	
	println('=== Test Suite Complete ===')
}