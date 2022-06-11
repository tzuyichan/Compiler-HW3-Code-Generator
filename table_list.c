#include "table_list.h"

#define FAIL_IF(EXP, MSG)                        \
    {                                            \
        if (EXP)                                 \
        {                                        \
            fprintf(stderr, "Error! " MSG "\n"); \
            exit(EXIT_FAILURE);                  \
        }                                        \
    }

struct list_t
{
    Node *first;
};

List *init_list()
{
    List *L;
    FAIL_IF(!(L = malloc(sizeof(List))), "List malloc failure!");
    L->first = NULL;

    return L;
}

Node *init_node()
{
    Node *N;
    FAIL_IF(!(N = malloc(sizeof(Node))), "Node malloc failure!");
    N->index = -1;
    strcpy(N->name, "?");
    strcpy(N->type, "?");
    N->addr = -2;
    N->lineno = -1;
    strcpy(N->func_sig, "?");
    N->next = NULL;

    return N;
}

int enqueue(List *L, Node *N)
{
    Node *p;

    for (p = L->first; p != NULL; p = p->next)
    {
        if (!p->next)
            break;
    } // p = last node in the linked list

    if (!p)
        L->first = N;
    else
        p->next = N;

    return 0;
}

Result *get_entry(List *L, char *name)
{
    for (Node *p = L->first; p != NULL; p = p->next)
    {
        if (strcmp(p->name, name) == 0)
        {
            Result *R;
            FAIL_IF(!(R = malloc(sizeof(Result))), "Lookup result malloc failure!");
            R->addr = p->addr;
            strncpy(R->type, p->type, 8);
            R->lineno = p->lineno;
            strncpy(R->func_sig, p->func_sig, ID_MAX_LEN);
            return R;
        }
    }

    return NULL;
}

Node *dequeue(List *L)
{
    Node *p;
    if ((p = L->first))
    {
        L->first = p->next;
        p->next = NULL;
        return p;
    }
    return NULL;
}

void delete_list(List *L)
{
    Node *p;
    while ((p = dequeue(L)))
        free(p);
    free(L);
}

void list_entry_types(List *L, char *type_str)
{
    if (L->first == NULL)
    {
        strcat(type_str, "V");
        return;
    }
    for (Node *p = L->first; p != NULL; p = p->next)
    {
        char type_abbrev = (p->type)[0] - 32; // ASCII case conversion
        strncat(type_str, &type_abbrev, 1);
    }
}