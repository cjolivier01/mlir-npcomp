//===- BasicpyOps.td - Basic Python ops --------------------*- tablegen -*-===//
//
// This file is licensed under the Apache License v2.0 with LLVM Exceptions.
// See https://llvm.org/LICENSE.txt for license information.
// SPDX-License-Identifier: Apache-2.0 WITH LLVM-exception
//
//===----------------------------------------------------------------------===//

#ifndef NPCOMP_DIALECT_BASICPY_IR_BASICPY_OPS
#define NPCOMP_DIALECT_BASICPY_IR_BASICPY_OPS

include "npcomp/Dialect/Basicpy/IR/BasicpyDialect.td"
include "mlir/Interfaces/CallInterfaces.td"
include "mlir/Interfaces/ControlFlowInterfaces.td"
include "mlir/Interfaces/SideEffectInterfaces.td"
include "mlir/IR/OpAsmInterface.td"
include "mlir/IR/SymbolInterfaces.td"

//===----------------------------------------------------------------------===//
// Predicates
//===----------------------------------------------------------------------===//

def BoolOrI1Type : AnyTypeOf<[Basicpy_BoolType, I1], "Python bool or i1">;

//===----------------------------------------------------------------------===//
// Binary operation enum
// The name matches the operation name in the python AST ("Add", "Mult", etc).
//===----------------------------------------------------------------------===//

def BINOP_ADD      : StrEnumAttrCase<"Add">;
def BINOP_BITAND   : StrEnumAttrCase<"BitAnd">;
def BINOP_BITOR    : StrEnumAttrCase<"BitOr">;
def BINOP_BITXOR   : StrEnumAttrCase<"BitXor">;
def BINOP_DIV      : StrEnumAttrCase<"Div">;
def BINOP_FLOORDIV : StrEnumAttrCase<"FloorDiv">;
def BINOP_LSHIFT   : StrEnumAttrCase<"LShift">;
def BINOP_MATMULT  : StrEnumAttrCase<"MatMult">;
def BINOP_MOD      : StrEnumAttrCase<"Mod">;
def BINOP_MULT     : StrEnumAttrCase<"Mult">;
def BINOP_RSHIFT   : StrEnumAttrCase<"RShift">;
def BINOP_SUB      : StrEnumAttrCase<"Sub">;

def BinaryOperationAttr : StrEnumAttr<
    "BinaryOperation", "Operation for a binary expression", [
      BINOP_ADD,
      BINOP_BITAND,
      BINOP_BITOR,
      BINOP_BITXOR,
      BINOP_DIV,
      BINOP_FLOORDIV,
      BINOP_LSHIFT,
      BINOP_MATMULT,
      BINOP_MOD,
      BINOP_MULT,
      BINOP_RSHIFT,
      BINOP_SUB,
    ]> {
  let cppNamespace = "::mlir::NPCOMP::Basicpy";
}

//===----------------------------------------------------------------------===//
// Comparison operation enum
// The name matches the operation name in the python AST ("Lt", "Gt", etc).
//===----------------------------------------------------------------------===//

def CMPOP_EQ      : StrEnumAttrCase<"Eq">;
def CMPOP_GT      : StrEnumAttrCase<"Gt">;
def CMPOP_GTE     : StrEnumAttrCase<"GtE">;
def CMPOP_IN      : StrEnumAttrCase<"In">;
def CMPOP_IS      : StrEnumAttrCase<"Is">;
def CMPOP_ISNOT   : StrEnumAttrCase<"IsNot">;
def CMPOP_LT      : StrEnumAttrCase<"Lt">;
def CMPOP_LTE     : StrEnumAttrCase<"LtE">;
def CMPOP_NEQ     : StrEnumAttrCase<"NotEq">;
def CMPOP_NOTIN   : StrEnumAttrCase<"NotIn">;

def CompareOperationAttr : StrEnumAttr<
    "CompareOperation", "Comparison operator", [
      CMPOP_EQ,
      CMPOP_GT,
      CMPOP_GTE,
      CMPOP_IN,
      CMPOP_IS,
      CMPOP_ISNOT,
      CMPOP_LT,
      CMPOP_LTE,
      CMPOP_NEQ,
      CMPOP_NOTIN,
    ]> {
  let cppNamespace = "::mlir::NPCOMP::Basicpy";
}

