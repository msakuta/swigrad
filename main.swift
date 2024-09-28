
indirect enum Term: Hashable {
    case Value(Double)
    case Add(Term, Term)
    case Sub(Term, Term)
    case Mul(Term, Term)
    case Div(Term, Term)
}

let a = Term.Value(1)
let b = Term.Value(2)
let ab = Term.Add(a, b)
let c = Term.Value(42)
let abc = Term.Mul(ab, c)

func eval(_ t: Term) -> Double {
    switch t {
    case let .Value(v): return v
    case let .Add(lhs, rhs): return eval(lhs) + eval(rhs)
    case let .Sub(lhs, rhs): return eval(lhs) - eval(rhs)
    case let .Mul(lhs, rhs): return eval(lhs) * eval(rhs)
    case let .Div(lhs, rhs): return eval(lhs) / eval(rhs)
    }
}

func derive(_ t: Term, _ wrt: Term) -> Double {
    switch t {
        case .Value(_): if (t) == (wrt) {
            return 1
        } else {
            return 0
        }
        case let .Add(lhs, rhs): return derive(lhs, wrt) + derive(rhs, wrt)
        case let .Sub(lhs, rhs): return derive(lhs, wrt) - derive(rhs, wrt)
        case let .Mul(lhs, rhs): 
            return eval(lhs) * derive(rhs, wrt) + derive(lhs, wrt) * eval(rhs)
        case let .Div(lhs, rhs):
            let lhsv = eval(lhs)
            let rhsv = eval(rhs)
            return derive(lhs, wrt) / rhsv - lhsv * derive(rhs, wrt) / rhsv / rhsv
    }
}

print("a = \(eval(a)), b = \(eval(b)), c = \(eval(c)), (a + b) * c = \(eval(abc))")
print("dabc/da", derive(abc, a))
print("dabc/db", derive(abc, b))
print("dabc/dc", derive(abc, c))

