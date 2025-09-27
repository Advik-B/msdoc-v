module structures

// PLC (Plex) is a common structure in .doc files. It is an array of
// Character Positions (CPs) followed by an array of data elements.
// The number of CPs is always one more than the number of data elements.
pub struct PLC {
pub mut:
	cps       []CP     // Character positions
	data      [][]u8   // Generic representation of data elements  
	data_size int      // Size of each data element in bytes
}

// parse_plc parses a PLC structure from raw bytes.
// data_size specifies the size of each data element in bytes.
pub fn parse_plc(data []u8, data_size int) !PLC {
	if data.len < 4 {
		return error('plc: data too short, need at least 4 bytes')
	}

	if data_size <= 0 {
		return error('plc: invalid data size $data_size')
	}

	// Calculate number of data elements
	// Formula: n = (cbPlc - 4) / (data_size + 4)
	// where cbPlc is the total PLC size, data_size is size of each data element,
	// and 4 is the size of each CP (32-bit integer)
	if (data.len - 4) % (data_size + 4) != 0 {
		return error('plc: invalid PLC size ${data.len} for data element size $data_size')
	}

	num_data_elements := (data.len - 4) / (data_size + 4)
	num_cps := num_data_elements + 1

	// Parse CPs
	mut cps := []CP{len: num_cps}
	for i in 0 .. num_cps {
		offset := i * 4
		if offset + 4 > data.len {
			return error('plc: not enough data for CP $i')
		}
		cps[i] = CP(u32(data[offset]) | (u32(data[offset+1]) << 8) | 
		           (u32(data[offset+2]) << 16) | (u32(data[offset+3]) << 24))
	}

	// Parse data elements
	mut data_elements := [][]u8{len: num_data_elements}
	data_offset := num_cps * 4
	for i in 0 .. num_data_elements {
		offset := data_offset + (i * data_size)
		if offset + data_size > data.len {
			return error('plc: not enough data for element $i')
		}
		data_elements[i] = data[offset..offset + data_size].clone()
	}

	return PLC{
		cps: cps
		data: data_elements
		data_size: data_size
	}
}

// count returns the number of data elements in the PLC.
pub fn (plc &PLC) count() int {
	return plc.data.len
}

// get_range returns the character range for the given data element index.
pub fn (plc &PLC) get_range(index int) !(CP, CP) {
	if index < 0 || index >= plc.data.len {
		return error('plc: invalid index $index')
	}
	return plc.cps[index], plc.cps[index + 1]
}

// get_data_at returns the data element at the given index.
pub fn (plc &PLC) get_data_at(index int) ![]u8 {
	if index < 0 || index >= plc.data.len {
		return error('plc: invalid index $index')
	}
	return plc.data[index]
}

// validate performs basic validation on the PLC structure.
pub fn (plc &PLC) validate() ! {
	if plc.cps.len != plc.data.len + 1 {
		return error('plc: invalid structure, CPs count (${plc.cps.len}) != Data count (${plc.data.len}) + 1')
	}

	// Check that CPs are in ascending order
	for i := 1; i < plc.cps.len; i++ {
		if plc.cps[i] < plc.cps[i-1] {
			return error('plc: CPs not in ascending order at index $i')
		}
	}

	// Check that all data elements have the same size
	for i, data_elem in plc.data {
		if data_elem.len != plc.data_size {
			return error('plc: data element $i has size ${data_elem.len}, expected ${plc.data_size}')
		}
	}
}