//===----------------------------------------------------------------------===//
// Constant and constructor operations
//===----------------------------------------------------------------------===//

def Basicpy_NumericConstantOp : Basicpy_Op<"numeric_constant", [
    ConstantLike, NoSideEffect, DeclareOpInterfaceMethods<OpAsmOpInterface>]> {
  let summary = "A constant from the Python3 numeric type hierarchy";
  let description = [{
    Basicpy re-uses core MLIR types to represent the Python3 numeric type
    hierarchy with the following mappings:

    * Python3 `int` : In python, this type is signed, arbitrary precision but
      in typical realizations, it maps to an MLIR `IntegerType` of a fixed
      bit-width (typically si64 if no further information is known). In the
      future, there may be a real `Basicpy::IntType` that retains the true
      arbitrary precision nature, but this is deemed an enhancement that
      does not obviate the need to infer physical, sized types for many
      real-world cases. As such, the Basicpy numeric type hierarchy will
      always include physical `IntegerType`, if only to enable progressive
      lowering and interop with cases where the precise type is known.
    * Python3 `float` : This is allowed to map to any legal floating point
      type on the physical machine and is usually represented as a double (f64).
      In MLIR, any `FloatType` is allowed, which facilitates progressive
      lowering and interop with cases where a more precise type is known.
    * Python3 `complex` : Maps to an MLIR `ComplexType` with a `FloatType`
      elementType (note: in Python, complex numbers are always defined with
      floating point components).
    * `bool` : See `bool_constant` for a constant (i1) -> !basicpy.BoolType
      constant. This constant op is not used for representing such bool
      values, even though from the Python perspective, bool is part of the
      numeric hierarchy (the distinction is really only necessary during
      promotion).

    ### Integer Signedness

    All `int` values in Python are signed. However, there exist special cases
    where libraries (i.e. struct packing and numpy arrays) interoperate with
    unsigned values. As such, when mapping to MLIR, Python integer types
    are represented as either signed or unsigned `IntegerType` types and can
    be lowered to signless integers as appropriate (typically during realization
    of arithmetic expressions where the choice is meaningful). Since it is not
    known at the outset when in lowering this information is safe to discard
    this `numeric_constant` op accepts any signedness.
  }];

  let arguments = (ins AnyAttr:$value);
  let results = (outs AnyType);
  let hasFolder = 1;
}

def Basicpy_BoolConstantOp : Basicpy_Op<"bool_constant", [
    ConstantLike, NoSideEffect, DeclareOpInterfaceMethods<OpAsmOpInterface>]> {
  let summary = "A boolean constant";
  let description = [{
    A constant of type !basicpy.BoolType that can take either an i1 value
    of 0 (False) or 1 (True).

    Note that as in Python a BoolType can be thought of as an object, whereas
    the corresponding i1 is a numeric type suitable for use in contexts where
    storage format matters (or for interop with lower level dialects).
  }];
  let arguments = (ins I1Attr:$value);
  let results = (outs
    Basicpy_BoolType:$result
  );
  let assemblyFormat = "$value attr-dict";
  let hasFolder = 1;
}

// TODO: Implement ConstantLike op trait.
def Basicpy_BuildDictOp : Basicpy_Op<"build_dict", [NoSideEffect]> {
  let summary = "Builds an empty dict";
  let description = [{
    This op mirrors the CPython BUILD_MAP op (note naming difference).

    Note that as with CPython, this op only builds an empty dict; however,
    it is reserved in the future for it to take variadic operands to construct
    with a list of key/value pairs.
  }];
  let arguments = (ins
  );
  let results = (outs
    Basicpy_DictType:$result
  );
  let assemblyFormat = "attr-dict `:` functional-type(operands, results)";
}

// TODO: Implement ConstantLike op trait.
def Basicpy_BuildListOp : Basicpy_Op<"build_list", [NoSideEffect]> {
  let summary = "Builds a list from operands";
  let description = [{
    Constructs a new list object from its operands.

    TODO: Any allowable type can be expressed in lists; however, this should be
    revisited once more of the dialect infrastructure is in place and tightened
    up accordingly. At that time, appropriate constraints should be added that
    both allow correct program representation and support transformations to
    lower levels (i.e. allowing a wider set of types as useful for conversions).
  }];
  let arguments = (ins
    Variadic<AnyType>:$elements
  );
  let results = (outs
    Basicpy_ListType:$result
  );
  let assemblyFormat = "operands attr-dict `:` functional-type(operands, results)";
}

