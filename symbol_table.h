#ifndef SYMBOL_TABLE_H
#define SYMBOL_TABLE_H

#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include "table_list.h"

typedef struct table_t Table;
typedef struct
{
    int current_scope;
    int next_free_addr;
    Table *first;
} Table_head;

Table_head *init_table();
void add_table(Table_head *T);
Result *add_symbol(Table_head *T, char *name, char *type, int lineno, char *func_sig);
Result *find_symbol(Table_head *T, char *name);
Node *dump_next_entry(Table_head *T);
void delete_table(Table_head *T);
void get_func_param_types(Table_head *T, char *type_str);

#endif