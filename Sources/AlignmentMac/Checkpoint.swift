import Foundation
import AlignmentCore

/// Reads tensors from a PyTorch zip checkpoint without Python. Only the pickle opcodes used by the pinned Demucs
/// checkpoint are supported; classes are never instantiated or executed, only recorded by name, and tensors are
/// rebuilt from their storage records.
public struct TorchCheckpoint {
    /// Float32 values in row-major order with their shape.
    public struct Tensor {
        public let shape: [Int]
        public let values: [Float]
    }
    public let tensors: [String: Tensor]

    /// Reads the state dictionary stored under `stateKey` (Demucs stores it under "state").
    public init(_ data: Data, stateKey: String = "state") throws {
        let archive = try StoredZip(data)
        guard let pickleName = archive.names.first(where: { $0.hasSuffix("/data.pkl") }) else {
            throw AlignmentError.invalid("Checkpoint lacks data.pkl")
        }
        let prefix = String(pickleName.dropLast("data.pkl".count))
        let root = try Unpickler(try archive.entry(pickleName)).load()
        guard case .dict(let top) = root, let state = top.value(for: stateKey), case .dict(let entries) = state else {
            throw AlignmentError.invalid("Checkpoint lacks a state dictionary")
        }
        var tensors = [String: Tensor]()
        for (k, v) in entries.pairs {
            guard case .string(let name) = k, case .tensor(let t) = v else { continue }
            tensors[name] = try t.materialize(archive, prefix: prefix)
        }
        self.tensors = tensors
    }
}

/// Uncompressed (stored) zip entries, located through the central directory.
struct StoredZip {
    let data: Data
    private var offsets = [String: (Int, Int)]()
    var names: [String] { Array(offsets.keys) }
    init(_ data: Data) throws {
        self.data = data
        func u16(_ o: Int) -> Int { Int(data[data.startIndex + o]) | Int(data[data.startIndex + o + 1]) << 8 }
        func u32(_ o: Int) -> Int { u16(o) | u16(o + 2) << 16 }
        guard data.count >= 22,
            let eocd = stride(from: data.count - 22, through: max(0, data.count - 65557), by: -1).first(where: {
                u32($0) == 0x0605_4b50
            })
        else {
            throw AlignmentError.invalid("Checkpoint is not a zip archive")
        }
        var p = u32(eocd + 16)
        var count = u16(eocd + 10)
        while count > 0 {
            guard u32(p) == 0x0201_4b50 else { throw AlignmentError.invalid("Malformed zip central directory") }
            let method = u16(p + 10)
            let size = u32(p + 20)
            let nameLength = u16(p + 28)
            let extra = u16(p + 30)
            let comment = u16(p + 32)
            let local = u32(p + 42)
            let name = String(
                decoding: data[(data.startIndex + p + 46)..<(data.startIndex + p + 46 + nameLength)], as: UTF8.self)
            guard method == 0 else { throw AlignmentError.invalid("Compressed checkpoint entries are unsupported") }
            let start = local + 30 + u16(local + 26) + u16(local + 28)
            offsets[name] = (start, size)
            p += 46 + nameLength + extra + comment
            count -= 1
        }
    }
    func entry(_ name: String) throws -> Data {
        guard let (start, size) = offsets[name], start + size <= data.count else {
            throw AlignmentError.invalid("Missing checkpoint entry \(name)")
        }
        return data.subdata(in: (data.startIndex + start)..<(data.startIndex + start + size))
    }
}

/// Values produced by the restricted unpickler; containers are reference types because pickle memoizes them.
indirect enum PickleValue {
    case none
    case bool(Bool)
    case int(Int)
    case double(Double)
    case string(String)
    case mark
    case list(PickleList)
    case dict(PickleDict)
    case tuple([PickleValue])
    case global(String, String)
    case object(String, [PickleValue])
    case storage(dtype: String, key: String)
    case tensor(TensorRecord)
}
final class PickleList { var items = [PickleValue]() }
final class PickleDict {
    var pairs = [(PickleValue, PickleValue)]()
    func value(for key: String) -> PickleValue? {
        pairs.first(where: {
            if case .string(let k) = $0.0 { return k == key }
            return false
        })?.1
    }
}
struct TensorRecord {
    let dtype, key: String
    let offset: Int
    let shape, strides: [Int]
    func materialize(_ archive: StoredZip, prefix: String) throws -> TorchCheckpoint.Tensor {
        let raw = try archive.entry(prefix + "data/" + key)
        let count = shape.reduce(1, *)
        var values = [Float](repeating: 0, count: count)
        var index = [Int](repeating: 0, count: shape.count)
        func element(_ i: Int) throws -> Float {
            switch dtype {
            case "HalfStorage":
                let b = raw.startIndex + 2 * i
                return Float(Float16(bitPattern: UInt16(raw[b]) | UInt16(raw[b + 1]) << 8))
            case "FloatStorage":
                let b = raw.startIndex + 4 * i
                return Float(
                    bitPattern: UInt32(raw[b]) | UInt32(raw[b + 1]) << 8 | UInt32(raw[b + 2]) << 16 | UInt32(raw[b + 3])
                        << 24)
            default: throw AlignmentError.invalid("Unsupported checkpoint storage \(dtype)")
            }
        }
        for n in 0..<count {
            var source = offset
            for d in 0..<shape.count { source += index[d] * strides[d] }
            values[n] = try element(source)
            var d = shape.count - 1
            while d >= 0 {
                index[d] += 1
                if index[d] < shape[d] { break }
                index[d] = 0
                d -= 1
            }
        }
        return .init(shape: shape, values: values)
    }
}