// TODO: Implement ConstantLike op trait.
def Basicpy_BuildTupleOp : Basicpy_Op<"build_tuple", [NoSideEffect]> {
  let summary = "Builds a tuple from operands";
  let description = [{
    Constructs a new tuple object from its operands.

    TODO: Any allowable type can be expressed in lists; however, this should be
    revisited once more of the dialect infrastructure is in place and tightened
    up accordingly. At that time, appropriate constraints should be added that
    both allow correct program representation and support transformations to
    lower levels (i.e. allowing a wider set of types as useful for conversions).
  }];
  let arguments = (ins
    Variadic<AnyType>:$elements
  );
  let results = (outs
    Basicpy_TupleType:$result
  );
  let assemblyFormat = "operands attr-dict `:` functional-type(operands, results)";
}

def Basicpy_BytesConstantOp : Basicpy_Op<"bytes_constant", [
    ConstantLike, NoSideEffect, DeclareOpInterfaceMethods<OpAsmOpInterface>]> {
  let summary = "Constant bytes value";
  let description = [{
    A bytes value of BytesType. The value is represented by a StringAttr.
  }];
  let arguments = (ins
    StrAttr:$value
  );
  let results = (outs
    Basicpy_BytesType:$result
  );
  let assemblyFormat = "$value attr-dict";
  let hasFolder = 1;
}

def Basicpy_SingletonOp : Basicpy_Op<"singleton", [
    ConstantLike, NoSideEffect]> {
  let summary = "Constant value for a singleton type";
  let description = [{
    Some types only have a single possible value, represented by the
    SingletonAttr. This op allows creating constants of these types.
  }];
  let arguments = (ins);
  let results = (outs
    Basicpy_SingletonType:$result
  );
  let assemblyFormat = "attr-dict `:` type($result)";
  let hasFolder = 1;
}

def Basicpy_StrConstantOp : Basicpy_Op<"str_constant", [
    ConstantLike, NoSideEffect, DeclareOpInterfaceMethods<OpAsmOpInterface>]> {
  let summary = "Constant string value";
  let description = [{
    A string value of StrType. The value is represented by a StringAttr
    that is UTF-8 encoded.
  }];
  let arguments = (ins
    StrAttr:$value
  );
  let results = (outs
    Basicpy_StrType:$result
  );
  let assemblyFormat = "$value attr-dict";
  let hasFolder = 1;
}

//===----------------------------------------------------------------------===//
// Casting and coercion operations
//===----------------------------------------------------------------------===//

def Basicpy_AsI1Op : Basicpy_Op<"as_i1",
    [NoSideEffect]> {
  let summary = "Evaluates an input to an i1 predicate value";
  let description = [{
    Applies the rules for interpreting a type as a boolean, returning an i1
    indicating the truthiness of the operand. Since the output of this op
    is intended to drive lower-level control flow, the i1 type is used (not
    the user level BoolType).
  }];
  let arguments = (ins AnyType:$operand);
  let results = (outs I1:$result);
  let assemblyFormat = "$operand attr-dict `:` type($operand)";
}

def Basicpy_BoolCastOp : Basicpy_Op<"bool_cast", [NoSideEffect]> {
  let summary = "Casts between BoolType and i1 (predicate value)";
  let description = [{
    When interfacing with lower level dialect or progressively lowering
    the Python BoolType away, it is often necessary to cast between it and
    i1, which is used to represent bool-ness at lower levels.
  }];
  let arguments = (ins BoolOrI1Type:$operand);
  let results = (outs BoolOrI1Type:$result);
  let assemblyFormat = "$operand attr-dict `:` type(operands) `->` type(results)";
}

