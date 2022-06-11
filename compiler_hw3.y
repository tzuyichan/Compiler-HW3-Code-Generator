/* Please feel free to modify any content */

/* Definition section */
%{
    #include "compiler_hw_common.h" //Extern variables that communicate with lex
    #include "symbol_table.h"
    #include "table_list.h"
    // #define YYDEBUG 1
    // int yydebug = 1;

    extern int yylineno;
    extern int yylex();
    extern FILE *yyin;

    int yylex_destroy ();
    void yyerror (char const *s)
    {
        printf("error:%d: %s\n", yylineno, s);
    }

    /* Used to generate code */
    /* As printf; the usage: CODEGEN("%d - %s\n", 100, "Hello world"); */
    /* We do not enforce the use of this macro */
    #define CODEGEN(...) \
        do { \
            for (int i = 0; i < INDENT_LVL; i++) { \
                fprintf(fout, "\t"); \
            } \
            fprintf(fout, __VA_ARGS__); \
        } while (0)

    #define MAIN_STACK_SIZE 100
    #define FUNC_STACK_SIZE 20

    /* Symbol table function - you can add new functions if needed. */
    /* parameters and return type can be changed */
    static void create_sym_table();
    static int insert_symbol(char *name, char *type);
    static int lookup_symbol(char *name, bool load_to_stack);
    static void lookup_func(char *name);
    static void dump_sym_table();
    static char *check_type(char *nterm1, char *nterm2, char *operator);
    static char get_op_type(char *type);
    static void get_jasmin_func_sig(char *func_sig);
    static void cat_jasmin_func_param(char param, char *j_func_sig);
    static void print_codegen(char *print_type, char *type);
    static void cmp_codegen(char *cmp_type, char *type);

    /* Global variables */
    // parser
    char TYPE[8];
    char FUNC_SIG[ID_MAX_LEN];
    char CURRENT_FUNC[ID_MAX_LEN];
    char CURRENT_IDENT[ID_MAX_LEN];
    char FUNC_RET_TYPE;
    bool IN_FUNC_SCOPE = false;
    Table_head *T;

    // code generation
    bool HAS_ERROR = false;
    FILE *fout = NULL;
    int INDENT_LVL = 0;
    int REGISTER = 0;
    int LABEL_CNT = 0;
    typedef struct switch_t
    {
        int count;
        int n_cases;
        bool has_default;
        int case_val[128];
    } Switch_t;
    Switch_t Switch;
%}

%error-verbose

/* Use variable or self-defined structure to represent
 * nonterminal and token type
 *  - you can add new fields if needed.
 */
%union {
    int i_val;
    float f_val;
    char *s_val;
}

/* Token without return */
%token INT FLOAT BOOL STRING
%token TRUE_ FALSE_
%token INC DEC 
%token VAR 
%token IF ELSE FOR SWITCH CASE DEFAULT
%token PRINT PRINTLN NEWLINE
%token PACKAGE FUNC RETURN

/* Token with return, which need to sepcify type */
%token <i_val> INT_LIT
%token <f_val> FLOAT_LIT
%token <s_val> STRING_LIT IDENT 
%token <s_val> ADD SUB MUL QUO REM
%token <s_val> EQL NEQ GTR GEQ LSS LEQ NOT LAND LOR
%token <s_val> ASSIGN ADD_ASSIGN SUB_ASSIGN MUL_ASSIGN QUO_ASSIGN REM_ASSIGN

/* Nonterminal with return, which need to sepcify type */
%type <s_val> Type ReturnType 
%type <s_val> DeclAssignment ParenthesisExpr Expression
%type <s_val> LogOrExpr LogAndExpr CmpExpr AddExpr MulExpr
%type <s_val> CastExpr UnaryExpr PrimaryExpr FunctionCall Boolean Operand Constant

/* Yacc will start at this nonterminal */
%start Program

/* Grammar section */
%%

Program
    : { create_sym_table(); } GlobalStatementList { dump_sym_table(); }
;

GlobalStatementList 
    : GlobalStatementList GlobalStatement
    | GlobalStatement
;

