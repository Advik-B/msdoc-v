module ole2

import os

const header_signature = u64(0xE11AB1A1E011CFD0)
const sector_size = 512
const dir_entry_size = 128

// Reader provides access to streams within an OLE2 compound file.
pub struct Reader {
mut:
	filename    string
	fat        []u32
	dir_entries []DirEntry
}

pub struct DirEntry {
pub:
	name            [32]u16
	name_len        u16
	object_type     u8
	color_flag      u8
	left_sibling    i32
	right_sibling   i32
	child_id        i32
	clsid           [16]u8
	state_bits      u32
	creation_time   u64
	modified_time   u64
	starting_sector i32
	stream_size     u64
}

// read_at reads bytes from a file at a specific position
fn read_at(filename string, offset u64, size int) ![]u8 {
	mut f := os.open(filename)!
	defer { f.close() }
	
	// Simple implementation: read entire file and extract portion
	// This is not optimal but works for now
	all_data := os.read_bytes(filename)!
	if offset + u64(size) > u64(all_data.len) {
		return error('read_at: trying to read beyond file end')
	}
	
	return all_data[int(offset)..int(offset) + size]
}

// new_reader initializes an OLE2 reader from a file.
pub fn new_reader(filename string) !&Reader {
	// Read the header
	header_bytes := read_at(filename, 0, 76)!
	
	// Parse signature
	signature := u64(header_bytes[0]) | (u64(header_bytes[1]) << 8) | 
	            (u64(header_bytes[2]) << 16) | (u64(header_bytes[3]) << 24) |
	            (u64(header_bytes[4]) << 32) | (u64(header_bytes[5]) << 40) |
	            (u64(header_bytes[6]) << 48) | (u64(header_bytes[7]) << 56)
	
	if signature != header_signature {
		return error('ole2: invalid signature')
	}
	
	// Parse directory start sector (offset 48-52)
	dir_start_sector := i32(header_bytes[48]) | (i32(header_bytes[49]) << 8) |
	                   (i32(header_bytes[50]) << 16) | (i32(header_bytes[51]) << 24)
	
	// Parse FAT sectors count and DIFAT sectors count
	fat_sector_count := u32(header_bytes[44]) | (u32(header_bytes[45]) << 8) |
	                   (u32(header_bytes[46]) << 16) | (u32(header_bytes[47]) << 24)
	
	// Read DIFAT
	difat_bytes := read_at(filename, 76, 436)!
	
	mut fat_sector_numbers := []i32{}
	
	// Read first 109 FAT sector numbers from header DIFAT
	for i in 0..109 {
		if fat_sector_numbers.len >= int(fat_sector_count) {
			break
		}
		offset := i * 4
		if offset + 3 < difat_bytes.len {
			sector_num := i32(difat_bytes[offset]) | (i32(difat_bytes[offset+1]) << 8) |
			             (i32(difat_bytes[offset+2]) << 16) | (i32(difat_bytes[offset+3]) << 24)
			if sector_num != -1 {
				fat_sector_numbers << sector_num
			}
		}
	}
	
	// Read FAT
	mut fat := []u32{}
	for sector_num in fat_sector_numbers {
		sector_offset := u64(sector_num + 1) * sector_size
		sector_data := read_at(filename, sector_offset, sector_size) or { continue }
		
		for i := 0; i < sector_size; i += 4 {
			if i + 3 < sector_data.len {
				fat_entry := u32(sector_data[i]) | (u32(sector_data[i+1]) << 8) |
				            (u32(sector_data[i+2]) << 16) | (u32(sector_data[i+3]) << 24)
				fat << fat_entry
			}
		}
	}
	
	// Read directory entries
	mut dir_entries := []DirEntry{}
	mut current_sector := dir_start_sector
	
	for current_sector >= 0 && current_sector != 0xFFFFFFFE {
		sector_offset := u64(current_sector + 1) * sector_size
		sector_data := read_at(filename, sector_offset, sector_size) or { break }
		
		// Parse directory entries in this sector
		for entry_offset := 0; entry_offset < sector_size; entry_offset += dir_entry_size {
			if entry_offset + dir_entry_size > sector_data.len {
				break
			}
			
			entry_data := sector_data[entry_offset..entry_offset + dir_entry_size]
			dir_entry := parse_dir_entry(entry_data)!
			dir_entries << dir_entry
		}
		
		// Move to next directory sector
		if current_sector >= 0 && current_sector < fat.len {
			current_sector = i32(fat[current_sector])
			if current_sector == 0xFFFFFFFE || current_sector == 0xFFFFFFFF {
				break
			}
		} else {
			break
		}
	}
	
	return &Reader{
		filename: filename
		fat: fat
		dir_entries: dir_entries
	}
}

