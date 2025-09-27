module objects

import ole2

// ObjectType represents the type of embedded object.
pub enum ObjectType {
	unknown
	ole      // OLE object (Excel sheet, PowerPoint, etc.)
	image    // Image (BMP, PNG, JPEG, etc.)
	chart    // Chart or graph
	equation // Mathematical equation
	drawing  // Drawing or shape
}

// string representation of object type
pub fn (ot ObjectType) str() string {
	match ot {
		.unknown { return 'Unknown' }
		.ole { return 'OLE' }
		.image { return 'Image' }
		.chart { return 'Chart' }
		.equation { return 'Equation' }
		.drawing { return 'Drawing' }
	}
}

// EmbeddedObject represents an object embedded in the document.
pub struct EmbeddedObject {
pub mut:
	object_type ObjectType // Type of the embedded object
	name        string     // Object name or description
	class_name  string     // OLE class name (for OLE objects)
	data        []u8       // Raw object data
	icon_data   []u8       // Icon representation data
	size        i64        // Size of the object data
	position    u32        // Position in document where object is referenced
	is_linked   bool       // True if object is linked rather than embedded
	link_path   string     // Path to linked file (if applicable)
}

// get_object_info returns a descriptive string about the object
pub fn (obj &EmbeddedObject) get_object_info() string {
	mut info := '${obj.object_type} object'
	if obj.name.len > 0 {
		info += ': ${obj.name}'
	}
	if obj.class_name.len > 0 {
		info += ' (${obj.class_name})'
	}
	info += ', size: ${obj.size} bytes'
	if obj.is_linked {
		info += ', linked to: ${obj.link_path}'
	}
	return info
}

// ObjectPool manages embedded objects within a .doc file.
pub struct ObjectPool {
mut:
	reader  &ole2.Reader
	objects map[u32]&EmbeddedObject
	loaded  bool
}

// new_object_pool creates a new ObjectPool for the given OLE2 reader.
pub fn new_object_pool(reader &ole2.Reader) ObjectPool {
	return ObjectPool{
		reader: unsafe { reader }
		objects: map[u32]&EmbeddedObject{}
		loaded: false
	}
}

// load_objects loads all embedded objects from the document.
pub fn (mut pool ObjectPool) load_objects() ! {
	if pool.loaded {
		return
	}

	// Try to read the ObjectPool stream
	if object_data := pool.reader.read_stream('ObjectPool') {
		pool.parse_object_pool(object_data)!
	}

	// Try to read individual object streams
	streams := pool.reader.list_streams()
	for stream_name in streams {
		if stream_name.starts_with('Ole') {
			if ole_data := pool.reader.read_stream(stream_name) {
				pool.parse_ole_object(stream_name, ole_data)!
			}
		}
	}

	pool.loaded = true
}

// get_all_objects returns all embedded objects in the document.
pub fn (pool &ObjectPool) get_all_objects() map[u32]&EmbeddedObject {
	return pool.objects
}

// extract_object returns a specific embedded object by position.
pub fn (mut pool ObjectPool) extract_object(position u32) !&EmbeddedObject {
	pool.load_objects()!
	
	if obj := pool.objects[position] {
		return obj
	}
	
	return error('object at position $position not found')
}

// parse_object_pool parses the ObjectPool stream containing object metadata.
fn (mut pool ObjectPool) parse_object_pool(data []u8) ! {
	// Basic ObjectPool parsing - simplified implementation
	if data.len < 16 {
		return error('objectpool: data too short')
	}

	mut offset := 0
	for offset + 16 <= data.len {
		// Read object entry (simplified structure)
		position := u32(data[offset]) | (u32(data[offset + 1]) << 8) | 
				   (u32(data[offset + 2]) << 16) | (u32(data[offset + 3]) << 24)
		
		size := i64(data[offset + 4]) | (i64(data[offset + 5]) << 8) | 
			   (i64(data[offset + 6]) << 16) | (i64(data[offset + 7]) << 24)

		if position > 0 {
			obj := &EmbeddedObject{
				object_type: .unknown
				name: 'Object_$position'
				class_name: ''
				data: []
				icon_data: []
				size: size
				position: position
				is_linked: false
				link_path: ''
			}
			
			pool.objects[position] = obj
		}

		offset += 16
		if offset >= data.len {
			break
		}
	}
}

// parse_ole_object parses an individual OLE object stream.
fn (mut pool ObjectPool) parse_ole_object(stream_name string, data []u8) ! {
	if data.len < 32 {
		return error('ole object: data too short')
	}

	// Extract position from stream name (e.g., "Ole10Native" -> position 10)
	mut position := u32(0)
	if stream_name.len > 3 {
		// Try to extract number from stream name
		num_part := stream_name[3..].replace('Native', '')
		position = num_part.u32()
	}

	// Determine object type based on data signature
	mut obj_type := ObjectType.unknown
	if data.len >= 4 {
		signature := u32(data[0]) | (u32(data[1]) << 8) | (u32(data[2]) << 16) | (u32(data[3]) << 24)
		match signature {
			0x0000001C { obj_type = .ole }     // OLE object signature
			0x424D0000 { obj_type = .image }   // BMP signature
			0x89504E47 { obj_type = .image }   // PNG signature
			0xFFD8FFE0 { obj_type = .image }   // JPEG signature
			else { obj_type = .unknown }
		}
	}

	// Create embedded object
	obj := &EmbeddedObject{
		object_type: obj_type
		name: stream_name
		class_name: pool.extract_class_name(data)
		data: data.clone()
		icon_data: []
		size: i64(data.len)
		position: position
		is_linked: false
		link_path: ''
	}

	pool.objects[position] = obj
}

// extract_class_name attempts to extract the OLE class name from object data.
fn (pool &ObjectPool) extract_class_name(data []u8) string {
	// Simplified class name extraction
	if data.len < 32 {
		return ''
	}

	// Look for common OLE class names in the data
	data_str := data.bytestr()
	if data_str.contains('Excel.Sheet') {
		return 'Excel.Sheet'
	} else if data_str.contains('PowerPoint') {
		return 'PowerPoint.Slide'
	} else if data_str.contains('Word.Document') {
		return 'Word.Document'
	} else if data_str.contains('Package') {
		return 'Package'
	}

	return ''
}

// has_objects returns true if the document contains embedded objects.
pub fn (mut pool ObjectPool) has_objects() bool {
	pool.load_objects() or { return false }
	return pool.objects.len > 0
}

// get_object_count returns the number of embedded objects.
pub fn (pool &ObjectPool) get_object_count() int {
	return pool.objects.len
}

// get_objects_by_type returns all objects of the specified type.
pub fn (pool &ObjectPool) get_objects_by_type(obj_type ObjectType) []&EmbeddedObject {
	mut result := []&EmbeddedObject{}
	for _, obj in pool.objects {
		if obj.object_type == obj_type {
			result << obj
		}
	}
	return result
}