GlobalStatement
    : PackageStmt NEWLINE
    | FunctionDeclStmt
    | NEWLINE
;


PackageStmt
    : PACKAGE IDENT     { printf("package: %s\n", $2); }
;

FunctionDeclStmt
    : FuncOpen '(' ParameterList ')' ReturnType {
        FUNC_RET_TYPE = $5[0] - 32;  // ASCII case conversion
        insert_symbol(CURRENT_FUNC, "func");

        int is_main_func = strcmp(CURRENT_FUNC, "main") == 0;
        if (is_main_func)
        {
            CODEGEN(".method public static main([Ljava/lang/String;)V\n");
        }
        else
        {
            lookup_func(CURRENT_FUNC);
            get_jasmin_func_sig(FUNC_SIG);
            CODEGEN(".method public static %s%s\n", CURRENT_FUNC, FUNC_SIG);
        }
        int stack_size = (is_main_func) ? MAIN_STACK_SIZE : FUNC_STACK_SIZE;
        CODEGEN(".limit stack %d\n", stack_size);
        CODEGEN(".limit locals %d\n", stack_size);
        INDENT_LVL++;
    }
    FuncBlock {
        INDENT_LVL--;
        CODEGEN(".end method\n");
    }
;

FuncOpen
    : FUNC IDENT {
        printf("func: %s\n", $2);
        strncpy(CURRENT_FUNC, $2, ID_MAX_LEN);
        create_sym_table();
        IN_FUNC_SCOPE = true;
    }
;

ParameterList
    : ParameterList ',' ParameterIdentType
    | ParameterIdentType
    | /* empty */
;

ReturnType
    : Type
    | /* empty */       { $$ = "void"; }
;

FuncBlock
    : Block
;
    
ReturnStmt
    : RETURN                { CODEGEN("return\n"); }
    | RETURN Expression     { CODEGEN("%creturn\n", get_op_type($2)); }
;

ParameterIdentType
    : IDENT Type {
        printf("param %s, type: %c\n", $1, $2[0] - 32);
        insert_symbol($1, $2);
    }
;

Type
    : INT           { $$ = "int32"; }
    | FLOAT         { $$ = "float32"; }
    | STRING        { $$ = "string"; }
    | BOOL          { $$ = "bool"; }
;

Block
    : '{' { create_sym_table(); } StatementList '}' { dump_sym_table(); }
;

StatementList
    : StatementList Statement
    | /* empty */
;

Statement
    : DeclarationStmt NEWLINE
    | SimpleStmt NEWLINE
    | Block
    | IfStmt
    | ForStmt
    | SwitchStmt
    | CaseStmt
    | PrintStmt NEWLINE
    | ReturnStmt NEWLINE
    | NEWLINE
;

DeclarationStmt
    : VAR IDENT Type DeclAssignment {
        REGISTER = insert_symbol($2, $3);
        if (strcmp($4, "unassigned") == 0)
        {
            if (strcmp($3, "string") == 0)
                CODEGEN("ldc \"\"\n");
            else
                CODEGEN("%cconst_0\n", get_op_type($3));
        }
        CODEGEN("%cstore %d\n", get_op_type($3), REGISTER);
    }
;

DeclAssignment
    : ASSIGN Expression     { $$ = $2; }
    | /* empty */           { $$ = "unassigned"; }
;

SimpleStmt
    : AssignmentStmt
    | Expression
    | IncDecStmt
;

IfStmt
    : IF Expression { check_type($2, $2, "IF"); } Block ElseStmt
;

ElseStmt
    : ELSE IfStmt
    | ELSE Block
    | /* empty */
;

ForStmt
    : FOR {
        INDENT_LVL--;
        CODEGEN("L_for_begin:\n");
        INDENT_LVL++;
    } Expression {
        check_type($3, $3, "FOR");
        CODEGEN("ifeq L_for_exit\n");
    } Block {
        CODEGEN("goto L_for_begin\n");
        INDENT_LVL--;
        CODEGEN("L_for_exit:\n");
        INDENT_LVL++;
    }
    | FOR {} ForClause Block
;

ForClause
    : SimpleStmt ';' Expression ';' SimpleStmt
