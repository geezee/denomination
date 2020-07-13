import std.ascii;
import std.typecons;

import genusdsl;
import helpers;


mixin Constraint!(
    constraint("Eq")
        .args("T")
        .methods(
            "equals".on("T").args("T").returns("bool")));

mixin Constraint!(
    constraint("GraphLike")
        .args("V", "E", "VId", "EId")
        .methods(
            "src".on("E").returns("VId"),
            "target".on("E").returns("VId"),
            "outgoing".on("V").returns("EId[]"),
            "incoming".on("V").returns("EId[]")
        ));


mixin Constraint!(
    constraint("Cloneable")
        .args("T", "U") // U for useless
        .methods(
            "clone".on("T").returns("T")));


struct MyStr {
    private string data;
    bool equals(MyStr o) { return data == o.data; }
    const(string) contents() @property { return data; }
    MyStr clone() { return MyStr(data); }
}

class ArrayList(E) {
    private E[] members = [];
    this() {}
    void add(E m) { members ~= m; }
    E[] contents() @property { return members; }
}


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



mixin Model!(
    "DualGraph", Tuple!(Generic!"V", Generic!"E", Generic!"VId", Generic!"EId"),
    Tuple!(GraphLike!(Generic!"V",Generic!"E",Generic!"VId",Generic!"EId")),
    Tuple!(GraphLike!(Generic!"V",Generic!"E",Generic!"VId",Generic!"EId")),
    MethodImpl!("src", q{ override VId src() { return parent.target(); } }),
    MethodImpl!("target", q{ override VId target() { return parent.src(); } }),
    MethodImpl!("outgoing", q{ override EId[] outgoing() { return parent.incoming(); } }),
    MethodImpl!("incoming", q{ override EId[] incoming() { return parent.outgoing(); } }));




void checkEq(E)() if (Where!(Eq, E)) {}

ArrayList!E checkClone(E)(ArrayList!E lst) {
    mixin UseModel!("lst", lst, ArrayListDeepCloneable!());
    return lst.clone();
}


void useBothGraphAndItsDual(V,E,VId,EId)(V vertex, E edge)
if (Where!(GraphLike,V,E,VId,EId)) {
    import std.stdio;
    writefln("The incoming and outgoing of `vertex` are: %s and %s",
        vertex.incoming(), vertex.outgoing());
    writefln("The src and target of `edge` are: %s and %s",
        edge.src(), edge.target());

    mixin UseModel!("dualVertex", vertex, DualGraph!(V, E, VId, EId), "V");
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

    vertex.vertexSpecific();
    dualVertex.vertexSpecific();
    ddualVertex.vertexSpecific();
}

alias VertexId = uint, EdgeId = string;
class Vertex {
    private int n = 0;
    this(int n) { this.n = n; }
    EdgeId[] incoming() { return ["i1", "i2"]; }
    EdgeId[] outgoing() { return ["o1", "o2"]; }
    void vertexSpecific() {
        import std.stdio;
        writefln("%d = %s", this.n, this.incoming());
    }
}
class Edge {
    VertexId src() { return 0; }
    VertexId target() { return 1; }
}


void main() {
    checkEq!MyStr;

    import std.stdio;
    auto lst = new ArrayList!MyStr();
    lst.add(MyStr("hello"));
    lst.add(MyStr("world"));
    checkClone!MyStr(lst).members.writeln;

    useBothGraphAndItsDual!(Vertex,Edge,VertexId,EdgeId)
        (new Vertex(10), new Edge());
}
