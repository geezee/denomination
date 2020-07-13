import std.traits;
import std.meta;
import std.algorithm.iteration;
import std.array;
import std.string;

import helpers;


struct ForConstraint { string constraintName; }

interface __Constraint {}

mixin template Constraint(__Cons c) {
    mixin(c.__constraint_to_d_string);
}


bool checkValidity(alias Constraint, string method, bool showMessages = false, Args...)() {
    alias TIN = Instantiate!(Constraint, Args);
    alias Method = __traits(getMember, TIN, method);
    static if (!isCallable!Method) {
        return true;
    } else {
        alias ExpectedReturnType = ReturnType!Method;
        alias CompleteExpectedParameterTypes = Parameters!Method;
        alias ExpectedParameterTypes = CompleteExpectedParameterTypes[1..$];
        alias ConstraintClass = CompleteExpectedParameterTypes[0];

        enum isStatic = getUDAs!(Method, "static").length == 1;
        enum methodConstraintSource = getUDAs!(Method, ForConstraint)[0].constraintName;
        enum constraintName = TIN.CONSTRAINT;

        static if (inTuple!(method, __traits(allMembers, ConstraintClass))) {
            alias ConstraintMethod = __traits(getMember, ConstraintClass, method);
            static if (isStatic && !__traits(isStaticFunction, ConstraintMethod)) {
                static if (showMessages) {
                    static assert(false,
                        "Constraint " ~ Constraint.stringof ~ " requires that "
                        ~ method ~ " be static");
                }
            } else {
                alias ActualReturnType = ReturnType!ConstraintMethod;
                static if (is(ActualReturnType == ExpectedReturnType)) {
                    alias ActualParameterTypes = Parameters!ConstraintMethod;
                    static if (is(ActualParameterTypes == ExpectedParameterTypes)) {
                        return true;
                    } else {
                        static if (showMessages) {
                            static assert(false,
                                    "Argument mismatch between " ~ Constraint.stringof ~ "'s " ~ method
                                    ~ " and " ~ ConstraintClass.stringof ~ "'s: "
                                    ~ "expected " ~ ExpectedParameterTypes.stringof
                                    ~ " instead found "
                                    ~ ActualParameterTypes.stringof);
                        }
                    }
                } else {
                    static if (showMessages) {
                        static assert(false,
                                "Expected return type of " ~ method ~ " to be "
                                ~ ExpectedReturnType.stringof
                                ~ " instead found "
                                ~ ActualReturnType.stringof);
                    }
                }
            }
        } else {
            static if (showMessages) {
                static assert(false,
                        "Constraint " ~ methodConstraintSource
                        ~ (methodConstraintSource == constraintName ? "" : " (from " ~ constraintName ~ ")")
                        ~ " requires " ~ ConstraintClass.stringof
                        ~ " to implement the method " ~ method);
            }
        }
        return false;
    }
}


template Where(alias constraint, Args...) {
    enum Where = SatisfiesConstraint!(true, constraint, Args);
}


template CheckWhere(alias constraint, Args...) {
    enum CheckWhere = SatisfiesConstraint!(false, constraint, Args);
}


template SatisfiesConstraint(bool showMessages, alias constraint, Args...) {
    alias objectMethods = __traits(allMembers, Object);
    static foreach (method; __traits(allMembers, constraint!Args)) {
        static if (!__traits(compiles, SatisfiesConstraint == false) // reason: we cannot break out of a static-foreach
                   && !inTuple!(method, objectMethods) // reason: method is not one of Object's
                   && !checkValidity!(constraint, method, showMessages, Args)) {
            enum SatisfiesConstraint = false;
        }
    }
    static if (!__traits(compiles, SatisfiesConstraint == false)) { // refer to previous comment
        enum SatisfiesConstraint = true;
    } else {
    }
}

string generateModelCode(string mname, ModelArgs, Constraints, Wheres, Methods...)() {
    alias TypesToExtend = ConstraintArguments!(TemplateArgsOf!Constraints);
    enum Generics = CollectGenericsFromConstraints!(TemplateArgsOf!Constraints);
    string output = "template " ~ mname ~ "(" ~ Generics.commaSeperate ~ ") {\n";
    output ~= "enum NAME = `" ~ mname ~ "`;\n";
    static foreach (Type; TypesToExtend) {
        output ~= ModelToClass!(mname, Type, Constraints, Wheres, Methods) ~ "\n";
    }
    return output ~= "\n}";
}

mixin template Model(string mname, ModelArgs, alias Constraints, alias Wheres, Methods...) {
    enum code = generateModelCode!(mname, ModelArgs, Constraints, Wheres, Methods);
    mixin(code);
}

template ApplicableWhere(alias Type) {
    import std.algorithm.searching : countUntil;
    enum TypeGenerics = CollectGenerics!Type;
    bool test(alias Where)() {
        enum WhereGenerics = CollectGenerics!Where;
        static foreach (g; WhereGenerics) {
            if (TypeGenerics.countUntil(g) == -1) return false;
        }
        return true;
    }
}

bool MethodApplicable(alias MethodImpl, alias Constraints, alias Type)() {
    import std.traits;
    enum methodName = TemplateArgsOf!MethodImpl[0];
    static foreach (Constraint; TemplateArgsOf!Constraints) {
        alias Method = __traits(getMember, Constraint, methodName);
        alias TargetClass = Parameters!Method[0];
        if (!is(Type == TargetClass)) return false;
    }
    return true;
}

string ModelToClass(string mname, alias Type, alias Constraints, alias Wheres, Methods...)() {
    enum TypeName = TypeToStringReplaceGenerics!Type;
    enum ExclMark = TypeName.indexOf('!');
    enum ClassName = (ExclMark > 0) ? TypeName[0..ExclMark] ~ TypeName[ExclMark+1..$]
                                    : TypeName ~ "()";
    alias ApplicableWheres = Filter!(ApplicableWhere!Type.test, TemplateArgsOf!Wheres);

    string bdy = TypeName ~ " parent; "
               ~ "this(" ~ TypeName ~ " member) {
                    import std.traits;
                    alias TN = " ~ TypeName ~ ";
                    // Call the right constructor
                    static if (__traits(hasMember, TN, `__ctor`)) {
                        alias SuperArgs = Parameters!(TN.__ctor);
                        static if (SuperArgs.length > 0)
                            super(Tuple!SuperArgs().expand);
                    }
                    // Copy all the properties
                    static foreach (m; FieldNameTuple!TN)
                        mixin(`this.` ~ m ~ ` = member.` ~ m ~ `;`);
                    this.parent = member;
                  }";

    static foreach (Method; Methods)
        static if (MethodApplicable!(Method,Constraints,Type))
            bdy ~= TemplateArgsOf!Method[1];

    static if (ApplicableWheres.length > 0) {
        return "class " ~ mname ~ "_" ~ ClassName ~ ": " ~ TypeName
             ~ " if (" ~  WheresAsString!ApplicableWheres ~ ") {\n"
             ~ bdy ~ "\n}";
    } else {
        return "class " ~ mname ~ "_" ~ ClassName ~ ": " ~ TypeName ~ " {\n" ~ bdy ~ "\n}";
    }
}


mixin template UseModel(alias dest, alias src, alias Model, string generic="") {
    import std.traits;
    enum Class = generic.length == 0 ? typeof(src).stringof : generic ~ "!()";
    enum code = "auto " ~ dest ~ " = new " ~ Model.stringof ~ "." ~ Model.NAME ~ "_"
    ~ Class ~ "(src);";
    mixin(code);
}
