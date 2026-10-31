#include "codegen.h"
#include <errno.h>
#include <float.h>
#include <inttypes.h>
#include <limits.h>
#include <stdlib.h>
#include <string.h>
#include <windows.h>
#include <io.h>

_Static_assert(sizeof(double) == sizeof(uint64_t) && DBL_MANT_DIG == 53 && DBL_MAX_EXP == 1024,
               "LLVM hexadecimal doubles require IEEE 754 binary64");

typedef enum { OPERAND_INTEGER, OPERAND_DECIMAL, OPERAND_TEMP } OperandKind;
typedef struct {
    OperandKind kind;
    SemanticType type;
    union { int32_t integer; uint64_t bits; unsigned long long temp; } value;
} Operand;
typedef struct Binding {
    const char *name;
    Operand operand;
    struct Binding *next;
} Binding;
typedef struct {
    FILE *out;
    Binding *bindings;
    unsigned long long next_temp;
    int failed;
} Context;

static int fail(Context *ctx, const char *message)
{
    fprintf(stderr, "Error de generacion LLVM: %s\n", message);
    ctx->failed = 1;
    return 0;
}

static const char *llvm_type(SemanticType type)
{
    return type == TYPE_INTEGER ? "i32" : type == TYPE_DECIMAL ? "double" : NULL;
}

static void print_operand(FILE *out, Operand op)
{
    if (op.kind == OPERAND_TEMP) fprintf(out, "%%t%llu", op.value.temp);
    else if (op.kind == OPERAND_INTEGER) fprintf(out, "%" PRId32, op.value.integer);
    else fprintf(out, "0x%016" PRIX64, op.value.bits);
}

static int expression(Context *ctx, const AstNode *node, Operand *out)
{
    if (!llvm_type(node->type)) return fail(ctx, "expresion sin tipo valido");
    out->type = node->type;
    switch (node->kind) {
    case AST_INTEGER:
        out->kind = OPERAND_INTEGER;
        out->value.integer = node->literal_value.integer;
        return 1;
    case AST_DECIMAL:
        out->kind = OPERAND_DECIMAL;
        memcpy(&out->value.bits, &node->literal_value.decimal, sizeof out->value.bits);
        return 1;
    case AST_IDENTIFIER:
        for (Binding *b = ctx->bindings; b; b = b->next) {
            if (strcmp(b->name, node->as.text) == 0) {
                if (b->operand.type != node->type) return fail(ctx, "tipo inconsistente en referencia");
                *out = b->operand;
                return 1;
            }
        }
        return fail(ctx, "referencia sin operando asociado");
    case AST_BINARY: {
        Operand left, right;
        if (!expression(ctx, node->as.binary.left, &left) ||
            !expression(ctx, node->as.binary.right, &right)) return 0;
        if (left.type != node->type || right.type != node->type)
            return fail(ctx, "tipos inconsistentes en el AST");
        const char *instruction = NULL;
        switch (node->as.binary.op) {
        case '+': instruction = node->type == TYPE_INTEGER ? "add" : "fadd"; break;
        case '-': instruction = node->type == TYPE_INTEGER ? "sub" : "fsub"; break;
        case '*': instruction = node->type == TYPE_INTEGER ? "mul" : "fmul"; break;
        case '/': instruction = node->type == TYPE_INTEGER ? "sdiv" : "fdiv"; break;
        default: return fail(ctx, "operador desconocido");
        }
        if (ctx->next_temp == ULLONG_MAX) return fail(ctx, "demasiados temporales");
        out->kind = OPERAND_TEMP;
        out->value.temp = ++ctx->next_temp;
        fprintf(ctx->out, "  %%t%llu = %s %s ", out->value.temp, instruction, llvm_type(node->type));
        print_operand(ctx->out, left);
        fputs(", ", ctx->out);
        print_operand(ctx->out, right);
        fputc('\n', ctx->out);
        return 1;
    }
    default: return fail(ctx, "nodo inesperado en expresion");
    }
}

