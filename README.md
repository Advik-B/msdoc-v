# MsDoc-V

> A V implementation of the Microsoft Word .doc file format reader

## Overview

MsDoc-V is a V library that implements the Microsoft Word Binary File Format (.doc) specification (MS-DOC). It allows you to extract text content and metadata from Word 97-2003 documents.

**Note**: This is a complete V port of the original Go implementation with full feature parity. The Go codebase has been removed as the V implementation provides all the same functionality with better performance and memory safety.

## Features

- ✅ **Text Extraction**: Extract plain text content from .doc files
- ✅ **Formatted Text**: Extract text with complete formatting information (fonts, colors, styles)
- ✅ **Metadata Reading**: Access comprehensive document properties (title, author, creation date, and more)
- ✅ **Format Support**: Word 97-2003 (.doc) files
- ✅ **OLE2 Parsing**: Full OLE2 compound document support
- ✅ **Unicode Support**: Handles both ANSI and Unicode text content
- ✅ **Piece Table Processing**: Correctly reconstructs fragmented text
- ✅ **Encryption Support**: Full support for encrypted and password-protected documents
- ✅ **VBA Macro Support**: Extract and decompile VBA macros and projects
- ✅ **Complete Metadata**: Full SummaryInformation and DocumentSummaryInformation parsing
- ✅ **Document Creation**: Create new .doc files from scratch
- ✅ **Document Modification**: Modify existing documents (text, formatting, metadata)
- ✅ **Write Support**: Full document creation and modification capabilities

## Installation

### Prerequisites
- V programming language (0.4.12+)

### Build
```bash
# Clone the repository
git clone https://github.com/Advik-B/msdoc-v.git
cd msdoc-v

# Build the library
v . -o msdoc

# Run tests
./msdoc --test
```

## Quick Start

```v
import main

// Open a .doc file
doc := main.open('sample.doc')!

// Extract plain text
text := doc.text()!
println('=== Document Text ===')
println(text)

// Extract metadata  
metadata := doc.get_metadata()!
println('=== Metadata ===')
println('Title: ${metadata.title}')
println('Author: ${metadata.author}')
println('Subject: ${metadata.subject}')

// Check for VBA macros
if doc.has_macros() {
	modules := doc.get_all_vba_modules()!
	println('VBA Modules: $modules')
}
```

## Command Line Usage

You can use the built binary to analyze .doc files:

```bash
# Analyze a document
./msdoc sample.doc

# Run tests
./msdoc --test

# Create a sample document
./msdoc --create output.doc
```

## Advanced Features

```v
import main

// Password-protected documents
doc := main.open_with_password('encrypted.doc', 'password123')!

// Extract formatted text with markdown
markdown := doc.markdown_text()!
println(markdown)

// Create new documents
mut writer := main.new_writer()
writer.set_title('My Document')
writer.set_author('V Developer')
writer.add_paragraph('Hello from V!')
writer.save('output.doc')!
```

## Documentation

For complete API documentation, see [README_V.md](README_V.md) which contains comprehensive examples, architecture details, and performance comparisons.

## License

MIT License - same as the original Go implementation.

## Acknowledgments  

This V implementation is based on the excellent Go msdoc library by TalentFormula. The conversion demonstrates V's capability for systems programming and binary file format processing while maintaining full feature parity with the original implementation.