import genusdsl;
import helpers;

mixin Constraint!(
    constraint("Eq")
        .args("T")
        .methods(
            "equals".on("T").args("T").returns("bool")
        ));


mixin Constraint!(
    constraint("Comp")
        .args("T")
        .extends("Eq", "T")
        .methods(
            "compareTo".on("T").args("T").returns("int")
        ));


mixin Constraint!(
    constraint("OrdRing")
        .args("T")
        .extends("Comp", "T")
        .methods(
            "zero".on("T").returns("T").statik,
            "one".on("T").returns("T").statik,
            "plus".on("T").args("T").returns("T"),
            "times".on("T").args("T").returns("T"),
        ));


mixin Constraint!(
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

mixin Constraint!(
    constraint("Weighted")
        .args("T","W")
        .methods(
            "weight".on("T").returns("W")
        ));


class CityMap(V,E,W,VId,EId) {
    E edge(EId id) { return E.init; }
    V vertex(VId id) { return V.init; }
}

class Edge(VId,W) {
    VId start;
    VId end;

    VId source() { return start; }
    VId sink() { return end; }
    W weight() { return W.init; }
}

class Vertex(EId) {
    EId[] outEdges;
    EId[] inEdges;

    EId[] outgoingEdges() { return outEdges; }
    EId[] incomingEdges() { return inEdges; }
}


struct Weight {
    static Weight zero() { return Weight(); }
    static Weight one() { return Weight(); }
    Weight plus(Weight w) { return this; }
    Weight times(Weight w) { return this; }
    int compareTo(Weight w) { return 0; }
    bool equals(Weight w) { return true; }
}



V[] someAlgorithm(G,V,E,W,VId,EId)(G graph)
if (Where!(GraphLike,G,V,E,VId,EId) && Where!(Weighted,E,W) && Where!(OrdRing,W)) {
    return [];
}



T[] sort(T)(T[] lst) if (Where!(Comp, T)) {
    return lst;
}


class List(T) if (Where!(Eq, T)) {
    private T[] members = [];

    void add(T member) {
        static if (CheckWhere!(Comp, T)) {
            addSorted(member);
        } else {
            members ~= member;
        }
    }

    void addSorted()(T member) if (Where!(Comp, T)) {
        members ~= member;
    }
}


struct Point2D {
    immutable int x;
    immutable int y;

    bool equals(Point2D point) {
        return x == point.x && y == point.y;
    }
}

struct Point {
    immutable int x;

    bool equals(Point point) {
        return x == point.x;
    }

    int compareTo(Point point) {
        return x - point.x;
    }
}


void main() {
    sort([Point(1), Point(0)]);

    auto list = new List!Point2D();
    auto orderableList = new List!Point();

    orderableList.addSorted(Point(0));
    static assert(!__traits(compiles, list.addSorted(Point2D(0,0))));

    alias VertexId = uint;
    alias EdgeId = string;

    auto g = new CityMap!(
        Vertex!(EdgeId),
        Edge!(VertexId,Weight),
        Weight,
        VertexId,
        EdgeId);


    someAlgorithm
        !(typeof(g),Vertex!(EdgeId),Edge!(VertexId,Weight),Weight,VertexId,EdgeId)
        (g);
}
