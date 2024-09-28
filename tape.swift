import Foundation

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
    case Neg(Int)
    case UnaryFn(Int, (Double) -> Double, (Double) -> Double, (Int, Int, Int) -> Int?)
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

    func add_neg(_ term: Int) -> Int {
        let ret = tape.count
        tape.append(TapeNode(
            name: "-" + tape[term].name,
            value: TapeValue.Neg(term)
        ))
        return ret
    }

    func add_unary(_ name: String, _ term: Int,
        f: @escaping (Double) -> Double,
        g: @escaping (Double) -> Double,
        gg: @escaping (Int, Int, Int) -> Int?) -> Int
    {
        let ret = tape.count
        tape.append(TapeNode(
            name: name + "(" + tape[term].name + ")",
            value: TapeValue.UnaryFn(term, f, g, gg)
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
            case let .Neg(term): return -eval_int(term)
            case let .UnaryFn(term, f, _, _): return f(eval_int(term))
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
            case let .Neg(term): return -derive_int(term, wrt)
            case let .UnaryFn(term, _, g, _): return derive_int(term, wrt) * g(eval_int(term))
        }
    }

    func clear_grad() {
        for i in 0..<tape.count {
            tape[i].grad = nil
        }
    }

    func backward_int(_ term: Int) {
        tape[term].grad = 1
        for i in (1..<tape.count).reversed() {
            backward_node(i)
        }
    }

    // Since swift doesn't allow simultaneous access to an array,
    // we cannot use `inout TapeNode` as the argument, because it will
    // borrow the reference to the whole tape for the entirety of this function,
    // making us unable to update another node.
    // Unfortunately it will be a cryptic runtime error, not a compile time one,
    // which is why I leave the comment here.
    // We need to access an element of the array like `tape[idx].grad`
    // every time.
    // Probably TapeNode is supposed to be a class in swift philosophy, but I
    // want it be a flat array without indirection.
    func backward_node(_ idx: Int) {
        switch tape[idx].value {
        case .Value:
            break
        case let .Add(lhs, rhs):
            let grad = tape[idx].grad
            if let grad {
                tape[lhs].grad = grad
                tape[rhs].grad = grad
            }
        case let .Sub(lhs, rhs):
            if let grad = tape[idx].grad {
                tape[lhs].grad = grad
                tape[rhs].grad = -grad
            }
        case let .Mul(lhs, rhs):
            if let grad = tape[idx].grad {
                tape[lhs].grad = grad * eval_int(rhs)
                tape[rhs].grad = grad * eval_int(lhs)
            }
        case let .Div(lhs, rhs):
            if let grad = tape[idx].grad {
                let lhsv = eval_int(lhs)
                let rhsv = eval_int(rhs)
                tape[lhs].grad = grad / rhsv
                tape[rhs].grad = -lhsv * grad / rhsv / rhsv
            }
        case let .Neg(term):
            if let grad = tape[idx].grad {
                tape[term].grad = -grad
            }
        case let .UnaryFn(term, _, g, _):
            if let grad = tape[idx].grad {
                tape[term].grad = g(grad)
            }
        }
    }

    func gen_graph(_ idx: Int, _ wrt: Int) -> Optional<Int> {
        switch tape[idx].value {
        case .Value: if idx == wrt { return 1 } else { return nil }
        case let .Add(lhs, rhs):
            switch (gen_graph(lhs, wrt), gen_graph(rhs, wrt)) {
            case let (lhs?, nil): return lhs
            case let (nil, rhs?): return rhs
            case let (lhs?, rhs?): return add_add(lhs, rhs)
            case _: return nil
            }
        case let .Sub(lhs, rhs):
            switch (gen_graph(lhs, wrt), gen_graph(rhs, wrt)) {
            case (lhs?, nil): return lhs
            case (nil, rhs?): return add_neg(rhs)
            case (lhs, rhs?): return add_sub(lhs, rhs)
            case _: return nil
            }
            break
        case let .Mul(lhs, rhs):
            switch (gen_graph(lhs, wrt), gen_graph(rhs, wrt)) {
            case let (dlhs?, nil): return add_mul(dlhs, rhs)
            case let (nil, drhs?): return add_mul(lhs, drhs)
            case let (dlhs?, drhs?):
                let plhs = add_mul(dlhs, rhs)
                let prhs = add_mul(lhs, drhs)
                let node = add_add(plhs, prhs)
                return node
            case _: return nil
            }
            break
        case let .Div(lhs, rhs):
            switch (gen_graph(lhs, wrt), gen_graph(rhs, wrt)) {
            case let (dlhs?, None): return add_div(dlhs, rhs)
            case let (None, drhs?):
                return add_neg(add_div(add_div(add_mul(lhs, drhs), rhs), rhs))
            case let (dlhs?, drhs?):
                let plhs = add_div(dlhs, rhs)
                let prhs = add_div(add_div(add_mul(lhs, drhs), rhs), rhs)
                return add_sub(plhs, prhs)
            case _: return nil
            }
            break
        case let .Neg(term):
            return gen_graph(term, wrt).map({ (node) in add_neg(node) })
        case let .UnaryFn(term, _, _, gg):
            let derived = gen_graph(term, wrt)
            return derived.flatMap({ (derived) in gg(term, idx, derived) })
    }
    return nil
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
    func backward() {
        tape.clear_grad()
        tape.backward_int(idx)
    }
    func gen_graph(_ wrt: TapeTerm) -> TapeTerm? {
        if let x = tape.gen_graph(idx, wrt.idx) {
            return TapeTerm(x, tape)
        } else {
            return nil
        }
    }
    func set(_ val: Double) {
        tape.tape[idx].data = val
        if case let TapeValue.Value(target) = tape.tape[idx].value {
            tape.tape[idx].value = TapeValue.Value(val)
        }
    }
    // func grad(): Option[Double] = tape.terms(idx).grad

    func apply(_ name: String,
        f: @escaping (Double) -> Double,
        g: @escaping (Double) -> Double,
        gg: @escaping (Int, Int, Int) -> Int?) -> TapeTerm
    {
        return TapeTerm(tape.add_unary(name, idx, f: f, g: g, gg: gg), tape)
    }
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

prefix func - (term: TapeTerm) -> TapeTerm {
    let tape = term.tape
    return TapeTerm(tape.add_neg(term.idx), tape)
}

func demo_simple() {
    var tape = Tape()

    let a = tape.value(name: "a", 1)
    let b = tape.value(name: "b", 2)
    let ab = a + b
    let c = tape.value(name: "c", 42)
    let abc = ab * c

    print(ab.eval())
    print(abc.derive(a))

    abc.backward()

    print("Back-propagated:")
    for term in tape.tape {
        print(term)
    }
}

func derive_exp(_ tape: Tape, _ arg: Int, _ out: Int, _ der: Int) -> Int? {
    tape.add_mul(out, der)
}

func demo_gauss() {
    var tape = Tape()

    let x = tape.value(name: "x", 0)
    let sigma = tape.value(name: "sigma", 1)
    let arg = -(x * x / (sigma * sigma))
    let term = arg.apply("exp", f: exp, g: exp, gg: { (arg, out, der) in derive_exp(tape, arg, out, der) })

    let exp_grad = term.gen_graph(x)

    print("Generated derived term:")
    for term in tape.tape {
        print(term)
    }

    for ix in -20...20 {
        let xval = Double(ix) / 10.0
        x.set(xval)
        print("[\(xval), \(term.eval()), \(term.derive(x))],")
    }
}

func demo_higher_order() {
    var tape = Tape()

    let x = tape.value(name: "x", 0)
    let sigma = tape.value(name: "sigma", 1)
    let arg = -(x * x / (sigma * sigma))
    let term = arg.apply("exp", f: exp, g: exp, gg: { (arg, out, der) in derive_exp(tape, arg, out, der) })

    let term_grad = term.gen_graph(x)!
    let term_grad2 = term_grad.gen_graph(x)!

    print("Generated derived term:")
    for term in tape.tape {
        print(term)
    }

    for ix in -20...20 {
        let xval = Double(ix) / 5.0
        x.set(xval)
        print("[\(xval), \(term.eval()), \(term_grad.eval()), \(term_grad2.eval())],")
    }
}

demo_higher_order()
