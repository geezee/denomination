# Denomination

Denomination is an experimental implementation of Genus [1] in the DLang.

At the moment only constraints are supported, the only models used are the
default models.


# Defining Constraints

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

# Declaring constraints

Once a constraint is defined, it can be declared by mixing it in using the
`Constraint` mixin-template like so:

```d
mixin Constraint!(
    constraint("Eq")
        .args("T")
        .methods(
            "equals".on("T").args("T").returns("T"));
```

# Using Denomination-Constraints using D-Constraints

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
        import std.stdio;
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


[1] : The whitepaper for Genus can be found at https://www.semanticscholar.org/paper/a1d0c109155a9040f6b24355806f123744f3c841