def Basicpy_UnknownCastOp : Basicpy_Op<"unknown_cast", [NoSideEffect]> {
  let summary = "Casts to and from the UnknownType";
  let arguments = (ins AnyType:$operand);
  let results = (outs AnyType:$result);
  let assemblyFormat = "operands attr-dict `:` type(operands) `->` type(results)";

  let hasCanonicalizer = 1;
}

//===----------------------------------------------------------------------===//
// Operations
//===----------------------------------------------------------------------===//

def Basicpy_BinaryCompareOp : Basicpy_Op<"binary_compare", []> {
  let summary = "Performs a comparison between two operands";
  let description = [{
    This op performs only one step of a potentially multi-step short
    circuit comparison.
    See: https://docs.python.org/3/reference/expressions.html#comparisons
  }];
  let arguments = (ins
    AnyType:$left,
    AnyType:$right,
    CompareOperationAttr:$operation
  );
  let results = (outs
    Basicpy_BoolType:$result
  );
  let assemblyFormat = "$left $operation $right attr-dict `:` type(operands)";
}

def Basicpy_BinaryExprOp : Basicpy_Op<"binary_expr", []> {
  let summary = "Binary expression";
  let description = [{
    An expression between two operands as generated by the AST BinOp node.
  }];
  let arguments = (ins
    AnyType:$left,
    AnyType:$right,
    BinaryOperationAttr:$operation
  );
  let results = (outs
    AnyType:$result
  );
  let assemblyFormat = "$left $operation $right attr-dict `:` functional-type(operands, results)";
}

def Basicpy_ExecOp : Basicpy_Op<"exec", [
    SingleBlockImplicitTerminator<"ExecDiscardOp">]> {
  let summary = "Evaluates an expression being executed as a statement";
  let description = [{
    The result is discarded. Typically expressions are no-side-effect and can
    be re-ordered as needed. Embedding one in an exec op ensures that its
    placement in program order is preserved.
  }];
  let regions = (region SizedRegion<1>:$body);

  let skipDefaultBuilders = 1;
  let builders = [
    OpBuilder<(ins)>,
  ];
  let extraClassDeclaration = [{
    OpBuilder getBodyBuilder() {
      Block* body = getBody(0);
      return OpBuilder::atBlockEnd(body);
    }
  }];
}

def Basicpy_ExecDiscardOp : Basicpy_Op<"exec_discard", [
    NoSideEffect, ReturnLike, Terminator]> {
  let summary = "Terminator for an exec block";
  let description = [{
    Discards results and terminates an exec block.
  }];
  let arguments = (ins Variadic<AnyType>:$operands);
  let assemblyFormat = "operands attr-dict `:` type(operands)";
}

def Basicpy_FuncTemplateCallOp : Basicpy_Op<"func_template_call", []> {
  let summary = "Calls a function template";
  let description = [{
    Most function calls start with this generic calling op, which binds
    symbolically to a func_template. At this level, there are very few
    semantics associated with the call, since, often, both types and the
    specific concrete callee cannot be determined.

    Per python calling conventions, all functions return one result, even if
    None or a tuple (which may be syntactically unpacked to multiple results).

    If specified, the `argNames` operand is right aligned to the list of
    positional `args`, representing arguments that are special or have been
    passed with a keyword. The following arg names are special:
      '*': Indicates that the argument is a positional argument pack (must be
           the first arg name, if present).
      '**': Indicates that the argument is a keyword argument pack (must be
           the last arg name, if present).
  }];

  let arguments = (ins
    FlatSymbolRefAttr:$callee,
    Variadic<AnyType>:$args,
    StrArrayAttr:$arg_names);
  let results = (outs AnyType:$result);
  let assemblyFormat = "$callee `(` $args `)` `kw` $arg_names attr-dict `:` functional-type($args, results)";
  let skipDefaultBuilders = 1;
  let builders = [
    OpBuilder<(ins)>,
  ];
}