fn parse_dir_entry(data []u8) !DirEntry {
	if data.len < dir_entry_size {
		return error('ole2: directory entry data too short')
	}
	
	mut name := [32]u16{}
	for i in 0..32 {
		if i * 2 + 1 < data.len {
			name[i] = u16(data[i*2]) | (u16(data[i*2+1]) << 8)
		}
	}
	
	name_len := u16(data[64]) | (u16(data[65]) << 8)
	object_type := data[66]
	color_flag := data[67]
	left_sibling := i32(data[68]) | (i32(data[69]) << 8) | (i32(data[70]) << 16) | (i32(data[71]) << 24)
	right_sibling := i32(data[72]) | (i32(data[73]) << 8) | (i32(data[74]) << 16) | (i32(data[75]) << 24)
	child_id := i32(data[76]) | (i32(data[77]) << 8) | (i32(data[78]) << 16) | (i32(data[79]) << 24)
	
	mut clsid := [16]u8{}
	for i in 0..16 {
		clsid[i] = data[80 + i]
	}
	
	state_bits := u32(data[96]) | (u32(data[97]) << 8) | (u32(data[98]) << 16) | (u32(data[99]) << 24)
	creation_time := u64(data[100]) | (u64(data[101]) << 8) | (u64(data[102]) << 16) | (u64(data[103]) << 24) |
	                (u64(data[104]) << 32) | (u64(data[105]) << 40) | (u64(data[106]) << 48) | (u64(data[107]) << 56)
	modified_time := u64(data[108]) | (u64(data[109]) << 8) | (u64(data[110]) << 16) | (u64(data[111]) << 24) |
	                (u64(data[112]) << 32) | (u64(data[113]) << 40) | (u64(data[114]) << 48) | (u64(data[115]) << 56)
	starting_sector := i32(data[116]) | (i32(data[117]) << 8) | (i32(data[118]) << 16) | (i32(data[119]) << 24)
	stream_size := u64(data[120]) | (u64(data[121]) << 8) | (u64(data[122]) << 16) | (u64(data[123]) << 24) |
	              (u64(data[124]) << 32) | (u64(data[125]) << 40) | (u64(data[126]) << 48) | (u64(data[127]) << 56)
	
	return DirEntry{
		name: name
		name_len: name_len
		object_type: object_type
		color_flag: color_flag
		left_sibling: left_sibling
		right_sibling: right_sibling
		child_id: child_id
		clsid: clsid
		state_bits: state_bits
		creation_time: creation_time
		modified_time: modified_time
		starting_sector: starting_sector
		stream_size: stream_size
	}
}

// utf16_name_to_string converts UTF-16 directory entry name to string
fn utf16_name_to_string(name [32]u16, name_len u16) string {
	if name_len == 0 || name_len > 64 {
		return ''
	}
	
	// Convert UTF-16 to string
	mut result := ''
	char_count := (name_len - 2) / 2  // Subtract 2 for null terminator, divide by 2 for UTF-16
	
	for i := 0; i < int(char_count) && i < 32; i++ {
		if name[i] != 0 {
			if name[i] < 128 {  // ASCII range
				result += u8(name[i]).ascii_str()
			}
		}
	}
	
	return result
}

// list_streams returns the names of all streams in the OLE2 file
pub fn (r &Reader) list_streams() []string {
	mut streams := []string{}
	
	for entry in r.dir_entries {
		if entry.object_type == 2 {  // Stream object type
			stream_name := utf16_name_to_string(entry.name, entry.name_len)
			if stream_name.len > 0 {
				streams << stream_name
			}
		}
	}
	
	return streams
}

// read_stream finds a stream by name and returns its content
pub fn (r &Reader) read_stream(name string) ![]u8 {
	// Find the directory entry for this stream
	mut target_entry := DirEntry{}
	mut found := false
	
	for entry in r.dir_entries {
		if entry.object_type == 2 {  // Stream object type
			stream_name := utf16_name_to_string(entry.name, entry.name_len)
			if stream_name == name {
				target_entry = entry
				found = true
				break
			}
		}
	}
	
	if !found {
		return error("ole2: stream '$name' not found")
	}
	
	// Read the stream data
	mut stream_data := []u8{}
	mut current_sector := target_entry.starting_sector
	mut bytes_left := target_entry.stream_size
	
	for current_sector >= 0 && current_sector != 0xFFFFFFFE && bytes_left > 0 {
		sector_offset := u64(current_sector + 1) * sector_size
		mut bytes_to_read := sector_size
		if bytes_left < u64(sector_size) {
			bytes_to_read = int(bytes_left)
		}
		
		sector_data := read_at(r.filename, sector_offset, bytes_to_read) or { break }
		stream_data << sector_data
		
		bytes_left -= u64(bytes_to_read)
		
		// Move to next sector
		if current_sector >= 0 && current_sector < r.fat.len {
			current_sector = i32(r.fat[current_sector])
			if current_sector == 0xFFFFFFFE || current_sector == 0xFFFFFFFF {
				break
			}
		} else {
			break
		}
	}
	
	if stream_data.len > int(target_entry.stream_size) {
		return stream_data[..int(target_entry.stream_size)]
	}
	
	return stream_data
}