;

SwitchStmt
    : SWITCH Expression {
        CODEGEN("goto L_switch_begin_%d\n", Switch.count);
    } Block {
        INDENT_LVL--;
        CODEGEN("L_switch_begin_%d:\n", Switch.count);
        CODEGEN("lookupswitch\n");
        INDENT_LVL++;
        for (int i = 0; i < Switch.n_cases; ++i)
            CODEGEN("%d: L_case_%d\n", Switch.case_val[i], Switch.case_val[i]);
        if (Switch.has_default)
            CODEGEN("default: L_case_default_%d\n", Switch.count);
        INDENT_LVL--;
        CODEGEN("L_switch_end_%d:\n", Switch.count);
        INDENT_LVL++;

        Switch.count++;
        Switch.n_cases = 0;
        Switch.has_default = false;
    }
;

CaseStmt
    : CASE INT_LIT ':' {
        INDENT_LVL--;
        CODEGEN("L_case_%d:\n", $2);
        INDENT_LVL++;
        Switch.case_val[Switch.n_cases++] = $2;
    } Block { CODEGEN("goto L_switch_end_%d\n", Switch.count); }
    | DEFAULT ':' {
        Switch.has_default = true;
        INDENT_LVL--;
        CODEGEN("L_case_default_%d:\n", Switch.count);
        INDENT_LVL++;
    } Block { CODEGEN("goto L_switch_end_%d\n", Switch.count); }
;

PrintStmt
    : PRINT ParenthesisExpr         { print_codegen("print", $2); }
    | PRINTLN ParenthesisExpr       { print_codegen("println", $2); }
;

AssignmentStmt
    : IDENT {
        lookup_symbol($1, false);
        strncpy(CURRENT_IDENT, $1, ID_MAX_LEN); strncpy($1, TYPE, 8);
    } ASSIGN Expression {
        check_type($1, $4, $3);
        REGISTER = lookup_symbol(CURRENT_IDENT, false);
        CODEGEN("%cstore %d\n", get_op_type($1), REGISTER);
    }
    // add assign
    | IDENT {
        lookup_symbol($1, true);
        strncpy(CURRENT_IDENT, $1, ID_MAX_LEN); strncpy($1, TYPE, 8);
    } ADD_ASSIGN Expression {
        check_type($1, $4, $3);
        REGISTER = lookup_symbol(CURRENT_IDENT, false);
        CODEGEN("%cadd\n", get_op_type($1));
        CODEGEN("%cstore %d\n", get_op_type($1), REGISTER);
    }
    // sub assign
    | IDENT {
        lookup_symbol($1, true);
        strncpy(CURRENT_IDENT, $1, ID_MAX_LEN); strncpy($1, TYPE, 8);
    } SUB_ASSIGN Expression {
        check_type($1, $4, $3);
        REGISTER = lookup_symbol(CURRENT_IDENT, false);
        CODEGEN("%csub\n", get_op_type($1));
        CODEGEN("%cstore %d\n", get_op_type($1), REGISTER);
    }
    // mul assign
    | IDENT {
        lookup_symbol($1, true);
        strncpy(CURRENT_IDENT, $1, ID_MAX_LEN); strncpy($1, TYPE, 8);
    } MUL_ASSIGN Expression {
        check_type($1, $4, $3);
        REGISTER = lookup_symbol(CURRENT_IDENT, false);
        CODEGEN("%cmul\n", get_op_type($1));
        CODEGEN("%cstore %d\n", get_op_type($1), REGISTER);
    }
    // div assign
    | IDENT {
        lookup_symbol($1, true);
        strncpy(CURRENT_IDENT, $1, ID_MAX_LEN); strncpy($1, TYPE, 8);
    } QUO_ASSIGN Expression {
        check_type($1, $4, $3);
        REGISTER = lookup_symbol(CURRENT_IDENT, false);
        CODEGEN("%cdiv\n", get_op_type($1));
        CODEGEN("%cstore %d\n", get_op_type($1), REGISTER);
    }
    // rem assign
    | IDENT {
        lookup_symbol($1, true);
        strncpy(CURRENT_IDENT, $1, ID_MAX_LEN); strncpy($1, TYPE, 8);
    } REM_ASSIGN Expression {
        check_type($1, $4, $3);
        REGISTER = lookup_symbol(CURRENT_IDENT, false);
        CODEGEN("irem\n");
        CODEGEN("istore %d\n", REGISTER);
    }
