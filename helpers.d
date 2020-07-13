import std.conv;
import std.typecons;
import std.meta;
import std.traits;
import std.string;
import std.algorithm.iteration;


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


struct Generic(string name) {}

template TypeToStringReplaceGenerics(T) {
    alias Template = TemplateOf!T;
    static if (__traits(isSame, Generic, Template)) {
        enum TypeToStringReplaceGenerics = TemplateArgsOf!T[0];
    } else static if (__traits(isSame, void, Template)) {
        enum TypeToStringReplaceGenerics = T.stringof;
    } else {
        enum FullTemplateName = Template.stringof;
        enum TemplateName = FullTemplateName[0..FullTemplateName.indexOf('(')];
        enum TypeToStringReplaceGenerics = TemplateName ~ "!("
            ~ TypeListToStringReplaceGenerics!(TemplateArgsOf!T) ~ ")";
    }
}


template TypeListToStringReplaceGenerics(T...) {
    static if (T.length == 0) {
        enum TypeListToStringReplaceGenerics = "";
    } else static if (T.length == 1) {
        enum TypeListToStringReplaceGenerics = TypeToStringReplaceGenerics!(T[0]);
    } else {
        enum TypeListToStringReplaceGenerics =
            TypeListToStringReplaceGenerics!(T[0])
            ~ ", "
            ~ TypeListToStringReplaceGenerics!(T[1..$]);
    }
}



string WheresAsString(Wheres...)() {
    static if (Wheres.length == 0) return "";
    static if (Wheres.length == 1) {
        static if (TemplateArgsOf!(Wheres[0]).length > 0) {
            return "Where!(" ~ Wheres[0].CONSTRAINT ~ ", "
                ~ TypeListToStringReplaceGenerics!(TemplateArgsOf!(Wheres[0])) ~ ")";
        } else {
            return "Where!(" ~ Wheres[0].CONSTRAINT ~ ")";
        }
        // return "Where!(" ~ TypeToStringReplaceGenerics!(Wheres[0]).tr("!",",") ~  ")";
    } else {
        return WheresAsString!(Wheres[0]) ~ " && " ~ WheresAsString!(Wheres[1..$]);
    }
}


template ConstraintArguments(Constraints...) {
    static if (Constraints.length == 0) {
        alias ConstraintArguments = AliasSeq!();
    } else static if (Constraints.length == 1) {
        alias ConstraintArguments = NoDuplicates!(TemplateArgsOf!Constraints);
    } else {
        alias ConstraintArguments = NoDuplicates!(AliasSeq!(
            ConstraintArguments!(Constraints[0]),
            ConstraintArguments!(Constraints[1])));
    }
}


string[] CollectGenerics(T)() {
    static if (__traits(isSame, void, TemplateOf!T)) {
        return [];
    } else static if (__traits(isSame, Generic, TemplateOf!T)) {
        return [TemplateArgsOf!T[0]];
    } else {
        alias Args = TemplateArgsOf!T;
        static if (Args.length == 0) {
            return [];
        } else {
            return CollectGenerics!(Args[0])
                 ~ CollectGenerics!(Tuple!(Args[1..$]));
        }
    }
}


struct MethodImpl(string name, string impl) {}

string[] CollectGenericsFromConstraints(Constraints...)() {
    string[] generics = [];
    static foreach (C; Constraints) {
        static foreach (T; TemplateArgsOf!C) {
            static if (__traits(isSame, Generic, TemplateOf!T)) {
                generics ~= (TemplateArgsOf!T)[0];
            }
        }
    }
    return generics;
}


bool TypeInList(S, Types...)() {
    static foreach (T; Types) {
        if (__traits(isSame, S, T)) return true;
    }
    return false;
}
