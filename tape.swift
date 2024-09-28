struct TapeNode {
    var name: String
    var value: TapeValue
    var data: Double?
    var grad: Double?
}

enum TapeValue {
    case Value(Double)
    case Add(Int, Int)
    case Sub(Int, Int)
    case Mul(Int, Int)
    case Div(Int, Int)
}

class Tape {
    var tape: [TapeNode] = []

    var count: Int {
        get { tape.count }
    }

    func value(name: String, _ val: Double) -> TapeTerm {
        let ret = tape.count
        tape.append(TapeNode(
            name: name,
            value: TapeValue.Value(val)
        ))
        return TapeTerm(ret, self)
    }

    func add_add(_ lhs: Int, _ rhs: Int) -> Int {
        let ret = tape.count
        tape.append(TapeNode(
            name: tape[lhs].name + " + " + tape[rhs].name,
            value: TapeValue.Add(lhs, rhs)
        ))
        return ret
    }

    func add_sub(_ lhs: Int, _ rhs: Int) -> Int {
        let ret = tape.count
        tape.append(TapeNode(
            name: tape[lhs].name + " - " + tape[rhs].name,
            value: TapeValue.Sub(lhs, rhs)
        ))
        return ret
    }

    func add_mul(_ lhs: Int, _ rhs: Int) -> Int {
        let ret = tape.count
        tape.append(TapeNode(
            name: tape[lhs].name + " * " + tape[rhs].name,
            value: TapeValue.Mul(lhs, rhs)
        ))
        return ret
    }

    func add_div(_ lhs: Int, _ rhs: Int) -> Int {
        let ret = tape.count
        tape.append(TapeNode(
            name: tape[lhs].name + " / " + tape[rhs].name,
            value: TapeValue.Div(lhs, rhs)
        ))
        return ret
    }

    func eval_int(_ term: Int) -> Double {
        let node = tape[term]
        switch node.value {
            case let .Value(v): return v
            case let .Add(lhs, rhs): return eval_int(lhs) + eval_int(rhs)
            case let .Sub(lhs, rhs): return eval_int(lhs) - eval_int(rhs)
            case let .Mul(lhs, rhs): return eval_int(lhs) * eval_int(rhs)
            case let .Div(lhs, rhs): return eval_int(lhs) / eval_int(rhs)
        }
    }

    func derive_int(_ term: Int, _ wrt: Int) -> Double {
        let node = tape[term]
        switch node.value {
            case let .Value(v): if term == wrt {
                return 1
            } else {
                return 0
            }
            case let .Add(lhs, rhs): return derive_int(lhs, wrt) + derive_int(rhs, wrt)
            case let .Sub(lhs, rhs): return derive_int(lhs, wrt) - derive_int(rhs, wrt)
            case let .Mul(lhs, rhs): return eval_int(lhs) * derive_int(rhs, wrt) + derive_int(lhs, wrt) * eval_int(rhs)
            case let .Div(lhs, rhs):
                let lhsv = eval_int(lhs)
                let rhsv = eval_int(rhs)
                return derive_int(lhs, wrt) / rhsv - lhsv * derive_int(rhs, wrt) / rhsv / rhsv
        }
    }
}

struct TapeTerm {
    var idx: Int
    var tape: Tape
    init(_ idx: Int, _ tape: Tape) {
        self.idx = idx
        self.tape = tape
    }
    func eval() -> Double { return  tape.eval_int(idx) }
    func derive(_ wrt: TapeTerm) -> Double { tape.derive_int(idx, wrt.idx) }
    // func backward() = {
    //     tape.clear_grad()
    //     tape.backward_int(idx)
    // }
    // func gen_graph(wrt: TapeTerm): Option[TapeTerm] = tape.gen_graph(idx, wrt.idx).map({ x => TapeTerm(x, tape) })
    // func set(v: Double) = tape.terms(idx).set(v)
    // func grad(): Option[Double] = tape.terms(idx).grad
    // func +(other: TapeTerm) = TapeTerm(tape.add_add(idx, other.idx), tape)
    // func -(other: TapeTerm) = TapeTerm(tape.add_sub(idx, other.idx), tape)
    // func *(other: TapeTerm) = TapeTerm(tape.add_mul(idx, other.idx), tape)
    // func /(other: TapeTerm) = TapeTerm(tape.add_div(idx, other.idx), tape)
    // func unary_- = TapeTerm(tape.add_neg(idx), tape)

    // func apply(name: String, f: (Double) => Double, g: (Double) => Double, gg: (Int, Int, Int) => Option[Int]) = {
    //     TapeTerm(tape.add_unary(idx, name, f, g, gg), tape)
    // }
}


func + (lhs: TapeTerm, _ rhs: TapeTerm) -> TapeTerm {
    assert(ObjectIdentifier(lhs.tape) == ObjectIdentifier(rhs.tape))
    let tape = lhs.tape
    return TapeTerm(tape.add_add(lhs.idx, rhs.idx), tape)
}

func - (lhs: TapeTerm, _ rhs: TapeTerm) -> TapeTerm {
    assert(ObjectIdentifier(lhs.tape) == ObjectIdentifier(rhs.tape))
    let tape = lhs.tape
    return TapeTerm(tape.add_sub(lhs.idx, rhs.idx), tape)
}

func * (lhs: TapeTerm, _ rhs: TapeTerm) -> TapeTerm {
    assert(ObjectIdentifier(lhs.tape) == ObjectIdentifier(rhs.tape))
    let tape = lhs.tape
    return TapeTerm(tape.add_mul(lhs.idx, rhs.idx), tape)
}

func / (lhs: TapeTerm, _ rhs: TapeTerm) -> TapeTerm {
    assert(ObjectIdentifier(lhs.tape) == ObjectIdentifier(rhs.tape))
    let tape = lhs.tape
    return TapeTerm(tape.add_div(lhs.idx, rhs.idx), tape)
}

var tape = Tape()

let a = tape.value(name: "a", 1)
let b = tape.value(name: "b", 2)
let ab = a + b
let c = tape.value(name: "c", 42)
let abc = ab * c

print(tape)
print(ab.eval())
print(abc.derive(a))