;

IncDecStmt
    : Operand INC {
        CODEGEN("%cconst_1\n", get_op_type($1));
        CODEGEN("%cadd\n", get_op_type($1));
        CODEGEN("%cstore %d\n", get_op_type($1), REGISTER);
    }
    | Operand DEC {
        CODEGEN("%cconst_1\n", get_op_type($1));
        CODEGEN("%csub\n", get_op_type($1));
        CODEGEN("%cstore %d\n", get_op_type($1), REGISTER);
    }
;

ParenthesisExpr
    : '(' Expression ')'        { $$ = $2; }
;

Expression
    : LogOrExpr
;

LogOrExpr
    : LogAndExpr
    | LogOrExpr LOR LogAndExpr           { $$ = check_type($1, $3, $2); CODEGEN("ior\n"); }
;

LogAndExpr
    : CmpExpr
    | LogAndExpr LAND CmpExpr          { $$ = check_type($1, $3, $2); CODEGEN("iand\n"); }
;

CmpExpr
    : AddExpr
    | CmpExpr EQL AddExpr          { $$ = check_type($1, $3, $2); printf("EQL\n"); }
    | CmpExpr NEQ AddExpr          { $$ = check_type($1, $3, $2); printf("NEQ\n"); }
    | CmpExpr LSS AddExpr          { $$ = check_type($1, $3, $2); printf("LSS\n"); }
    | CmpExpr LEQ AddExpr          { $$ = check_type($1, $3, $2); printf("LEQ\n"); }
    | CmpExpr GTR AddExpr          { $$ = check_type($1, $3, $2); cmp_codegen("ifgt", $1); }
    | CmpExpr GEQ AddExpr          { $$ = check_type($1, $3, $2); printf("GEQ\n"); }
;

AddExpr
    : MulExpr
    | AddExpr ADD MulExpr           { $$ = check_type($1, $3, $2); CODEGEN("%cadd\n", TYPE[0]); }
    | AddExpr SUB MulExpr           { $$ = check_type($1, $3, $2); CODEGEN("%csub\n", TYPE[0]); }
;

MulExpr
    : CastExpr
    | MulExpr MUL CastExpr           { $$ = check_type($1, $3, $2); CODEGEN("%cmul\n", TYPE[0]); }
    | MulExpr QUO CastExpr           { $$ = check_type($1, $3, $2); CODEGEN("%cdiv\n", TYPE[0]); }
    | MulExpr REM CastExpr           { $$ = check_type($1, $3, $2); CODEGEN("irem\n"); }
;

CastExpr
    : UnaryExpr
    | INT '(' AddExpr ')'          { $$ = "int32"; CODEGEN("f2i\n"); }
    | FLOAT '(' AddExpr ')'        { $$ = "float32"; CODEGEN("i2f\n"); }
;

UnaryExpr
    : PrimaryExpr
    | ADD PrimaryExpr       { $$ = check_type($2, $2, $1); printf("POS\n"); }
    | SUB PrimaryExpr       { $$ = check_type($2, $2, $1); CODEGEN("%cneg\n", get_op_type($2)); }
    | NOT { CODEGEN("iconst_1 ; NOT\n"); } UnaryExpr { $$ = check_type($3, $3, $1); CODEGEN("ixor\n"); }
;

PrimaryExpr
    : Operand
    | '"' STRING_LIT '"'    { $$ = "string"; CODEGEN("ldc \"%s\"\n", $2); }
    | Boolean
    | ParenthesisExpr
    | FunctionCall
;

FunctionCall
    : IDENT '(' FuncCallParamList ')' {
        lookup_func($1);
        printf("call: %s%s\n", $1, FUNC_SIG);
        get_jasmin_func_sig(FUNC_SIG);
        CODEGEN("invokestatic Main/%s%s\n", $1, FUNC_SIG);
        strncpy($$, TYPE, 8);
    }