def Basicpy_FuncTemplateOp : Basicpy_Op<"func_template", [
    IsolatedFromAbove,
    SingleBlockImplicitTerminator<"FuncTemplateTerminatorOp">,
    NativeOpTrait<"SymbolTable">,
    Symbol]> {
  let summary = "Group of multiple overload-resolved concrete functions";
  let description = [{
    The outer func_template op acts as a module that can contain named concrete
    functions that are interpreted as overloads. If the function signature is
    sufficient to disambiguate (i.e. with nothing more than arity and MLIR
    argument types), then this is all that is needed. However, in many cases,
    additional attributes will need to be specified to further constrain types.
    The first matching function signature is selected to satisfy a
    `func_template_call` op.

    TODO: Define this extended constraint matching.

    Instantiation
    -------------
    Once a concrete function is selected as being applicable to a given call,
    it will typically be instantiated as a standalone, unspecialized function
    in the calling module (as a peer to the func_template). This function
    will be uniquely identified by concating the outer func_template's symbol
    name, '$', and the concrete instance's symbol name.

    Note that the function may still be unspecialized (in that it contains
    UnknownType arguments/results), and type inference is expected to further
    specialize/inline/constrain it.

    Naming
    ------
    By convention, func_templates are named to avoid collision for various
    uses:
      - Global function templates: "__global$python.qualified.name"
      - Method names: "__method$method_name"
      - Attribute getter: "__getattr$attr_name"
      - Attribute setter: "__setattr$attr_name"

    As in user-level python, for functions that bind to an instance, the first
    argument must be a concrete type for the bound instance type. In this way,
    there is one `func_template` for every unique member name and the normal
    type constraints system is used to select the overload, just as if it was
    a normal function call. It is left to utility routines to merge libraries
    in a way that preserves this invariant.

    TODO: This needs to be fleshed out more as some additional rules about
    ordering and conflict resolution are likely needed to make this correct.

    Correlation with python runtime
    -------------------------------
    When extracting a program, it is typically necessary to create weak
    references to specific python functions and correlate them back to a named
    template defined here. Often times this can just be done lexically, but
    to avoid fragility, any func_template that correlates to a python
    runtime function will have an additional attribute `py_bind` that is an
    array of StringAttr qualified names to resolve and bind to in the python
    runtime. In cases of divergence, the symbol name of the template should
    be chosen just for uniqueness (not significance).

    The qualified name format for `py_bind` attribute is:
        package.name#local.qualified.name
  }];
  let arguments = (ins);
  let regions = (region SizedRegion<1>:$body);

  let skipDefaultBuilders = 1;
  let builders = [
    OpBuilder<(ins)>,
  ];
  let extraClassDeclaration = [{
    OpBuilder getBodyBuilder() {
      Block* body = getBody(0);
      return OpBuilder::atBlockEnd(body);
    }
  }];
}

def Basicpy_FuncTemplateTerminatorOp : Basicpy_Op<"func_template_terminator", [
    HasParent<"Basicpy::FuncTemplateOp">,
    Terminator]> {
  let summary = "Terminator pseudo-op for the FuncTemplateOp";

  let parser = ?;
  let printer = ?;
}

def Basicpy_SlotObjectMakeOp : Basicpy_Op<"slot_object_make", [
    NoSideEffect]> {
  let summary = "Creates an instance of a SlotObject type";
  let description = [{
    SlotObjects are typically instances of built-in classes that have a fixed
    number of slots. Unlike in standard python, the types of each slot are
    tracked.

    This op has a custom assembly form which can be used when valid that
    omits the operand types (since they are equal to the types in the returned
    slot object). Example:
      %0 = basicpy.singleton : !basicpy.NoneType
      %1 = basicpy.slot_object_make(%0) ->
          !basicpy.SlotObject<slice, !basicpy.NoneType>
  }];
  let arguments = (ins
    // TODO: Tighter constraints on allowable types.
    Variadic<AnyType>:$slots
  );
  let results = (outs
    Basicpy_SlotObjectType:$result
  );
}

def Basicpy_SlotObjectGetOp : Basicpy_Op<"slot_object_get", [
    NoSideEffect]> {
  let summary = "Gets a slot from a slot object";
  let description = [{
    Gets a slot from a SlotObject.

    Example:
      %0 = basicpy.slot_object_make ...
      %1 = basicpy.slot_object_get %0[1] : !basicpy.SlotObject<...>
  }];
  let arguments = (ins
    Basicpy_SlotObjectType:$object,
    IndexAttr:$index
  );
  let results = (outs
    AnyType:$result
  );
}

#endif // NPCOMP_DIALECT_BASICPY_IR_BASICPY_OPS
