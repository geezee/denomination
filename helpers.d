import std.conv;


/***
  DSL for specifying methods
****/
struct __Method {
    string name;
    string klass;
    string[] argTypes = [];
    string returnType = "void";
    bool isStatic = false;
}

__Method on(string name, string klass) { return __Method(name, klass); }
__Method args(__Method m, string[] args...) { m.argTypes ~= args; return m; }
__Method returns(__Method m, string rt) { m.returnType = rt; return m; }
__Method statik(__Method m) { m.isStatic = true; return m; }




/***
  DSL for specifying constraints
****/
struct __Cons {
    string name;
    string[] argTypes = [];
    string parent = "";
    string[] parentArgs = [];
    __Method[] _methods = [];
}

__Cons constraint(string name) { return __Cons(name); }
__Cons args(__Cons c, string[] args...) { c.argTypes = args; return c; }
__Cons extends(__Cons c, string p, string[] pa...) { c.parent = p; c.parentArgs = pa; return c; }
__Cons methods(__Cons c, __Method[] ms...) { c._methods = ms; return c; }



/**
  comma seperate an array of elements
*/
string commaSeperate(bool withArgs = false)(string[] elems) {
    if (elems.length == 0) return "";
    string args = "";
    static if (withArgs) {
        foreach (i,a; elems) args ~= a ~ " arg" ~ i.to!string ~ ", ";
    } else {
        foreach (a; elems) args ~= a ~ ", ";
    }
    return args[0..$-2];
}




/**
  Convert a method object to a method signature (string)
*/
string __method_to_d_string(__Method m, string constraintName) {
    return (m.isStatic ? "@(`static`) " : "")
        ~ "@ForConstraint(`" ~ constraintName ~ "`) "
        ~ m.returnType ~ " "
        ~ m.name
        ~ "(" ~ ([m.klass] ~ m.argTypes).commaSeperate!true ~ ");";
}


/**
  Convert a constraint object to an abstract class (string)
*/
string __constraint_to_d_string(__Cons c) {
    string parentArgs = c.parentArgs.commaSeperate;
    string parent = c.parent == "" ? "__Constraint" : (c.parent ~ "!(" ~ parentArgs ~ ")");
    string args = c.argTypes.commaSeperate;
    string impl = "interface " ~ c.name ~ "(" ~ args ~ "): " ~ parent ~ " {\n";
    impl ~= "\tstatic immutable string CONSTRAINT = `" ~ c.name ~ "`;\n";
    foreach (m; c._methods) {
        impl ~= "\t" ~ m.__method_to_d_string(c.name) ~ "\n";
    }
    return impl ~ "}";
}


/**
 Check if an element is in a tuple
*/
bool inTuple(alias element, T...)() {
    static if (T.length == 0) return false;
    else return element == T[0] || inTuple!(element, T[1..$]);
}
