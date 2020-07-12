import std.traits;
import std.meta;
import std.algorithm.iteration;
import std.array;

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
