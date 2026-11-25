#!/usr/bin/env bash
#
# Reproducer: "null as boolean" throws IllegalArgumentException("null to boolean") on Groovy 5 and later when the code
# is compiled with classic call sites (indy=false). With invokedynamic, and on Groovy 4 in both modes, it is false.
#
# Usage: ./run.sh <groovy-version> [<groovy-version> ...]   e.g. ./run.sh 4.0.33 5.1.3 6.0.0
#   Jars are looked up in ~/.m2/repository and the Gradle cache. Classic call sites on Groovy 6 need groovy-callsite.
#   GROOVY_JAR and GROOVY_CALLSITE_JAR override the lookup, for a build from source.
set -uo pipefail
cd "$(dirname "$0")"

find_jar() { # find_jar <module> <version>
    find "${HOME}/.m2/repository/org/apache/groovy/$1/$2" "${HOME}/.gradle/caches/modules-2/files-2.1/org.apache.groovy/$1/$2" \
        -name "$1-$2.jar" 2>/dev/null | head -1
}

for version in "${@:-6.0.0}"; do
    groovy_jar=${GROOVY_JAR:-$(find_jar groovy "${version}")}
    callsite_jar=${GROOVY_CALLSITE_JAR:-$(find_jar groovy-callsite "${version}")}
    if [ -z "${groovy_jar}" ]; then
        echo "${version}: groovy jar not found"; continue
    fi
    echo "== Groovy ${version}"
    for indy in true false; do
        if [ "${indy}" = false ] && [ -z "${callsite_jar}" ] && [ "${version%%.*}" -ge 6 ]; then
            echo "   indy=false: skipped, groovy-callsite ${version} not found"; continue
        fi
        java -Dgroovy.target.indy=${indy} -cp "${groovy_jar}${callsite_jar:+:${callsite_jar}}" groovy.ui.GroovyMain NullAsPrimitive.groovy 2>&1 \
            | grep -v '^Picked up JAVA_TOOL_OPTIONS' | sed 's/^/   /'
    done
done
