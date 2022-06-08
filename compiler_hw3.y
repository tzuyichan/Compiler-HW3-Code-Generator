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

    extern int yylineno;
    extern int yylex();
    extern FILE *yyin;

    /* Symbol table function - you can add new functions if needed. */
    /* parameters and return type can be changed */
    static void create_sym_table();
    static void insert_symbol(char *name, char *type);
    static void lookup_symbol(char *name);
    static void lookup_func(char *name);
    static void dump_sym_table();
    static char *check_type(char *nterm1, char *nterm2, char *operator);

    /* Global variables */
    bool HAS_ERROR = false;
    char TYPE[8];
    char FUNC_SIG[ID_MAX_LEN];
    char CURRENT_FUNC[ID_MAX_LEN];
    char FUNC_RET_TYPE;
    bool IN_FUNC_SCOPE = false;
    Table_head *T;
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
%type <s_val> ParenthesisExpr Expression 
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
    }
    FuncBlock
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
    : RETURN                { printf("return\n"); }
    | RETURN Expression     { printf("%creturn\n", $2[0]); }
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
    : VAR IDENT Type DeclAssignment     { insert_symbol($2, $3); }
;

DeclAssignment
    : ASSIGN Expression
    | /* empty */
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
    : FOR Expression { check_type($2, $2, "FOR"); } Block
    | FOR ForClause Block
;

ForClause
    : SimpleStmt ';' Expression ';' SimpleStmt
;

SwitchStmt
    : SWITCH Expression Block
;

CaseStmt
    : CASE INT_LIT { printf("case %d\n", $2); } ':' Block
    | DEFAULT ':' Block
;

PrintStmt
    : PRINT ParenthesisExpr         { printf("PRINT %s\n", $2); }
    | PRINTLN ParenthesisExpr       { printf("PRINTLN %s\n", $2); }
;

AssignmentStmt
    : IDENT { lookup_symbol($1); strncpy($1, TYPE, 8); } ASSIGN Expression { check_type($1, $4, $3); printf("ASSIGN\n"); }
    | IDENT { lookup_symbol($1); strncpy($1, TYPE, 8); } ADD_ASSIGN Expression { printf("ADD\n"); }
    | IDENT { lookup_symbol($1); strncpy($1, TYPE, 8); } SUB_ASSIGN Expression { printf("SUB\n"); }
    | IDENT { lookup_symbol($1); strncpy($1, TYPE, 8); } MUL_ASSIGN Expression { printf("MUL\n"); }
    | IDENT { lookup_symbol($1); strncpy($1, TYPE, 8); } QUO_ASSIGN Expression { printf("QUO\n"); }
    | IDENT { lookup_symbol($1); strncpy($1, TYPE, 8); } REM_ASSIGN Expression { printf("REM\n"); }
;

IncDecStmt
    : Operand INC       { printf("INC\n"); }
    | Operand DEC       { printf("DEC\n"); }
;

ParenthesisExpr
    : '(' Expression ')'        { $$ = $2; }
;

Expression
    : LogOrExpr
;

LogOrExpr
    : LogAndExpr
    | LogOrExpr LOR LogAndExpr           { $$ = check_type($1, $3, $2); printf("LOR\n"); }
;

LogAndExpr
    : CmpExpr
    | LogAndExpr LAND CmpExpr          { $$ = check_type($1, $3, $2); printf("LAND\n"); }
;

CmpExpr
    : AddExpr
    | CmpExpr EQL AddExpr          { $$ = check_type($1, $3, $2); printf("EQL\n"); }
    | CmpExpr NEQ AddExpr          { $$ = check_type($1, $3, $2); printf("NEQ\n"); }
    | CmpExpr LSS AddExpr          { $$ = check_type($1, $3, $2); printf("LSS\n"); }
    | CmpExpr LEQ AddExpr          { $$ = check_type($1, $3, $2); printf("LEQ\n"); }
    | CmpExpr GTR AddExpr          { $$ = check_type($1, $3, $2); printf("GTR\n"); }
    | CmpExpr GEQ AddExpr          { $$ = check_type($1, $3, $2); printf("GEQ\n"); }
;

AddExpr
    : MulExpr
    | AddExpr ADD MulExpr           { $$ = check_type($1, $3, $2); printf("ADD\n"); }
    | AddExpr SUB MulExpr           { $$ = check_type($1, $3, $2); printf("SUB\n"); }
;

MulExpr
    : CastExpr
    | MulExpr MUL CastExpr           { $$ = check_type($1, $3, $2); printf("MUL\n"); }
    | MulExpr QUO CastExpr           { $$ = check_type($1, $3, $2); printf("QUO\n"); }
    | MulExpr REM CastExpr           { $$ = check_type($1, $3, $2); printf("REM\n"); }
