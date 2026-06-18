// splitpdf — PDF flattener and size-limited splitter
// Usage: splitpdf <input.pdf> <max_size_mb>
// Outputs: <sanitized_name>/ directory alongside the input file

import Foundation
import PDFKit
import CoreGraphics

// MARK: - Entry point

guard CommandLine.arguments.count == 3 else {
    fputs("Usage: splitpdf <input.pdf> <max_size_mb>\n", stderr)
    exit(1)
}

let inputPath = CommandLine.arguments[1]
let inputURL  = URL(fileURLWithPath: inputPath)

guard let maxMB = Double(CommandLine.arguments[2]), maxMB > 0 else {
    fputs("Error: max_size_mb must be a positive number.\n", stderr)
    exit(1)
}

let maxBytes    = Int(maxMB * 1024 * 1024)
let safeBytes   = Int(Double(maxBytes) * 0.95) // 5% margin covers PDFKit serialization variance

// MARK: - Step 1: Sanitize filename

/// Converts the source filename into a safe, length-limited base name.
/// - Only alphanumeric characters are kept; everything else is removed
/// - Result is truncated to 25 characters
func sanitizeFilename(_ raw: String) -> String {
    let filtered = raw.unicodeScalars
                      .filter { CharacterSet.alphanumerics.contains($0) }
                      .map    { String($0) }
                      .joined()
    return String(filtered.prefix(25))
}

let rawBaseName = inputURL.deletingPathExtension().lastPathComponent
let safeName    = sanitizeFilename(rawBaseName)

guard !safeName.isEmpty else {
    fputs("Error: filename '\(rawBaseName)' produced an empty sanitized name.\n", stderr)
    exit(1)
}

print("Sanitized filename: \(safeName)")

// MARK: - Step 2: Load source PDF

guard let sourcePDF = PDFDocument(url: inputURL) else {
    fputs("Error: could not open PDF at \(inputPath)\n", stderr)
    exit(1)
}

let pageCount = sourcePDF.pageCount
guard pageCount > 0 else {
    fputs("Error: PDF has no pages.\n", stderr)
    exit(1)
}

print("Source PDF: \(pageCount) page(s)")

// MARK: - Step 3: Flatten PDF

/// Renders every page of the source PDF into a fresh PDF document via CGContext.
/// This merges form fields, annotations, highlights, comments, and all other
/// interactive or floating content into static page content — equivalent to
/// printing to PDF.
func flattenPDF(_ source: PDFDocument) -> PDFDocument? {
    let output = NSMutableData()

    guard let consumer = CGDataConsumer(data: output as CFMutableData) else { return nil }

    // CGContext(consumer:mediaBox:_:) is the modern Swift replacement for
    // CGPDFContextCreate, which was obsoleted in Swift 3.
    guard let context = CGContext(consumer: consumer, mediaBox: nil, nil) else {
        return nil
    }

    for i in 0..<source.pageCount {
        guard let page = source.page(at: i) else { continue }

        let bounds = page.bounds(for: .mediaBox)

        // beginPDFPage replaces CGPDFContextBeginPage (obsoleted Swift 3)
        // Pass the mediaBox for this specific page so each page retains
        // its original dimensions.
        let pageInfo: CFDictionary = [
            kCGPDFContextMediaBox as String: NSValue(rect: bounds)
        ] as CFDictionary

        context.beginPDFPage(pageInfo)

        // PDFKit and CGContext both use bottom-left origin on macOS.
        // No coordinate flip needed — draw the page directly.
        // Using page.draw(with:to:) renders all content: text, images,
        // form fields, annotations, highlights, sticky notes, etc.
        page.draw(with: .mediaBox, to: context)

        // endPDFPage replaces CGPDFContextEndPage (obsoleted Swift 3)
        context.endPDFPage()
    }

    // closePDF replaces CGPDFContextClose (obsoleted Swift 3)
    context.closePDF()

    return PDFDocument(data: output as Data)
}

print("Flattening PDF...")
guard let flatPDF = flattenPDF(sourcePDF) else {
    fputs("Error: flattening failed.\n", stderr)
    exit(1)
}
print("Flattening complete. (\(flatPDF.pageCount) page(s))")

// MARK: - Step 4: Create output directory

let outputDir = inputURL
    .deletingLastPathComponent()
    .appendingPathComponent(safeName, isDirectory: true)

do {
    try FileManager.default.createDirectory(
        at: outputDir,
        withIntermediateDirectories: true,
        attributes: nil
    )
} catch {
    fputs("Error: could not create output directory: \(error.localizedDescription)\n", stderr)
    exit(1)
}

print("Output directory: \(outputDir.path)")

// MARK: - Step 5: Greedy split loop

/// Writes a PDFDocument chunk to disk with a sequentially numbered filename.
func writeChunk(_ chunk: PDFDocument, index: Int, baseName: String, to dir: URL) throws {
    let fileName  = "\(baseName)\(String(format: "%02d", index)).pdf"
    let outputURL = dir.appendingPathComponent(fileName)
    guard let data = chunk.dataRepresentation() else {
        throw NSError(domain: "splitpdf", code: 1,
                      userInfo: [NSLocalizedDescriptionKey: "Could not serialize chunk \(index)"])
    }
    try data.write(to: outputURL, options: .atomic)
    let kb = Double(data.count) / 1024.0
    print("  Wrote \(fileName) (\(String(format: "%.1f", kb)) KB)")
}

print("Splitting into chunks ≤ \(maxMB) MB...")

var chunkIndex    = 1
var currentChunk  = PDFDocument()
var skippedPages  = [Int]()

for i in 0..<flatPDF.pageCount {
    guard let page = flatPDF.page(at: i) else { continue }

    currentChunk.insert(page, at: currentChunk.pageCount)

    // Probe the current chunk size
    if let probeData = currentChunk.dataRepresentation(),
       probeData.count > safeBytes {

        if currentChunk.pageCount == 1 {
            let pageMB = String(format: "%.1f", Double(probeData.count) / 1024.0 / 1024.0)
            print("OVERSIZED_PAGE:\(i + 1):\(pageMB)")
            skippedPages.append(i + 1)
            currentChunk = PDFDocument()
        } else {
            // Back off: remove the page that pushed us over the limit
            currentChunk.removePage(at: currentChunk.pageCount - 1)

            // Write the chunk without that page
            do {
                try writeChunk(currentChunk, index: chunkIndex, baseName: safeName, to: outputDir)
            } catch {
                fputs("Error writing chunk: \(error.localizedDescription)\n", stderr)
                exit(1)
            }
            chunkIndex   += 1

            // Start a fresh chunk with the page that pushed us over
            currentChunk = PDFDocument()
            currentChunk.insert(page, at: 0)
        }
    }
}

// Write whatever remains in the final chunk
if currentChunk.pageCount > 0 {
    do {
        try writeChunk(currentChunk, index: chunkIndex, baseName: safeName, to: outputDir)
    } catch {
        fputs("Error writing final chunk: \(error.localizedDescription)\n", stderr)
        exit(1)
    }
}

let writtenCount = chunkIndex - 1
if !skippedPages.isEmpty {
    print("OVERSIZED_SUMMARY:\(skippedPages.map { String($0) }.joined(separator: ","))")
}
print("Done. \(writtenCount) file(s) written to \(outputDir.lastPathComponent)/")