static int emit_module(Context *ctx, const AstNode *program)
{
    if (!program || program->kind != AST_PROGRAM) return fail(ctx, "programa invalido");
    fputs("declare void @print_i32(i32)\ndeclare void @print_f64(double)\n\n", ctx->out);
    for (const AstNode *s = program->as.program.statements; s; s = s->next)
        if (s->kind == AST_LED) { fputs("declare void @olc_led13_on()\n\n", ctx->out); break; }
    fputs("define void @olc_program() {\nentry:\n", ctx->out);
    for (const AstNode *s = program->as.program.statements; s; s = s->next) {
        Operand value;
        if (s->kind == AST_LET) {
            if (!expression(ctx, s->as.declaration.value, &value)) return 0;
            Binding *binding = malloc(sizeof *binding);
            if (!binding) return fail(ctx, "memoria insuficiente");
            binding->name = s->as.declaration.name;
            binding->operand = value;
            binding->next = ctx->bindings;
            ctx->bindings = binding;
        } else if (s->kind == AST_PRINT) {
            if (!expression(ctx, s->as.print.value, &value)) return 0;
            const char *type = llvm_type(value.type);
            fprintf(ctx->out, "  call void @%s(%s ",
                    value.type == TYPE_INTEGER ? "print_i32" : "print_f64", type);
            print_operand(ctx->out, value);
            fputs(")\n", ctx->out);
        } else if (s->kind == AST_LED) {
            if (!s->as.led.validated) return fail(ctx, "instruccion LED no validada");
            fputs("  call void @olc_led13_on()\n", ctx->out);
        } else return fail(ctx, "instruccion desconocida");
    }
    fputs("  ret void\n}\n", ctx->out);
    return !ferror(ctx->out);
}

static int same_file(FILE *input, const char *output)
{
    HANDLE in = (HANDLE)_get_osfhandle(_fileno(input));
    BY_HANDLE_FILE_INFORMATION a, b;
    if (in == INVALID_HANDLE_VALUE || !GetFileInformationByHandle(in, &a)) return -1;
    HANDLE out = CreateFileA(output, FILE_READ_ATTRIBUTES,
        FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, NULL, OPEN_EXISTING, 0, NULL);
    if (out == INVALID_HANDLE_VALUE) {
        DWORD error = GetLastError();
        return (error == ERROR_FILE_NOT_FOUND || error == ERROR_PATH_NOT_FOUND) ? 0 : -1;
    }
    int ok = GetFileInformationByHandle(out, &b);
    int same = ok &&
        a.dwVolumeSerialNumber == b.dwVolumeSerialNumber &&
        a.nFileIndexHigh == b.nFileIndexHigh && a.nFileIndexLow == b.nFileIndexLow;
    CloseHandle(out);
    return ok ? same : -1;
}

int codegen_write(const AstNode *program, const char *output, FILE *input)
{
    int identity = same_file(input, output);
    if (identity < 0) {
        fprintf(stderr, "Error de generacion LLVM: no se pudo verificar la identidad de los archivos\n");
        return 0;
    }
    if (identity) {
        fprintf(stderr, "Error de generacion LLVM: salida y entrada son el mismo archivo\n");
        return 0;
    }
    size_t length = strlen(output);
    if (length > SIZE_MAX - 48) { fputs("Ruta de salida demasiado larga\n", stderr); return 0; }
    char *temp = malloc(length + 48);
    if (!temp) { fputs("Error: memoria insuficiente\n", stderr); return 0; }
    FILE *file = NULL;
    for (unsigned i = 0; i < 1000; ++i) {
        snprintf(temp, length + 48, "%s.tmp.%lu.%u", output, (unsigned long)GetCurrentProcessId(), i);
        file = fopen(temp, "wbx");
        if (file || errno != EEXIST) break;
    }
    if (!file) { perror("No se pudo crear salida temporal LLVM"); free(temp); return 0; }
    Context ctx = { file, NULL, 0, 0 };
    int ok = emit_module(&ctx, program);
    if (fclose(file) != 0) { perror("Error al cerrar salida LLVM"); ok = 0; }
    while (ctx.bindings) { Binding *next = ctx.bindings->next; free(ctx.bindings); ctx.bindings = next; }
    if (ok && !MoveFileExA(temp, output, MOVEFILE_REPLACE_EXISTING)) {
        fprintf(stderr, "No se pudo reemplazar salida LLVM (Windows error %lu)\n", (unsigned long)GetLastError());
        ok = 0;
    }
    if (!ok) {
        if (!ctx.failed) fputs("Error al escribir LLVM IR\n", stderr);
        if (remove(temp) != 0) perror("No se pudo eliminar salida temporal LLVM");
    }
    free(temp);
    return ok;
}