;

FuncCallParamList
    : FuncCallParamList ',' Expression
    | Expression
    | /* empty */
;

Operand
    : Constant
    | IDENT             { REGISTER = lookup_symbol($1, true); strncpy($$, TYPE, 8); }
;

Boolean
    : TRUE_             { $$ = "bool"; CODEGEN("iconst_1\n"); }
    | FALSE_            { $$ = "bool"; CODEGEN("iconst_0\n"); }
;

Constant
    : INT_LIT {
        $$ = "int32";
        printf("INT_LIT %d\n", $1);
        CODEGEN("ldc %d\n", $1);
    }
    | FLOAT_LIT {
        $$ = "float32";
        printf("FLOAT_LIT %f\n", $1);
        CODEGEN("ldc %f\n", $1);
    }
;

%%

/* C code section */
int main(int argc, char *argv[])
{
    if (argc == 2) {
        yyin = fopen(argv[1], "r");
    } else {
        yyin = stdin;
    }
    if (!yyin) {
        printf("file `%s` doesn't exists or cannot be opened\n", argv[1]);
        exit(1);
    }

    // initialize global variables
    memset(TYPE, 0, 8);
    memset(FUNC_SIG, 0, ID_MAX_LEN);
    memset(CURRENT_FUNC, 0, ID_MAX_LEN);
    Switch.count = 0;
    Switch.n_cases = 0;
    Switch.has_default = false;
    memset(Switch.case_val, 0, 128);

    /* Codegen output init */
    char *bytecode_filename = "hw3.j";
    fout = fopen(bytecode_filename, "w");
    CODEGEN(".source hw3.j\n");
    CODEGEN(".class public Main\n");
    CODEGEN(".super java/lang/Object\n");

    yylineno = 0;
    T = init_table();
    yyparse();

	printf("Total lines: %d\n", yylineno);
    fclose(fout);
    fclose(yyin);

    if (HAS_ERROR) {
        remove(bytecode_filename);
    }
    yylex_destroy();
    return 0;
}

static void create_sym_table() {
    if (!IN_FUNC_SCOPE)
    {
        add_table(T);
        printf("> Create symbol table (scope level %d)\n", T->current_scope);
    }
    IN_FUNC_SCOPE = false;
}

static int insert_symbol(char *name, char *type) {
    char type_str[ID_MAX_LEN];
    char func_sig[ID_MAX_LEN];
    int addr;
    memset(type_str, 0, ID_MAX_LEN);
    memset(func_sig, 0, ID_MAX_LEN);

    // check if symbol has already been declared
    Result *R = find_symbol(T, name);
    if (R && R->scope == T->current_scope)
    {
        printf("error:%d: %s redeclared in this block. previous declaration at line %d\n",
               yylineno, name, R->lineno);
        HAS_ERROR = true;
    }

    // trick to fix wrong line number inside functions
    int lineno = IN_FUNC_SCOPE ? yylineno + 1 : yylineno;

    if (strcmp(type, "func") == 0)
    {
        // generate function signature
        get_func_param_types(T, type_str);
        snprintf(func_sig, ID_MAX_LEN, "(%s)%c", type_str, FUNC_RET_TYPE);
        printf("func_signature: %s\n", func_sig);
    }
    else
    {
        strncpy(func_sig, "-", ID_MAX_LEN);
    }

    Result *entry;
    entry = add_symbol(T, name, type, lineno, func_sig);

    printf("> Insert `%s` (addr: %d) to scope level %d\n", 
           name, entry->addr, entry->scope);

    addr = entry->addr;
    free(entry);

    return addr;
}

