# `null as boolean` throws with classic call sites since Groovy 5

Not reported yet.

Coercing a null value to `boolean` with the `as` operator,

```groovy
boolean present(Holder h) {
    h.value as boolean
}
```

gives `false` on Groovy 4, and on Groovy 5 and later when the class is compiled for invokedynamic. Compiled with
classic call sites (`indy=false`) on Groovy 5 and later it throws:

```
java.lang.IllegalArgumentException: null to boolean
```

The result is the same in dynamic and in `@CompileStatic` code. Only the `as` form is affected: a cast
(`(boolean) x`), an assignment to a `boolean`, a `boolean` return and Groovy truth (`x ? true : false`, `!!x`) still
give `false` in every mode.

`x as boolean` is a common way to write "is this set", so an application that compiles without invokedynamic (the
Grails default up to Grails 8) meets this at run time, at each such expression whose value happens to be null, after
moving from Groovy 4 to Groovy 5.

## Reproducer

`NullAsPrimitive.groovy` has no dependencies. It evaluates each form in a dynamic and in a `@CompileStatic` class:

```
$ ./run.sh 4.0.33 5.1.3 6.0.0
```

| Expression, value is null | 4.0.33, indy | 4.0.33, classic | 5.x / 6.x / master, indy | 5.x / 6.x / master, classic |
|---|---|---|---|---|
| `x as boolean` | `false` | `false` | `false` | **`IllegalArgumentException: null to boolean`** |
| `(boolean) x` | `false` | `false` | `false` | `false` |
| `boolean b = x` | `false` | `false` | `false` | `false` |
| `x ? true : false` | `false` | `false` | `false` | `false` |
| `x as int` | `NullPointerException` | `GroovyCastException` | `NullPointerException` | `IllegalArgumentException: null to int` |

The dynamic and the `@CompileStatic` class give the same result for every `as` row. `x as int` failed before as well;
what changed there is the exception, and the two modes never agreed on it.

The jars are looked up in `~/.m2/repository` and the Gradle cache. Classic call sites on Groovy 6 and later need
`groovy-callsite`; `GROOVY_JAR` and `GROOVY_CALLSITE_JAR` point the script at a build from source.

## Cause

The two bytecode writers coerce differently.

`InvocationWriter.coerce()` (classic) passes the target type as written to `ScriptBytecodeAdapter.asType(Object,
Class)`, so `null as boolean` calls `NullObject.asType(boolean.class)`. Since Groovy 5.0.0-alpha-3 that method rejects
primitive types (added with the change for GROOVY-11196):

```java
public Object asType(final Class c) {
    if (c.isPrimitive()) throw new IllegalArgumentException("null to " + c);
    return null;
}
```

Before, it returned null and the cast to `boolean` that follows turned null into `false`.

`InvokeDynamicWriter.coerce()` asks for the wrapper type instead, `asType(Boolean)`, and then casts the result to
`boolean`, so the check for a primitive type is never reached and null becomes `false` as before.

## Suggested fix

Make the classic writer agree with the invokedynamic writer: in `InvocationWriter.coerce()`, call `asType` with the
wrapper of a primitive target type and leave the conversion to the primitive to the cast that follows. For `boolean`
this restores the Groovy 4 result in both modes. Alternatively `NullObject.asType(boolean.class)` could return
`false`, since `NullObject.asBoolean()` already does.

## Environment

JDK 25.0.4 (Liberica), macOS. Reproduced with classic call sites on Groovy 5.0.7, 5.1.3, 6.0.0, `GROOVY_5_1_X` and
`GROOVY_6_0_X` snapshots, and a build of master (eb37f3402a; the code involved is unchanged at f1115f25db). Not
reproduced on 4.0.33, or on any of these versions with invokedynamic.
