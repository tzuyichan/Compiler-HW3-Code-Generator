CC := gcc
CFLAGS := -Wall -O0 -ggdb
YFLAG := -d -v
LEX_SRC := compiler_hw3.l
YAC_SRC := compiler_hw3.y
HEADER := compiler_hw_common.h
COMPILER := mycompiler
JAVABYTECODE := hw3.j
EXEC := Main
v := 0

all: ${COMPILER}

${COMPILER}: lex.yy.c y.tab.c symbol_table.o table_list.o
	${CC} ${CFLAGS} -o $@ $^

lex.yy.c: ${LEX_SRC} ${HEADER}
	lex $<

y.tab.c: ${YAC_SRC} ${HEADER}
	yacc ${YFLAG} $<

${JAVABYTECODE}: ${COMPILER}
ifeq (,$(wildcard ${JAVABYTECODE}))
	@echo "${JAVABYTECODE} does not exist."
endif

${EXEC}.class: ${JAVABYTECODE}
	@java -jar jasmin.jar -g ${JAVABYTECODE}

run: ${EXEC}.class
	@java ${EXEC} || java -Xverify:none ${EXEC}

judge: all
	@judge -v ${v}

clean:
	rm -rf ${COMPILER} y.tab.* y.output lex.* ${EXEC}.class *.j *.o *.log *.dSYM tmp.out