static int lookup_symbol(char *name, bool load_to_stack) {
    int addr;
    Result *R = find_symbol(T, name);

    if (R)
    {
        strncpy(TYPE, R->type, 8);
        printf("IDENT (name=%s, address=%d)\n", name, R->addr);

        if (load_to_stack)
        {
            if (strcmp(TYPE, "int32") == 0 || strcmp(TYPE, "bool") == 0)
            {
                CODEGEN("iload %d\n", R->addr);
            }
            else if (strcmp(TYPE, "float32") == 0)
            {
                CODEGEN("fload %d\n", R->addr);
            }
            else
            {
                CODEGEN("aload %d\n", R->addr);
            }
        }
    }
    else
    {
        strncpy(TYPE, "ERROR", 8);
        printf("error:%d: undefined: %s\n", yylineno + 1, name);
        HAS_ERROR = true;
    }

    addr = R->addr;
    free(R);

    return addr;
}

static void lookup_func(char *name)
{
    Result *R = find_symbol(T, name);
    if (R)
    {
        strncpy(FUNC_SIG, R->func_sig, ID_MAX_LEN);

        char ret_val = R->func_sig[strlen(R->func_sig) - 1];
        switch (ret_val)
        {
            case 'I':
                strncpy(TYPE, "int32", 8);
                break;
            case 'F':
                strncpy(TYPE, "float32", 8);
                break;
            case 'B':
                strncpy(TYPE, "bool", 8);
                break;
            case 'S':
                strncpy(TYPE, "string", 8);
                break;
            case 'V':
                strncpy(TYPE, "void", 8);
                break;
            default:
                strncpy(TYPE, "ERROR", 8);
        }
    }
    else
    {
        strncpy(FUNC_SIG, "-", ID_MAX_LEN);
        strncpy(TYPE, "ERROR", 8);
    }
    free(R);
}

static void dump_sym_table() {
    printf("\n> Dump symbol table (scope level: %d)\n", T->current_scope);
    printf("%-10s%-10s%-10s%-10s%-10s%-10s\n",
           "Index", "Name", "Type", "Addr", "Lineno", "Func_sig");

    Node *entry;
    while ((entry = dump_next_entry(T)))
    {
        printf("%-10d%-10s%-10s%-10d%-10d%-10s\n",
               entry->index, entry->name, entry->type,
               entry->addr, entry->lineno, entry->func_sig);
        free(entry);
    }
    printf("\n");
    delete_table(T);
}

static char *check_type(char *nterm1, char *nterm2, char *op)
{
    if ((strcmp(op, "NOT") == 0 || strcmp(op, "LAND") == 0 || strcmp(op, "LOR") == 0))
    {
        if (strcmp(nterm1, nterm2) == 0 && strcmp(nterm1, "bool") == 0)
        {
            strncpy(TYPE, "bool", 8);
            return "bool";
        }
        else
        {
            char *wrong_type = strcmp(nterm1, "bool") == 0 ? nterm2 : nterm1;
            printf("error:%d: invalid operation: (operator %s not defined on %s)\n",
                yylineno, op, wrong_type);
            HAS_ERROR = true;
            strncpy(TYPE, "ERROR", 8);
            return "ERROR";
        }
    }

    if (strcmp(op, "REM") == 0)
    {
        if (strcmp(nterm1, nterm2) == 0 && strcmp(nterm1, "int32") == 0)
        {
            strncpy(TYPE, "int32", 8);
            return "int32";
        }
        else
        {
            char *wrong_type = strcmp(nterm1, "int32") == 0 ? nterm2 : nterm1;
            printf("error:%d: invalid operation: (operator %s not defined on %s)\n",
                yylineno, op, wrong_type);
            HAS_ERROR = true;
            strncpy(TYPE, "ERROR", 8);
            return "ERROR";
        }
    }

    if ((strcmp(op, "FOR") == 0 || strcmp(op, "IF") == 0)
        && strcmp(nterm1, "bool") != 0)
    {
        if (strcmp(nterm1, "ERROR") == 0)  // don't test for error type in condition
        {
            strncpy(TYPE, "bool", 8);
            return "bool";
        }
        printf("error:%d: non-bool (type %s) used as for condition\n",
               yylineno + 1, nterm1);
        HAS_ERROR = true;
        strncpy(TYPE, "ERROR", 8);
        return "ERROR";
    }

    if (strcmp(nterm1, nterm2) != 0)
    {
        printf("error:%d: invalid operation: %s (mismatched types %s and %s)\n",
               yylineno, op, nterm1, nterm2);
        HAS_ERROR = true;
        strncpy(TYPE, "ERROR", 8);
        return "ERROR";
    }

    if (strcmp(op, "EQL") == 0 || strcmp(op, "NEQ") == 0
        || strcmp(op, "LSS") == 0 || strcmp(op, "LEQ") == 0
        || strcmp(op, "GTR") == 0 || strcmp(op, "GEQ") == 0)
    {
        strncpy(TYPE, "bool", 8);
        return "bool";
    }

    strncpy(TYPE, nterm1, 8);
    return nterm1;
}

