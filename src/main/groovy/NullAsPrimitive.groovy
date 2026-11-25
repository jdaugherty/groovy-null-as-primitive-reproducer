import groovy.transform.CompileStatic

/**
 * Coerces a null value to a primitive type with the "as" operator, with a cast, and by assignment, in dynamic and in
 * statically compiled code.
 */
class Holder {
    Object value
    Integer number
}

class Dynamic {
    static boolean asBoolean(Holder h) { h.value as boolean }
    static boolean castBoolean(Holder h) { (boolean) h.value }
    static boolean assignBoolean(Holder h) { boolean b = h.value; b }
    static boolean truth(Holder h) { h.value ? true : false }
    static int asInt(Holder h) { h.number as int }
    static int castInt(Holder h) { (int) h.number }
}

@CompileStatic
class Static {
    static boolean asBoolean(Holder h) { h.value as boolean }
    static boolean castBoolean(Holder h) { (boolean) h.value }
    static boolean assignBoolean(Holder h) { boolean b = h.value; b }
    static boolean truth(Holder h) { h.value ? true : false }
    static int asInt(Holder h) { h.number as int }
    static int castInt(Holder h) { (int) h.number }
}

String indy = "indy=${args ? args[0] : 'true'}"
Holder holder = new Holder()
[dynamic: Dynamic, static: Static].each { String mode, Class<?> type ->
    [asBoolean    : 'null as boolean',
     castBoolean  : '(boolean) null',
     assignBoolean: 'boolean b = null',
     truth        : 'null ? true : false',
     asInt        : 'null as int',
     castInt      : '(int) null'].each { String method, String form ->
        String result
        try {
            result = type."$method"(holder)
        } catch (Throwable t) {
            result = "${t.class.simpleName}: ${t.message}"
        }
        println "${indy} ${mode.padRight(7)} ${form.padRight(19)} -> ${result}"
    }
}
