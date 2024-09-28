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

struct Tape {
    var tape: [TapeNode] = []

    mutating func addConst(name: String, _ val: Double) -> Int {
        let ret = tape.count
        tape.append(TapeNode(
            name: name,
            value: TapeValue.Value(val)
        ))
        return ret
    }

    mutating func add(_ lhs: Int, _ rhs: Int) -> Int {
        let ret = tape.count
        tape.append(TapeNode(
            name: tape[lhs].name + " + " + tape[rhs].name,
            value: TapeValue.Add(lhs, rhs)
        ))
        return ret
    }

    mutating func mul(_ lhs: Int, _ rhs: Int) -> Int {
        let ret = tape.count
        tape.append(TapeNode(
            name: tape[lhs].name + " * " + tape[rhs].name,
            value: TapeValue.Mul(lhs, rhs)
        ))
        return ret
    }

    func eval(_ idx: Int) -> Double {
        let node = tape[idx]
        switch node.value {
            case let .Value(v): return v
            case let .Add(lhs, rhs): return eval(lhs) + eval(rhs)
            case let .Sub(lhs, rhs): return eval(lhs) - eval(rhs)
            case let .Mul(lhs, rhs): return eval(lhs) * eval(rhs)
            case let .Div(lhs, rhs): return eval(lhs) / eval(rhs)
        }
    }

    func derive(_ idx: Int, _ wrt: Int) -> Double {
        let node = tape[idx]
        switch node.value {
            case let .Value(v): if idx == wrt {
                return 1
            } else {
                return 0
            }
            case let .Add(lhs, rhs): return derive(lhs, wrt) + derive(rhs, wrt)
            case let .Sub(lhs, rhs): return derive(lhs, wrt) - derive(rhs, wrt)
            case let .Mul(lhs, rhs): return eval(lhs) * derive(rhs, wrt) + derive(lhs, wrt) * eval(rhs)
            case let .Div(lhs, rhs):
                let lhsv = eval(lhs)
                let rhsv = eval(rhs)
                return derive(lhs, wrt) / rhsv - lhsv * derive(rhs, wrt) / rhsv / rhsv
        }
    }
}

var tape = Tape()

let a = tape.addConst(name: "a", 1)
let b = tape.addConst(name: "b", 2)
let ab = tape.add(a, b)
let c = tape.addConst(name: "c", 42)
let abc = tape.mul(ab, c)

print(tape)
print(tape.eval(ab))
print(tape.derive(abc, a))
