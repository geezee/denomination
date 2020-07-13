# Denomination

Denomination is an experimental (proof of concept) implementation of Genus [1]
in DLang.

Support for (non-default) models is limited and its API is very clunky.


## Defining Constraints

Constraints can be defined as follows:

```d
constraint("Eq")
    .args("T")
    .methods(
        "equals".on("T").args("T").returns("bool"));
```

Constraints can inherit method constraints from other constraints as so:

```d
constraint("Comparable")
    .args("T")
    .extends("Eq", "T")
    .methods(
        "compareTo".on("T").args("T").returns("int"));
```

Constraints can impose the existence of static methods like so:

```d
constraint("Group")
    .args("G")
    .methods(
        "identity".on("G").returns("G").statik,
        "plus".on("G").args("G").returns("G"),
        "inverse".on("G").returns("G"));
```

Constraints can be multi-parameteric:

```d
constraint("GraphLike")
    .args("G", "V", "E", "VId", "EId")
    .methods(
        "outgoingEdges".on("V").returns("EId[]"),
        "incomingEdges".on("V").returns("EId[]"),
        "source".on("E").returns("VId"),
        "sink".on("E").returns("VId"),
        "edge".on("G").args("EId").returns("E"),
        "vertex".on("G").args("VId").returns("V")
    ));
```

## Declaring constraints

Once a constraint is defined, it can be declared by mixing it in using the
`Constraint` mixin-template like so:

```d
mixin Constraint!(
    constraint("Eq")
        .args("T")
        .methods(
            "equals".on("T").args("T").returns("T"));
```

## Using Denomination-Constraints using D-Constraints (An Example)

Employing constraints can be done using D's native support for constraints on
templated function/methods/templates. The two templates to use are `Where` and
`CheckWhere`, the former will halt compilation **with useful error messages** if
the constraint is not satisfied, the latter will just return false.

Here's one cool example:

```d
// if you try to make a set with a type that doesn't implement `equals` then a
// compilation error is produced
class Set(T) if (Where!(Eq, T)) {
    private T[] elements;

    this() {
        elements = [];
    }

    void add(T member) {
        static if (CheckWhere!(Comp, T)) { // here we make the decision to add in order
            pragma(msg, "Will use the sorted version for type ", T);
            addSorted(member);
        } else {
            pragma(msg, "Will use naive version for type ", T);
            foreach (e; elements) if (e.equals(member)) return;
            elements ~= member;
        }
    }

    // if additionally the type implements `compareTo` we will store the
    // elements in a sorted fashion
    private void addSorted()(T member) if (Where!(Comp, T)) {
        if (elements.length == 0) {
            elements ~= member;
            return;
        }
        size_t index(size_t start, size_t end) {
            if (start >= end) return end;
            size_t i = (start + end) / 2;
            T mid = elements[i];
            int diff = member.compareTo(mid);
            if (diff == 0) return -1; // no repeats in a set
            else if (diff < 0) return index(start, i);
            else return index(i+1, end);
        }
        size_t i = index(0, elements.length);
        if (i >= 0) elements = elements[0..i] ~ [member] ~ elements[i..$];
    }

    const(T[]) members() @property {
        return elements;
    }
}

/**
When compiling the following messages are produced:
    Will use naive version for type Point2D
    Will use the sorted version for type Point
*/
unittest {
    import std.stdio;
    auto set1 = new Set!Point2D();
    set1.add(Point2D(0,1));
    set1.add(Point2D(1,0));
    writeln(set1.members); // [const(Point2D)(0, 1), const(Point2D)(1, 0)]

    auto set2 = new Set!Point();
    set2.add(Point(3));
    set2.add(Point(4));
    set2.add(Point(10));
    set2.add(Point(1));
    writeln(set2.members); // [const(Point)(1), const(Point)(3), const(Point)(4), const(Point)(10)]
}
```

## Useful error messages

To demonstrate the error messages this is the program we will try

```d
import genusdsl;
import helpers;

mixin Constraint!(
    constraint("Eq")
        .args("T")
        .methods(
            "equals".on("T").args("T").returns("bool")));

mixin Constraint!(
    constraint("Group")
        .args("G")
        .extends("Eq", "G")
        .methods(
            "identity".on("G").returns("G").statik,
            "plus".on("G").args("G").returns("G"),
            "inverse".on("G").returns("G")));


bool checkIdentityProperties(T)(T elem = T.identity) if (Where!(Group, T)) {
    T id = T.identity;
    return id.equals(id.plus(id))
        && id.equals(id.inverse)
        && id.plus(elem).equals(elem) && elem.plus(id).equals(elem);
}

struct MyData {
    // implementation will be here...
}

void main() {
    import std.stdio;
    writefln("Check passed = %s", checkIdentityProperties!MyData);
}
```

### Missing method

```d
struct MyData {}
```

```
genusdsl.d(69): Error: static assert:  "Constraint Group requires MyData to implement the method identity"
```

### Non-static method should be static
```d
struct MyData {
    bool identity(int data) { return true; }
}
```

```
genusdsl.d(37): Error: static assert:  "Constraint Group(G) requires that identity be static"
```

### Wrong return type
```d
struct MyData {
    static bool identity(int data) { return true; }
}
```

```
genusdsl.d(59): Error: static assert:  "Expected return type of identity to be MyData instead found bool"
```

### Wrong arguments
```d
struct MyData {
    static MyData identity(int data) { return MyData(); }
}
```

```
genusdsl.d(49): Error: static assert:  "Argument mismatch between Group(G)'s identity and MyData's: expected () instead found (int)"
```