/// Protocol-2 pickle subset: no code is executed and unknown classes become inert records.
struct Unpickler {
    let bytes: [UInt8]
    init(_ data: Data) { bytes = [UInt8](data) }
    func load() throws -> PickleValue {
        var stack = [PickleValue]()
        var marks = [Int]()
        var memo = [Int: PickleValue]()
        var p = 0
        func byte() throws -> Int {
            guard p < bytes.count else { throw AlignmentError.invalid("Truncated pickle") }
            p += 1
            return Int(bytes[p - 1])
        }
        func le(_ n: Int) throws -> Int {
            var v = 0
            for k in 0..<n { v |= try byte() << (8 * k) }
            return v
        }
        func line() throws -> String {
            var s = [UInt8]()
            while true {
                let b = try byte()
                if b == 10 { break }
                s.append(UInt8(b))
            }
            return String(decoding: s, as: UTF8.self)
        }
        func pop() throws -> PickleValue {
            guard let v = stack.popLast() else { throw AlignmentError.invalid("Pickle stack underflow") }
            return v
        }
        func popToMark() throws -> [PickleValue] {
            guard let m = marks.popLast(), m <= stack.count else { throw AlignmentError.invalid("Pickle mark missing") }
            let items = Array(stack[m...])
            stack.removeLast(stack.count - m)
            return items
        }
        func intValue(_ v: PickleValue) -> Int? {
            if case .int(let i) = v { return i }
            return nil
        }
        while true {
            let op = try byte()
            switch op {
            case 0x80: _ = try byte()  // PROTO
            case 0x2e: return try pop()  // STOP
            case 0x63: stack.append(.global(try line(), try line()))  // GLOBAL
            case 0x71: memo[try byte()] = stack.last  // BINPUT
            case 0x72: memo[try le(4)] = stack.last  // LONG_BINPUT
            case 0x68: stack.append(memo[try byte()] ?? .none)  // BINGET
            case 0x6a: stack.append(memo[try le(4)] ?? .none)  // LONG_BINGET
            case 0x7d: stack.append(.dict(PickleDict()))  // EMPTY_DICT
            case 0x5d: stack.append(.list(PickleList()))  // EMPTY_LIST
            case 0x29: stack.append(.tuple([]))  // EMPTY_TUPLE
            case 0x28: marks.append(stack.count)  // MARK
            case 0x58:  // BINUNICODE
                let n = try le(4)
                guard p + n <= bytes.count else { throw AlignmentError.invalid("Truncated pickle") }
                stack.append(.string(String(decoding: bytes[p..<p + n], as: UTF8.self)))
                p += n
            case 0x4a: stack.append(.int(Int(Int32(truncatingIfNeeded: try le(4)))))  // BININT
            case 0x4b: stack.append(.int(try byte()))  // BININT1
            case 0x4d: stack.append(.int(try le(2)))  // BININT2
            case 0x47:  // BINFLOAT (big-endian)
                var v: UInt64 = 0
                for _ in 0..<8 { v = v << 8 | UInt64(try byte()) }
                stack.append(.double(Double(bitPattern: v)))
            case 0x88: stack.append(.bool(true))  // NEWTRUE
            case 0x89: stack.append(.bool(false))  // NEWFALSE
            case 0x4e: stack.append(.none)  // NONE
            case 0x74: stack.append(.tuple(try popToMark()))  // TUPLE
            case 0x85: stack.append(.tuple([try pop()]))  // TUPLE1
            case 0x86:
                let b = try pop()
                let a = try pop()
                stack.append(.tuple([a, b]))  // TUPLE2
            case 0x87:
                let c = try pop()
                let b = try pop()
                let a = try pop()
                stack.append(.tuple([a, b, c]))  // TUPLE3
            case 0x61:  // APPEND
                let v = try pop()
                if case .list(let l) = stack.last { l.items.append(v) }
            case 0x65:  // APPENDS
                let items = try popToMark()
                if case .list(let l) = stack.last { l.items += items }
            case 0x75:  // SETITEMS
                let items = try popToMark()
                if case .dict(let d) = stack.last {
                    for k in stride(from: 0, to: items.count - 1, by: 2) { d.pairs.append((items[k], items[k + 1])) }
                }
            case 0x62: _ = try pop()  // BUILD: object state is not needed
            case 0x51:  // BINPERSID: ('storage', type, key, location, numel)
                guard case .tuple(let pid) = try pop(), pid.count >= 3, case .global(_, let type) = pid[1],
                    case .string(let key) = pid[2]
                else {
                    throw AlignmentError.invalid("Unsupported persistent reference")
                }
                stack.append(.storage(dtype: type, key: key))
            case 0x52:  // REDUCE
                let args = try pop()
                let callable = try pop()
                guard case .global(let module, let name) = callable, case .tuple(let a) = args else {
                    stack.append(.none)
                    continue
                }
                switch (module, name) {
                case ("torch._utils", "_rebuild_tensor_v2"):
                    guard a.count >= 4, case .storage(let dtype, let key) = a[0], let offset = intValue(a[1]),
                        case .tuple(let size) = a[2], case .tuple(let stride) = a[3]
                    else { throw AlignmentError.invalid("Malformed tensor record") }
                    stack.append(
                        .tensor(
                            TensorRecord(
                                dtype: dtype, key: key, offset: offset, shape: size.compactMap(intValue),
                                strides: stride.compactMap(intValue))))
                case ("collections", "OrderedDict"): stack.append(.dict(PickleDict()))
                default: stack.append(.object(module + "." + name, a))
                }
            default: throw AlignmentError.invalid(String(format: "Unsupported pickle opcode 0x%02x", op))
            }
        }
    }
}