;

CastExpr
    : UnaryExpr
    | INT '(' AddExpr ')'          { $$ = "int32"; printf("f2i\n"); }
    | FLOAT '(' AddExpr ')'        { $$ = "float32"; printf("i2f\n"); }
;

UnaryExpr
    : PrimaryExpr
    | ADD PrimaryExpr       { $$ = check_type($2, $2, $1); printf("POS\n"); }
    | SUB PrimaryExpr       { $$ = check_type($2, $2, $1); printf("NEG\n"); }
    | NOT UnaryExpr         { $$ = check_type($2, $2, $1); printf("NOT\n"); }
;

PrimaryExpr
    : Operand
    | '"' STRING_LIT '"'    { $$ = "string"; printf("STRING_LIT %s\n", $2); }
    | Boolean
    | ParenthesisExpr
    | FunctionCall
;

FunctionCall
    : IDENT '(' FuncCallParamList ')' {
        lookup_func($1);
        printf("call: %s%s\n", $1, FUNC_SIG);
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
    | IDENT             { lookup_symbol($1); strncpy($$, TYPE, 8); }
;

Boolean
    : TRUE_             { $$ = "bool"; printf("TRUE 1\n"); }
    | FALSE_            { $$ = "bool"; printf("FALSE 0\n"); }
;

Constant
    : INT_LIT           { $$ = "int32"; printf("INT_LIT %d\n", $1); }
    | FLOAT_LIT         { $$ = "float32"; printf("FLOAT_LIT %f\n", $1); } 
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

    // initialize global strings
    memset(TYPE, 0, 8);
    memset(FUNC_SIG, 0, ID_MAX_LEN);
    memset(CURRENT_FUNC, 0, ID_MAX_LEN);

    yylineno = 0;
    T = init_table();
    yyparse();

	printf("Total lines: %d\n", yylineno);
    fclose(yyin);
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

static void insert_symbol(char *name, char *type) {
    char type_str[ID_MAX_LEN];
    char func_sig[ID_MAX_LEN];
    memset(type_str, 0, ID_MAX_LEN);
    memset(func_sig, 0, ID_MAX_LEN);

    // check if symbol has already been declared
    Result *R = find_symbol(T, name);
    if (R && R->scope == T->current_scope)
    {
        printf("error:%d: %s redeclared in this block. previous declaration at line %d\n",
               yylineno, name, R->lineno);
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

    free(entry);
}

static void lookup_symbol(char *name) {
    Result *R = find_symbol(T, name);
    /* int lineno = IN_FUNC_SCOPE ? yylineno + 1 : yylineno; */

    if (R)
    {
        strncpy(TYPE, R->type, 8);
        printf("IDENT (name=%s, address=%d)\n", name, R->addr); 
    }
    else
    {
        strncpy(TYPE, "ERROR", 8);
        printf("error:%d: undefined: %s\n", yylineno + 1, name);
    }
    free(R);
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
            default:
                strncpy(TYPE, "void", 8);
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
            return "bool";
        }
        else
        {
            char *wrong_type = strcmp(nterm1, "bool") == 0 ? nterm2 : nterm1;
            printf("error:%d: invalid operation: (operator %s not defined on %s)\n",
                yylineno, op, wrong_type);
            return "ERROR";
        }
    }

    if (strcmp(op, "REM") == 0)
    {
        if (strcmp(nterm1, nterm2) == 0 && strcmp(nterm1, "int32") == 0)
        {
            return "int32";
        }
        else
        {
            char *wrong_type = strcmp(nterm1, "int32") == 0 ? nterm2 : nterm1;
            printf("error:%d: invalid operation: (operator %s not defined on %s)\n",
                yylineno, op, wrong_type);
            return "ERROR";
        }
    }

    if ((strcmp(op, "FOR") == 0 || strcmp(op, "IF") == 0)
        && strcmp(nterm1, "bool") != 0)
    {
        if (strcmp(nterm1, "ERROR") == 0)  // don't test for error type in condition
        {
            return "bool";
        }
        printf("error:%d: non-bool (type %s) used as for condition\n",
               yylineno + 1, nterm1, op);
        return "ERROR";
    }

    if (strcmp(nterm1, nterm2) != 0)
    {
        printf("error:%d: invalid operation: %s (mismatched types %s and %s)\n",
               yylineno, op, nterm1, nterm2);
        return "ERROR";
    }

    if (strcmp(op, "EQL") == 0 || strcmp(op, "NEQ") == 0
        || strcmp(op, "LSS") == 0 || strcmp(op, "LEQ") == 0
        || strcmp(op, "GTR") == 0 || strcmp(op, "GEQ") == 0)
    {
        return "bool";
    }

    return nterm1;
}