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
    var terms: [TapeNode] = []

    var count: Int {
        get { terms.count }
    }

    func value(name: String, _ val: Double) -> TapeTerm {
        let ret = terms.count
        terms.append(TapeNode(
            name: name,
            value: TapeValue.Value(val)
        ))
        return TapeTerm(ret, self)
    }

    func add_add(_ lhs: Int, _ rhs: Int) -> Int {
        let ret = terms.count
        terms.append(TapeNode(
            name: terms[lhs].name + " + " + terms[rhs].name,
            value: TapeValue.Add(lhs, rhs)
        ))
        return ret
    }

    func add_sub(_ lhs: Int, _ rhs: Int) -> Int {
        let ret = terms.count
        terms.append(TapeNode(
            name: terms[lhs].name + " - " + terms[rhs].name,
            value: TapeValue.Sub(lhs, rhs)
        ))
        return ret
    }

    func add_mul(_ lhs: Int, _ rhs: Int) -> Int {
        let ret = terms.count
        terms.append(TapeNode(
            name: terms[lhs].name + " * " + terms[rhs].name,
            value: TapeValue.Mul(lhs, rhs)
        ))
        return ret
    }

    func add_div(_ lhs: Int, _ rhs: Int) -> Int {
        let ret = terms.count
        terms.append(TapeNode(
            name: terms[lhs].name + " / " + terms[rhs].name,
            value: TapeValue.Div(lhs, rhs)
        ))
        return ret
    }

    func add_neg(_ term: Int) -> Int {
        let ret = terms.count
        terms.append(TapeNode(
            name: "-" + terms[term].name,
            value: TapeValue.Neg(term)
        ))
        return ret
    }

    func add_unary(_ name: String, _ term: Int,
        f: @escaping (Double) -> Double,
        g: @escaping (Double) -> Double,
        gg: @escaping (Int, Int, Int) -> Int?) -> Int
    {
        let ret = terms.count
        terms.append(TapeNode(
            name: name + "(" + terms[term].name + ")",
            value: TapeValue.UnaryFn(term, f, g, gg)
        ))
        return ret
    }

    func eval_int(_ term: Int) -> Double {
        let node = terms[term]
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
        let node = terms[term]
        switch node.value {
            case .Value: if term == wrt {
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
        for i in 0..<terms.count {
            terms[i].grad = nil
        }
    }

    func backward_int(_ term: Int) {
        terms[term].grad = 1
        for i in (1..<terms.count).reversed() {
            backward_node(i)
        }
    }

    // Since swift doesn't allow simultaneous access to an array,
    // we cannot use `inout TapeNode` as the argument, because it will
    // borrow the reference to the whole terms for the entirety of this function,
    // making us unable to update another node.
    // Unfortunately it will be a cryptic runtime error, not a compile time one,
    // which is why I leave the comment here.
    // We need to access an element of the array like `terms[idx].grad`
    // every time.
    // Probably TapeNode is supposed to be a class in swift philosophy, but I
    // want it be a flat array without indirection.
    func backward_node(_ idx: Int) {
        switch terms[idx].value {
        case .Value:
            break
        case let .Add(lhs, rhs):
            let grad = terms[idx].grad
            if let grad {
                terms[lhs].grad = grad
                terms[rhs].grad = grad
            }
        case let .Sub(lhs, rhs):
            if let grad = terms[idx].grad {
                terms[lhs].grad = grad
                terms[rhs].grad = -grad
            }
        case let .Mul(lhs, rhs):
            if let grad = terms[idx].grad {
                terms[lhs].grad = grad * eval_int(rhs)
                terms[rhs].grad = grad * eval_int(lhs)
            }
        case let .Div(lhs, rhs):
            if let grad = terms[idx].grad {
                let lhsv = eval_int(lhs)
                let rhsv = eval_int(rhs)
                terms[lhs].grad = grad / rhsv
                terms[rhs].grad = -lhsv * grad / rhsv / rhsv
            }
        case let .Neg(term):
            if let grad = terms[idx].grad {
                terms[term].grad = -grad
            }
        case let .UnaryFn(term, _, g, _):
            if let grad = terms[idx].grad {
                terms[term].grad = g(grad)
            }
        }
    }

    func gen_graph(_ idx: Int, _ wrt: Int) -> Optional<Int> {
        switch terms[idx].value {
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
        case let .Div(lhs, rhs):
            switch (gen_graph(lhs, wrt), gen_graph(rhs, wrt)) {
            case let (dlhs?, nil): return add_div(dlhs, rhs)
            case let (nil, drhs?):
                return add_neg(add_div(add_div(add_mul(lhs, drhs), rhs), rhs))
            case let (dlhs?, drhs?):
                let plhs = add_div(dlhs, rhs)
                let prhs = add_div(add_div(add_mul(lhs, drhs), rhs), rhs)
                return add_sub(plhs, prhs)
            case _: return nil
            }
        case let .Neg(term):
            return gen_graph(term, wrt).map({ (node) in add_neg(node) })
        case let .UnaryFn(term, _, _, gg):
            let derived = gen_graph(term, wrt)
            return derived.flatMap({ (derived) in gg(term, idx, derived) })
        }
    }

    func dot() -> String {
        var ret = "digraph D {\n\tnode[style=filled fillcolor=\"#7fff7f\"];\n"
        for (i, node) in terms.enumerated() {
            ret += "a\(i) [label=\"\(node.name)\", shape=rect];\n"
        }
        for (i, node) in terms.enumerated() {
            switch node.value {
            case .Value:
                break
            case let .Add(lhs, rhs): ret += "a\(lhs) -> a\(i);\na\(rhs) -> a\(i);\n"
            case let .Sub(lhs, rhs): ret += "a\(lhs) -> a\(i);\na\(rhs) -> a\(i);\n"
            case let .Mul(lhs, rhs): ret += "a\(lhs) -> a\(i);\na\(rhs) -> a\(i);\n"
            case let .Div(lhs, rhs): ret += "a\(lhs) -> a\(i);\na\(rhs) -> a\(i);\n"
            case let .Neg(term): ret += "a\(term) -> a\(i);\n"
            case let .UnaryFn(term, _, _, _): ret += "a\(term) -> a\(i);\n"
            }
        }
        ret += "}\n"
        return ret
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
        tape.terms[idx].data = val
        if case TapeValue.Value = tape.terms[idx].value {
            tape.terms[idx].value = TapeValue.Value(val)
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
    let tape = Tape()

    let a = tape.value(name: "a", 1)
    let b = tape.value(name: "b", 2)
    let ab = a + b
    let c = tape.value(name: "c", 42)
    let abc = ab * c

    print(ab.eval())
    print(abc.derive(a))

    abc.backward()

    print("Back-propagated:")
    for term in tape.terms {
        print(term)
    }
}

func derive_exp(_ tape: Tape, _ arg: Int, _ out: Int, _ der: Int) -> Int? {
    tape.add_mul(out, der)
}

func demo_gauss() {
    let tape = Tape()

    let x = tape.value(name: "x", 0)
    let sigma = tape.value(name: "sigma", 1)
    let arg = -(x * x / (sigma * sigma))
    let term = arg.apply("exp", f: exp, g: exp, gg: { (arg, out, der) in derive_exp(tape, arg, out, der) })

    print("Generated derived term:")
    for term in tape.terms {
        print(term)
    }

    for ix in -20...20 {
        let xval = Double(ix) / 10.0
        x.set(xval)
        print("[\(xval), \(term.eval()), \(term.derive(x))],")
    }
}

func demo_sin() {
    let tape = Tape()
    let x = tape.value(name: "x", 0)
    let x2 = x * x
    func derive_sin(_ arg: Int, _ out: Int, _ der: Int) -> Int? {
        return tape.add_unary("sin", arg, f: sin, g: cos, gg: derive_sin)
    }
    let sin_x2 = x2.apply("sin", f: sin, g: cos, gg: derive_sin)
    for i in -50...50 {
        let xval = Double(i) / 10.0
        x.set(xval)
        print("[\(xval), \(sin_x2.eval()), \(sin_x2.derive(x))],")
    }
}

func demo_higher_order() {
    let tape = Tape()

    let x = tape.value(name: "x", 0)
    let sigma = tape.value(name: "sigma", 1)
    let arg = -(x * x / (sigma * sigma))
    let term = arg.apply("exp", f: exp, g: exp, gg: { (arg, out, der) in derive_exp(tape, arg, out, der) })

    let term_grad = term.gen_graph(x)!
    let term_grad2 = term_grad.gen_graph(x)!

    print("Generated derived term:")
    for term in tape.terms {
        print(term)
    }

    for ix in -20...20 {
        let xval = Double(ix) / 5.0
        x.set(xval)
        print("[\(xval), \(term.eval()), \(term_grad.eval()), \(term_grad2.eval())],")
    }

    let text = tape.dot()
    do {
        try text.write(toFile: "graph.dot", atomically: true, encoding: .utf8)
    } catch {
        print("Failed to write to graph.dot")
    }
}

demo_higher_order()