### Missing method from super-constraint (parent constraint)
```d
struct MyData {
    static MyData identity() { return MyData(); }
    MyData plus(MyData d) { return this; }
    MyData inverse() { return this; }
}
```

```
genusdsl.d(69): Error: static assert:  "Constraint Eq (from Group) requires MyData to implement the method equals"
```


# Models

## Defining and declaring models

### The simplest model: case insensitive Eq

```d
mixin Model!(
    "StringCaseInsensitiveEq", Tuple!(),
    Tuple!(Eq!MyStr),
    Tuple!(),
    MethodImpl!("equals", q{
        bool equals(MyStr other) {
            return this.contents.toLower == other.contents.toLower;
        }
    }));
```

### More complex example: Array should be cloneable if its contents are

```d
mixin Model!(
    "ArrayListDeepCloneable", Tuple!(Generic!"E"),
    Tuple!(Cloneable!(ArrayList!(Generic!"E"), MyStr)),
    Tuple!(Cloneable!(Generic!"E", MyStr), Eq!MyStr),
    MethodImpl!("clone", q{
        ArrayList!E clone() {
           auto result = new ArrayList!E();
           foreach (m; parent.contents) result.add(m.clone);
           return result;
        }
    }));
```

### Most complex example: The dual of a graph

```d
mixin Model!(
    "DualGraph", Tuple!(Generic!"V", Generic!"E", Generic!"VId", Generic!"EId"),
    Tuple!(GraphLike!(Generic!"V",Generic!"E",Generic!"VId",Generic!"EId")),
    Tuple!(GraphLike!(Generic!"V",Generic!"E",Generic!"VId",Generic!"EId")),
    MethodImpl!("src", q{ override VId src() { return parent.target(); } }),
    MethodImpl!("target", q{ override VId target() { return parent.src(); } }),
    MethodImpl!("outgoing", q{ override EId[] outgoing() { return parent.incoming(); } }),
    MethodImpl!("incoming", q{ override EId[] incoming() { return parent.outgoing(); } }));
```

## Arguments of the `Model` template

The arguments of the `Model` mixin are:

1. The name of the model as a string
2. The generic arguments of the model
3. The constraints that the model is implementing
4. The conditions (i.e. the `where` clauses) that must be satisfied on the model
5. The methods: each method has a name, then its implementation (as a string)

## Using models

By default the model is always the default model, to use a model you must use
the `UseModel` template that introduces (or overrides) the value that implements
the model.

If the constraints of the model depend directly on a generic, eg
`Eq!(Generic!"T")` as opposed to `Eq!(ArrayList!(Generic!"T"))`, then you must
provide explicitly the types to replace the generics.

Hopefully these examples are illustrative:

```d
ArrayList!E doClone(E)(ArrayList!E lst) {
    mixin UseModel!("lst", lst, ArrayListDeepCloneable!());
    return lst.clone(); // lst now satisfies ArrayListDeepCloneable
}
```

```d
void useBothGraphAndItsDual(V,E,VId,EId)(V vertex, E edge)
if (Where!(GraphLike,V,E,VId,EId)) {
    writefln("The incoming and outgoing of `vertex` are: %s and %s",
        vertex.incoming(), vertex.outgoing());
    writefln("The src and target of `edge` are: %s and %s",
        edge.src(), edge.target());

    // dualVertex is the vertex described by the `V` generic in the `DualGraph` model
    mixin UseModel!("dualVertex", vertex, DualGraph!(V, E, VId, EId), "V");
    // dualEdge is the edge described by the `E` generic in the `DualGraph` model
    mixin UseModel!("dualEdge", edge, DualGraph!(V, E, VId, EId), "E");

    writefln("[dual] The incoming and outgoing of `vertex` are: %s and %s",
        dualVertex.incoming(), dualVertex.outgoing());
    writefln("[dual] The src and target of `edge` are: %s and %s",
        dualEdge.src(), dualEdge.target());

    mixin UseModel!("ddualVertex", dualVertex, DualGraph!(V, E, VId, EId), "V");
    mixin UseModel!("ddualEdge", dualEdge, DualGraph!(V, E, VId, EId), "E");

    writefln("[dual-dual] The incoming and outgoing of `vertex` are: %s and %s",
        ddualVertex.incoming(), ddualVertex.outgoing());
    writefln("[dual-dual] The src and target of `edge` are: %s and %s",
        ddualEdge.src(), ddualEdge.target());
}


alias VertexId = uint;
alias EdgeId = string;
class Vertex {
    EdgeId[] incoming() { return ["i1", "i2"]; }
    EdgeId[] outgoing() { return ["o1", "o2"]; }
}
class Edge {
    VertexId src() { return 0; }
    VertexId target() { return 1; }
}

useBothGraphAndItsDual
    !(Vertex,Edge,VertexId,EdgeId)
    (new Vertex(), new Edge());

/* OUTPUT IS:
The incoming and outgoing of `vertex` are: ["i1", "i2"] and ["o1", "o2"]
The src and target of `edge` are: 0 and 1
[dual] The incoming and outgoing of `vertex` are: ["o1", "o2"] and ["i1", "i2"]
[dual] The src and target of `edge` are: 1 and 0
[dual-dual] The incoming and outgoing of `vertex` are: ["i1", "i2"] and ["o1", "o2"]
[dual-dual] The src and target of `edge` are: 0 and 1
*/
```


# References

[1] : The whitepaper for Genus can be found at https://www.semanticscholar.org/paper/a1d0c109155a9040f6b24355806f123744f3c841
