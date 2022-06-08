#ifndef TABLE_LIST_H
#define TABLE_LIST_H

#include <stdio.h>
#include <stdlib.h>
#include <stdbool.h>
#include <string.h>
#include "compiler_hw_common.h"

typedef struct list_t List;
typedef struct node_t
{
    int index;
    char name[ID_MAX_LEN];
    char type[8];
    int addr;
    int lineno;
    char func_sig[ID_MAX_LEN];
    struct node_t *next;
} Node;

typedef struct
{
    int scope;
    int addr;
    char type[8];
    int lineno;
    char func_sig[ID_MAX_LEN];
} Result;

List *init_list();
Node *init_node();
int enqueue(List *L, Node *N);
Result *get_entry(List *L, char *name);
Node *dequeue(List *L);
void delete_list(List *L);
void list_entry_types(List *L, char *type_str);

#endif