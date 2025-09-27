module macros

import compress.zlib
import ole2

// ModuleType represents the type of VBA module.
pub enum ModuleType {
	standard  // Standard code module
	class     // Class module
	form      // UserForm module
	document  // Document module (ThisDocument)
}

// string representation of module type
pub fn (mt ModuleType) str() string {
	match mt {
		.standard { return 'Standard' }
		.class { return 'Class' }
		.form { return 'Form' }
		.document { return 'Document' }
	}
}

// Module represents a VBA module (code module, class module, or form).
pub struct Module {
pub mut:
	name        string     // Module name
	module_type ModuleType // Module type
	code        string     // VBA source code
	compressed  bool       // True if code is compressed
	stream_name string     // Storage stream name
	offset      u32        // Offset within stream
	size        u32        // Uncompressed size
}

// Reference represents an external reference used by the VBA project.
pub struct Reference {
pub mut:
	name        string // Reference name
	description string // Reference description
	guid        string // Reference GUID
	version     string // Reference version
	path        string // Reference file path
}

// VBAProject represents a VBA project contained in the document.
pub struct VBAProject {
pub mut:
	name        string                // Project name
	description string                // Project description
	help_file   string                // Help file path
	modules     map[string]&Module    // VBA modules by name
	references  []&Reference          // External references
	protected   bool                  // True if project is protected
	password    string                // Project password (if known)
}

// get_module_code returns the VBA code for a specific module.
pub fn (project &VBAProject) get_module_code(module_name string) (string, bool) {
	if module_name in project.modules {
		return project.modules[module_name].code, true
	}
	return '', false
}

// get_all_module_names returns the names of all modules in the project.
pub fn (project &VBAProject) get_all_module_names() []string {
	return project.modules.keys()
}

// has_macro_functions checks if any module contains macro functions.
pub fn (project &VBAProject) has_macro_functions() bool {
	for _, mod in project.modules {
		if mod.code.contains('Sub ') || mod.code.contains('Function ') {
			return true
		}
	}
	return false
}

// get_modules_by_type returns all modules of the specified type.
pub fn (project &VBAProject) get_modules_by_type(module_type ModuleType) []&Module {
	mut modules := []&Module{}
	for _, mod in project.modules {
		if mod.module_type == module_type {
			modules << mod
		}
	}
	return modules
}

// MacroExtractor handles extraction of VBA macros from .doc files.
pub struct MacroExtractor {
mut:
	reader &ole2.Reader
}

// new_macro_extractor creates a new macro extractor for the given OLE2 reader.
pub fn new_macro_extractor(reader &ole2.Reader) MacroExtractor {
	return MacroExtractor{
		reader: reader
	}
}

// has_macros checks if the document contains VBA macros.
pub fn (me &MacroExtractor) has_macros() bool {
	// Check for Macros storage
	if _ := me.reader.read_stream('Macros') {
		return true
	}

	// Check for VBA storage (alternative location)
	if _ := me.reader.read_stream('_VBA_PROJECT') {
		return true
	}

	return false
}

// extract_project extracts the complete VBA project from the document.
pub fn (me &MacroExtractor) extract_project() !VBAProject {
	if !me.has_macros() {
		return error('document does not contain VBA macros')
	}

	mut project := VBAProject{
		modules: map[string]&Module{}
		references: []
	}

	// Try to read project information
	me.parse_project_info(mut project)!

	// Extract modules
	me.extract_modules(mut project)!

	return project
}

// parse_project_info parses the project-level information.
fn (me &MacroExtractor) parse_project_info(mut project VBAProject) ! {
	// Try to read the dir stream containing project metadata
	if dir_data := me.reader.read_stream('dir') {
		me.parse_dir_stream(mut project, dir_data)!
	}
}

// parse_dir_stream parses the dir stream containing project metadata.
fn (me &MacroExtractor) parse_dir_stream(mut project VBAProject, data []u8) ! {
	// This is a simplified implementation
	// The actual dir stream format is quite complex with various record types
	// For now, we'll extract basic project information
	
	// Read null-terminated strings for project info
	mut offset := 0
	
	// Skip initial records to find project info
	// This would need proper parsing of the dir stream format
	
	if data.len > 100 {
		// Extract project name (simplified)
		project.name = 'VBAProject'
		project.description = 'Microsoft Office Word VBA Project'
	}
}

// extract_modules extracts individual VBA modules.
fn (me &MacroExtractor) extract_modules(mut project VBAProject) ! {
	// Try to read common module streams
	module_names := ['ThisDocument', 'Module1', 'NewMacros']
	
	for module_name in module_names {
		if module_data := me.reader.read_stream(module_name) {
			mod := me.parse_module_data(module_name, module_data)!
			project.modules[module_name] = &mod
		}
	}
}

// parse_module_data parses VBA module data from a stream.
fn (me &MacroExtractor) parse_module_data(module_name string, data []u8) !Module {
	mut mod := Module{
		name: module_name
		module_type: .standard
		code: ''
		compressed: false
		stream_name: module_name
		offset: 0
		size: u32(data.len)
	}

	// Try to extract VBA source code
	// This is simplified - actual VBA modules may be compressed
	if data.len > 0 {
		// Check if data looks like compressed VBA
		if data[0] == 0x01 {
			// Compressed VBA code
			mod.compressed = true
			if decompressed := me.decompress_vba(data) {
				mod.code = decompressed
			}
		} else {
			// Try to extract as plain text
			mod.code = me.extract_text_from_data(data)
		}
	}

	// Determine module type based on name
	if module_name.contains('ThisDocument') {
		mod.module_type = .document
	} else if module_name.starts_with('Class') {
		mod.module_type = .class
	} else if module_name.contains('Form') {
		mod.module_type = .form
	}

	return mod
}

// decompress_vba attempts to decompress VBA code using ZLIB.
fn (me &MacroExtractor) decompress_vba(data []u8) ?string {
	// Skip header bytes and try decompression
	if data.len < 10 {
		return none
	}

	compressed_data := data[8..]  // Skip VBA header
	if decompressed := zlib.decompress(compressed_data) {
		return decompressed.bytestr()
	}
	
	return none
}

// extract_text_from_data extracts readable text from binary data.
fn (me &MacroExtractor) extract_text_from_data(data []u8) string {
	mut text := ''
	
	for b in data {
		if b >= 32 && b < 127 {  // Printable ASCII
			text += b.ascii_str()
		} else if b == 13 || b == 10 {
			text += '\n'
		}
	}
	
	return text.trim_space()
}