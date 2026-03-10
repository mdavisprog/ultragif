// Native module to handle TraceLog callbacks due to usage of va_list.

#include "raylib.h"
#include <stdio.h>
#include <stdarg.h>

void (*onTraceLogSignature)(int, const char*) = NULL;

void onTraceLog(int log_level, const char* format, va_list list) {
    static char buffer[1024];

    int count = vsnprintf(buffer, sizeof(buffer), format, list);
    if (count >= 1024) {
        printf("Trace log exceeds buffer size! %d >= %lld\n", count, sizeof(buffer));
    }

    if (onTraceLogSignature != NULL) {
        onTraceLogSignature(log_level, buffer);
    }
}

void registerTraceLog() {
    SetTraceLogCallback(onTraceLog);
}
