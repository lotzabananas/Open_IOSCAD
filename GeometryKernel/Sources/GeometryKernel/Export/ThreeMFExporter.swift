import Foundation

public enum ThreeMFExporter {
    /// Export a TriangleMesh to 3MF format (ZIP archive with XML)
    public static func export(_ mesh: TriangleMesh) -> Data {
        let modelXML = generateModelXML(mesh)
        let contentTypes = generateContentTypes()
        let rels = generateRels()

        // Build ZIP archive manually (minimal implementation)
        var zip = ZipBuilder()
        zip.addFile(name: "[Content_Types].xml", data: contentTypes.data(using: .utf8)!)
        zip.addFile(name: "_rels/.rels", data: rels.data(using: .utf8)!)
        zip.addFile(name: "3D/3dmodel.model", data: modelXML.data(using: .utf8)!)
        return zip.build()
    }

    private static func generateModelXML(_ mesh: TriangleMesh) -> String {
        var xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <model unit="millimeter" xmlns="http://schemas.microsoft.com/3dmanufacturing/core/2015/02">
          <resources>
            <object id="1" type="model">
              <mesh>
                <vertices>
        """

        for v in mesh.vertices {
            xml += "\n          <vertex x=\"\(v.x)\" y=\"\(v.y)\" z=\"\(v.z)\" />"
        }

        xml += """

                </vertices>
                <triangles>
        """

        for tri in mesh.triangles {
            xml += "\n          <triangle v1=\"\(tri.0)\" v2=\"\(tri.1)\" v3=\"\(tri.2)\" />"
        }

        xml += """

                </triangles>
              </mesh>
            </object>
          </resources>
          <build>
            <item objectid="1" />
          </build>
        </model>
        """

        return xml
    }

    private static func generateContentTypes() -> String {
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types">
          <Default Extension="rels" ContentType="application/vnd.openxmlformats-package.relationships+xml" />
          <Default Extension="model" ContentType="application/vnd.ms-package.3dmanufacturing-3dmodel+xml" />
        </Types>
        """
    }

    private static func generateRels() -> String {
        return """
        <?xml version="1.0" encoding="UTF-8"?>
        <Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships">
          <Relationship Target="/3D/3dmodel.model" Id="rel0" Type="http://schemas.microsoft.com/3dmanufacturing/2013/01/3dmodel" />
        </Relationships>
        """
    }
}

// MARK: - Minimal ZIP builder (no compression, store only)

struct ZipBuilder {
    private var entries: [(name: String, data: Data)] = []

    mutating func addFile(name: String, data: Data) {
        entries.append((name, data))
    }

    func build() -> Data {
        var archive = Data()
        var centralDirectory = Data()
        var offsets: [UInt32] = []

        for entry in entries {
            offsets.append(UInt32(archive.count))

            let nameData = entry.name.data(using: .utf8)!
            let crc = crc32(entry.data)

            // Local file header
            appendUInt32(&archive, 0x04034b50) // signature
            appendUInt16(&archive, 20)          // version needed
            appendUInt16(&archive, 0)           // flags
            appendUInt16(&archive, 0)           // compression (store)
            appendUInt16(&archive, 0)           // mod time
            appendUInt16(&archive, 0)           // mod date
            appendUInt32(&archive, crc)         // crc32
            appendUInt32(&archive, UInt32(entry.data.count)) // compressed size
            appendUInt32(&archive, UInt32(entry.data.count)) // uncompressed size
            appendUInt16(&archive, UInt16(nameData.count))   // name length
            appendUInt16(&archive, 0)           // extra length
            archive.append(nameData)
            archive.append(entry.data)
        }

        let cdOffset = UInt32(archive.count)

        for (i, entry) in entries.enumerated() {
            let nameData = entry.name.data(using: .utf8)!
            let crc = crc32(entry.data)

            // Central directory entry
            appendUInt32(&centralDirectory, 0x02014b50) // signature
            appendUInt16(&centralDirectory, 20)          // version made by
            appendUInt16(&centralDirectory, 20)          // version needed
            appendUInt16(&centralDirectory, 0)           // flags
            appendUInt16(&centralDirectory, 0)           // compression
            appendUInt16(&centralDirectory, 0)           // mod time
            appendUInt16(&centralDirectory, 0)           // mod date
            appendUInt32(&centralDirectory, crc)
            appendUInt32(&centralDirectory, UInt32(entry.data.count))
            appendUInt32(&centralDirectory, UInt32(entry.data.count))
            appendUInt16(&centralDirectory, UInt16(nameData.count))
            appendUInt16(&centralDirectory, 0)  // extra length
            appendUInt16(&centralDirectory, 0)  // comment length
            appendUInt16(&centralDirectory, 0)  // disk number
            appendUInt16(&centralDirectory, 0)  // internal attrs
            appendUInt32(&centralDirectory, 0)  // external attrs
            appendUInt32(&centralDirectory, offsets[i])
            centralDirectory.append(nameData)
        }

        archive.append(centralDirectory)

        // End of central directory
        appendUInt32(&archive, 0x06054b50)
        appendUInt16(&archive, 0)  // disk number
        appendUInt16(&archive, 0)  // cd disk number
        appendUInt16(&archive, UInt16(entries.count))
        appendUInt16(&archive, UInt16(entries.count))
        appendUInt32(&archive, UInt32(centralDirectory.count))
        appendUInt32(&archive, cdOffset)
        appendUInt16(&archive, 0)  // comment length

        return archive
    }

    private func appendUInt16(_ data: inout Data, _ value: UInt16) {
        var v = value.littleEndian
        data.append(Data(bytes: &v, count: 2))
    }

    private func appendUInt32(_ data: inout Data, _ value: UInt32) {
        var v = value.littleEndian
        data.append(Data(bytes: &v, count: 4))
    }

    private func crc32(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xFFFFFFFF
        for byte in data {
            crc ^= UInt32(byte)
            for _ in 0..<8 {
                if crc & 1 != 0 {
                    crc = (crc >> 1) ^ 0xEDB88320
                } else {
                    crc >>= 1
                }
            }
        }
        return crc ^ 0xFFFFFFFF
    }
}