static char get_op_type(char *type)
{
    if (strcmp(type, "int32") == 0 || strcmp(type, "bool") == 0)
        return 'i';
    else if (strcmp(type, "float32") == 0)
        return 'f';
    else if (strcmp(type, "string") == 0)
        return 'a';
    else
    {
        HAS_ERROR = true;
        return 'z';
    }
}

static void get_jasmin_func_sig(char *func_sig)
{
    char new_sig[ID_MAX_LEN];
    char *p;
    memset(new_sig, 0, ID_MAX_LEN);

    p = strtok(func_sig, "()");

    // write function parameters
    strcat(new_sig, "(");
    for (int i = 0; i < strlen(p); ++i)
    {
        if (p[0] == 'V') break;
        cat_jasmin_func_param(p[i], new_sig);
    }
    strcat(new_sig, ")");

    // write return value
    p = strtok(NULL, "()");
    cat_jasmin_func_param(p[0], new_sig);

    memset(func_sig, 0, ID_MAX_LEN);
    strncpy(func_sig, new_sig, ID_MAX_LEN);
}

static void cat_jasmin_func_param(char param, char *j_func_sig)
{
    switch (param)
    {
        case 'I':
        case 'B':
            strcat(j_func_sig, "I");
            break;
        case 'F':
            strcat(j_func_sig, "F");
            break;
        case 'S':
            strcat(j_func_sig, "Ljava/lang/String;");
            break;
        case 'V':
            strcat(j_func_sig, "V");
            break;
    }
}

static void print_codegen(char *print_type, char *type)
{
    if (strcmp(type, "int32") == 0 || strcmp(type, "float32") == 0)
    {
        CODEGEN("getstatic java/lang/System/out Ljava/io/PrintStream;\n");
        CODEGEN("swap\n");
        CODEGEN("invokevirtual java/io/PrintStream/%s(%c)V\n", print_type, type[0] - 32);
    }
    else
    {
        if (strcmp(type, "bool") == 0)
        {
            CODEGEN("ifne L_cmp_%d\n", LABEL_CNT++);
            CODEGEN("ldc \"false\"\n");
            CODEGEN("goto L_cmp_%d\n", LABEL_CNT++);
            INDENT_LVL--;
            CODEGEN("L_cmp_%d:\n", LABEL_CNT - 2);
            INDENT_LVL++;
            CODEGEN("ldc \"true\"\n");
            INDENT_LVL--;
            CODEGEN("L_cmp_%d:\n", LABEL_CNT - 1);
            INDENT_LVL++;
        }
        CODEGEN("getstatic java/lang/System/out Ljava/io/PrintStream;\n");
        CODEGEN("swap\n");
        CODEGEN("invokevirtual java/io/PrintStream/%s(Ljava/lang/String;)V\n", print_type);
    }
}

static void cmp_codegen(char *cmp_type, char *type)
{
    if (strcmp(type, "int32") == 0)
        CODEGEN("isub\n");
    else
        CODEGEN("fcmpl\n");

    CODEGEN("%s L_cmp_%d\n", cmp_type, LABEL_CNT++);
    CODEGEN("iconst_0\n");
    CODEGEN("goto L_cmp_%d\n", LABEL_CNT++);
    INDENT_LVL--;
    CODEGEN("L_cmp_%d:\n", LABEL_CNT - 2);
    INDENT_LVL++;
    CODEGEN("iconst_1\n");
    INDENT_LVL--;
    CODEGEN("L_cmp_%d:\n", LABEL_CNT - 1);
    INDENT_LVL++;
}