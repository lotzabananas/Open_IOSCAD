import Foundation
import simd

/// Writes tessellated geometry as a STEP AP214 file.
/// The geometry is encoded as a closed shell of triangulated faces.
public enum STEPWriter {

    /// Write a TriangleMesh to STEP format string.
    /// The `commentBlock` parameter is inserted in the DATA section
    /// for embedding the @openioscad history.
    public static func write(mesh: TriangleMesh, commentBlock: String = "") -> String {
        var lines: [String] = []

        // HEADER
        lines.append("ISO-10303-21;")
        lines.append("HEADER;")
        lines.append("FILE_DESCRIPTION(('OpeniOSCAD model'),'2;1');")

        let dateStr = ISO8601DateFormatter().string(from: Date())
        lines.append("FILE_NAME('model.step','\(dateStr)',(''),('OpeniOSCAD'),'','OpeniOSCAD','');")
        lines.append("FILE_SCHEMA(('AUTOMOTIVE_DESIGN'));")
        lines.append("ENDSEC;")

        // DATA
        lines.append("DATA;")

        // Comment block (for @openioscad history)
        if !commentBlock.isEmpty {
            lines.append(commentBlock)
        }

        if mesh.isEmpty {
            lines.append("ENDSEC;")
            lines.append("END-ISO-10303-21;")
            return lines.joined(separator: "\n")
        }

        var entityID = 1

        // Write cartesian points
        let pointStartID = entityID
        for vertex in mesh.vertices {
            lines.append("#\(entityID)=CARTESIAN_POINT('',(\(vertex.x),\(vertex.y),\(vertex.z)));")
            entityID += 1
        }

        // Write direction entities for normals (one per triangle)
        let dirStartID = entityID
        var triNormals: [SIMD3<Float>] = []
        for tri in mesh.triangles {
            let v0 = mesh.vertices[Int(tri.0)]
            let v1 = mesh.vertices[Int(tri.1)]
            let v2 = mesh.vertices[Int(tri.2)]
            var n = simd_cross(v1 - v0, v2 - v0)
            let len = simd_length(n)
            if len > 0 { n /= len }
            triNormals.append(n)
            lines.append("#\(entityID)=DIRECTION('',(\(n.x),\(n.y),\(n.z)));")
            entityID += 1
        }

        // Write vertex points
        let vpStartID = entityID
        for i in 0..<mesh.vertices.count {
            lines.append("#\(entityID)=VERTEX_POINT('',#\(pointStartID + i));")
            entityID += 1
        }

        // Write edge curves and oriented edges for each triangle
        // Each triangle becomes a face bound with 3 edges
        let faceStartID = entityID + mesh.triangles.count * 10 // Reserve space
        var faceEntityIDs: [Int] = []

        for (triIdx, tri) in mesh.triangles.enumerated() {
            let vp0 = vpStartID + Int(tri.0)
            let vp1 = vpStartID + Int(tri.1)
            let vp2 = vpStartID + Int(tri.2)

            // Line entities for edge curves
            let ln0 = entityID; entityID += 1
            let ln1 = entityID; entityID += 1
            let ln2 = entityID; entityID += 1
            lines.append("#\(ln0)=LINE('',#\(pointStartID + Int(tri.0)),#\(dirStartID + triIdx));")
            lines.append("#\(ln1)=LINE('',#\(pointStartID + Int(tri.1)),#\(dirStartID + triIdx));")
            lines.append("#\(ln2)=LINE('',#\(pointStartID + Int(tri.2)),#\(dirStartID + triIdx));")

            // Edge curves referencing the lines
            let ec0 = entityID; entityID += 1
            let ec1 = entityID; entityID += 1
            let ec2 = entityID; entityID += 1
            lines.append("#\(ec0)=EDGE_CURVE('',#\(vp0),#\(vp1),#\(ln0),.T.);")
            lines.append("#\(ec1)=EDGE_CURVE('',#\(vp1),#\(vp2),#\(ln1),.T.);")
            lines.append("#\(ec2)=EDGE_CURVE('',#\(vp2),#\(vp0),#\(ln2),.T.);")

            // Oriented edges
            let oe0 = entityID; entityID += 1
            let oe1 = entityID; entityID += 1
            let oe2 = entityID; entityID += 1
            lines.append("#\(oe0)=ORIENTED_EDGE('',*,*,#\(ec0),.T.);")
            lines.append("#\(oe1)=ORIENTED_EDGE('',*,*,#\(ec1),.T.);")
            lines.append("#\(oe2)=ORIENTED_EDGE('',*,*,#\(ec2),.T.);")

            // Edge loop
            let el = entityID; entityID += 1
            lines.append("#\(el)=EDGE_LOOP('',(\(toList([oe0, oe1, oe2]))));")

            // Face bound
            let fb = entityID; entityID += 1
            lines.append("#\(fb)=FACE_BOUND('',#\(el),.T.);")

            // Plane (normal + point)
            let planeNormal = dirStartID + triIdx
            let planePoint = pointStartID + Int(tri.0)
            let axis = entityID; entityID += 1
            lines.append("#\(axis)=AXIS2_PLACEMENT_3D('',#\(planePoint),#\(planeNormal),#\(planeNormal));")

            let plane = entityID; entityID += 1
            lines.append("#\(plane)=PLANE('',#\(axis));")

            // Advanced face
            let face = entityID; entityID += 1
            lines.append("#\(face)=ADVANCED_FACE('',(#\(fb)),#\(plane),.T.);")
            faceEntityIDs.append(face)
        }

        // Closed shell
        let closedShell = entityID; entityID += 1
        lines.append("#\(closedShell)=CLOSED_SHELL('',(\(toList(faceEntityIDs))));")

        // Manifold solid BREP
        let brep = entityID; entityID += 1
        lines.append("#\(brep)=MANIFOLD_SOLID_BREP('',#\(closedShell));")

        // Shape representation
        let context = entityID; entityID += 1
        lines.append("#\(context)=( GEOMETRIC_REPRESENTATION_CONTEXT(3) GLOBAL_UNCERTAINTY_ASSIGNED_CONTEXT((#\(entityID))) GLOBAL_UNIT_ASSIGNED_CONTEXT((#\(entityID+1),#\(entityID+2),#\(entityID+3))) REPRESENTATION_CONTEXT('','') );")
        entityID += 1

        // Units
        let uncert = entityID; entityID += 1
        lines.append("#\(uncert)=UNCERTAINTY_MEASURE_WITH_UNIT(LENGTH_MEASURE(1.E-07),#\(entityID),'','');")

        let mm = entityID; entityID += 1
        lines.append("#\(mm)=(LENGTH_UNIT() NAMED_UNIT(*) SI_UNIT(.MILLI.,.METRE.));")

        let rad = entityID; entityID += 1
        lines.append("#\(rad)=(NAMED_UNIT(*) PLANE_ANGLE_UNIT() SI_UNIT($,.RADIAN.));")

        let sr = entityID; entityID += 1
        lines.append("#\(sr)=(NAMED_UNIT(*) SI_UNIT($,.STERADIAN.) SOLID_ANGLE_UNIT());")

        let shapeRep = entityID; entityID += 1
        lines.append("#\(shapeRep)=SHAPE_REPRESENTATION('',(#\(brep)),#\(context));")

        lines.append("ENDSEC;")
        lines.append("END-ISO-10303-21;")

        return lines.joined(separator: "\n")
    }

    private static func toList(_ ids: [Int]) -> String {
        ids.map { "#\($0)" }.joined(separator: ",")
    }
}
