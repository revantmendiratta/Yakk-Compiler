/*
 * CS250
 *
 * simple.y: simple parser for the simple "C" language
 * 
 *
 */

%token  <string_val> WORD

%token  NOTOKEN LPARENT RPARENT LBRACE RBRACE LCURLY RCURLY COMA SEMICOLON EQUAL STRING_CONST LONG LONGSTAR VOID CHARSTAR CHARSTARSTAR INTEGER_CONST AMPERSAND OROR ANDAND EQUALEQUAL NOTEQUAL LESS GREAT LESSEQUAL GREATEQUAL PLUS MINUS TIMES DIVIDE PERCENT IF ELSE WHILE DO FOR CONTINUE BREAK RETURN

%union  {
  char *string_val;
  int nargs;
  int my_nlabel;
}

%{
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <assert.h>

  int yylex(void);
  int yyerror(const char *s);

  extern int line_number;
  const char * input_file;
  char * asm_file;
  FILE * fasm;

#define MAX_ARGS 5
  int nargs;
  char * args_table[MAX_ARGS];

#define MAX_GLOBALS 100
  int nglobals = 0;
  char * global_vars_table[MAX_GLOBALS];
  int global_vars_type[MAX_GLOBALS];

#define MAX_LOCALS 32
  int nlocals = 0;
  char * local_vars_table[MAX_LOCALS];
  int local_vars_type[MAX_LOCALS];


#define MAX_STRINGS 100
  int nstrings = 0;
  char * string_table[MAX_STRINGS];

  char *byteStack[] = { "bl", "r10b", "r13b", "r14b", "r15b"};
  char *regStk[]=      { "rbx", "r10", "r13", "r14", "r15"};
  char nregStk = sizeof(regStk)/sizeof(char*);

  char *regArgs[]= { "rdi", "rsi", "rdx", "rcx", "r8", "r9"};
  char nregArgs = sizeof(regArgs)/sizeof(char*);

#define MAX_LOOPS 30
  int track_loop[MAX_LOOPS];
  int track_loop_top = 0; 


  int current_type;

  int top = 0;

  int nargs =0;

  int nlabel = 0;

  int loop_counter = 0;


  %}

  %%

  goal: program
  ;

program :
function_or_var_list;

function_or_var_list:
function_or_var_list function
| function_or_var_list global_var
| /*empty */
;

function:
var_type WORD
{
  fprintf(fasm, "\t.text\n");
  fprintf(fasm, ".globl %s\n", $2);
  fprintf(fasm, "%s:\n", $2);



  fprintf(fasm, "# Save registers\n");
  fprintf(fasm, "# Push one extra to align stack to 16bytes\n");
  fprintf(fasm, "\tpushq %%rbx\n");
  fprintf(fasm, "\tpushq %%r10\n");
  fprintf(fasm, "\tpushq %%r13\n");
  fprintf(fasm, "\tpushq %%r14\n");
  fprintf(fasm, "\tpushq %%r15\n");
  fprintf(fasm, "\tsubq $%d,%%rsp\n", 8*MAX_LOCALS); 
  nlocals = 0;
  top = 0; 
}
LPARENT arguments RPARENT 
{
  /*
     fprintf(fasm, "\t# Save arguments\n");
     for (int i=0; i < nlocals; i++) {
     fprintf(fasm, "\tmovq %%%s,%d(%%rsp)\n", regArgs[i], 8*(MAX_LOCALS-i) );
     }
   */
  for (int i = 0; i < nlocals; i++) {
    if (i < nregArgs) {
      fprintf(fasm, "\tmovq %%%s, %d(%%rsp)\n", regArgs[i], 8 * (MAX_LOCALS - i));
    } else {
      fprintf(fasm, "\tmovq %d(%%rsp), %d(%%rsp)\n", 8 * (i - nregArgs), 8 * (MAX_LOCALS - i));
    }
  }
}
compound_statement
{
  fprintf(fasm, "# Restore registers\n");
  fprintf(fasm, "\taddq $%d,%%rsp\n", 8*MAX_LOCALS);
  fprintf(fasm, "\tpopq %%r15\n");
  fprintf(fasm, "\tpopq %%r14\n");
  fprintf(fasm, "\tpopq %%r13\n");
  fprintf(fasm, "\tpopq %%r10\n");
  fprintf(fasm, "\tpopq %%rbx\n");
  fprintf(fasm, "\tret\n");
}
;

arg_list:
arg
| arg_list COMA arg
;

arguments:
arg_list
| /*empty*/
;

arg: var_type WORD {
       char *id = $2;
       assert(nlocals < MAX_LOCALS);
       local_vars_table[nlocals] = id;
       local_vars_type[nlocals] = current_type;
       nlocals++;
     }
;

global_var: 
var_type global_var_list SEMICOLON;

global_var_list: WORD {
                   char * id = $1;
                   fprintf(fasm,"     # Defining global var %s\n", id);
                   fprintf(fasm,"     \t.data\n");
                   fprintf(fasm,"     \t.comm %s, 8\n", id);
                   fprintf(fasm,"\n");
                   global_vars_table[nglobals] = id;
                   global_vars_type[nglobals] = current_type;
                   nglobals++;
                 }
| global_var_list COMA WORD {

}
;

var_type:
CHARSTAR {
  current_type = CHARSTAR;
}
| CHARSTARSTAR {
  current_type = CHARSTARSTAR;
}
| LONG {
  current_type = LONG;
}
| LONGSTAR {
  current_type = LONGSTAR;
}
| VOID {
  current_type = VOID;
};
assignment:
WORD EQUAL expression {
  char * id = $<string_val>1;

  //check if var is a global or local var
  int localvar = -1;
  for (int i = 0; i < nlocals; i++) {
    if (strcmp(id, local_vars_table[i]) == 0) {
      localvar = i;
      break;
    }
  }
  if (localvar != -1) {
    //local variable assignment
    fprintf(fasm, "\tmovq %%rbx, %d(%%rsp)\n", 8 * (MAX_LOCALS - localvar));

  }
  else if (localvar == -1) {
    //global variable assignment
    fprintf(fasm, "\tmovq %%rbx, %s\n", id);
  }
  top = 0;
}
| WORD LBRACE expression RBRACE {
  // Lookup local var
  int localvar = -1;
  char * id = $<string_val>1;

  for (int i = 0; i < nlocals; i++) {
    if (!strcmp(local_vars_table[i], id)) {
      localvar = i;
      break;
    }
  }

  int type;
  if (localvar >= 0) {
    type = local_vars_type[localvar];
  } else {
    int globalvar;
    for (int i = 0; i < nglobals; i++) {
      if (strcmp(global_vars_table[i], id) == 0) {
        globalvar = i;
        break;
      }
    }
    type = global_vars_type[globalvar];
  }


  if(type == CHARSTAR)
  {
    fprintf(fasm, "\tmovq $1, %%rax\n");
  }
  else 
  {
    fprintf(fasm, "\tmovq $8, %%rax\n");
  }

  fprintf(fasm, "\timulq %%rax, %%%s\n", regStk[top-1]);

  if (localvar != -1) {
    // locar var
    fprintf(fasm, "\tmovq %d(%%rsp), %%%s\n", 8*(MAX_LOCALS-localvar), regStk[top]);
    top++;
  }
  else {
    // global var
    fprintf(fasm, "\tmovq %s, %%%s\n", id, regStk[top]);
    top++;
  }

  fprintf(fasm, "\taddq %%%s, %%%s\n", regStk[top-1], regStk[top-2]);
  top--;
}
EQUAL expression {
  if (current_type == CHARSTAR) {
    fprintf(fasm, "\tmovb %%%s, %%al\n", byteStack[top-1]);
    fprintf(fasm, "\txor %%%s, %%%s\n", regStk[top-1], regStk[top-1]);
    fprintf(fasm, "\tmovb %%al, %%%s\n", byteStack[top-1]);
    fprintf(fasm, "\tmovb %%%s, (%%%s)\n", byteStack[top-1], regStk[top-2]);
  }
  else {
    fprintf(fasm, "\tmovq %%%s, (%%%s)\n", regStk[top-1], regStk[top-2]);
  }
  top-=2;
}
;
call:
WORD LPARENT call_arguments RPARENT {
  char * funcName = $<string_val>1;
  int nargs = $<nargs>3;
  int i;
  fprintf(fasm,"     # func=%s nargs=%d\n", funcName, nargs);
  fprintf(fasm,"     # Move values from reg stack to reg args\n");
  for (i=nargs-1; i>=0; i--) {
    if (i < nregArgs) {
      fprintf(fasm, "\tmovq %%%s, %%%s\n", regStk[top - 1], regArgs[i]);
      top--;
    } else {
      fprintf(fasm, "\tpushq %%%s\n", regStk[top - 1]);
      top--;
    }
  }
  if (!strcmp(funcName, "printf")) {
    // printf has a variable number of arguments
    // and it need the following
    fprintf(fasm, "\tmovl    $0, %%eax\n");
  }
  fprintf(fasm, "\tcall %s\n", funcName);
  fprintf(fasm, "\tmovq %%rax, %%%s\n", regStk[top]);
  top++;
}
;

call_arg_list:
expression {
  $<nargs>$=1;
}
| call_arg_list COMA expression {
  $<nargs>$++;
}

;

call_arguments:
call_arg_list { $<nargs>$=$<nargs>1; }
| /*empty*/ { $<nargs>$=0;}
;

expression :
logical_or_expr
;
logical_or_expr:
logical_and_expr
| logical_or_expr OROR logical_and_expr {
  fprintf(fasm,"\n\t# ||\n");
  int label = nlabel++;
  fprintf(fasm, "\tcmpq $0, %%%s\n", regStk[top - 1]);
  fprintf(fasm, "\tjne short_circuit_or_%d\n", label); 
  top--;
  fprintf(fasm, "\tcmpq $0, %%%s\n", regStk[top - 1]);
  fprintf(fasm, "\tje short_circuit_false_%d\n", label); 
  fprintf(fasm, "short_circuit_or_%d:\n", label);
  fprintf(fasm, "\tmovq $1, %%%s\n", regStk[top - 1]);
  fprintf(fasm, "\tjmp end_or_%d\n", label);
  fprintf(fasm, "short_circuit_false_%d:\n", label);
  fprintf(fasm, "\tmovq $0, %%%s\n", regStk[top - 1]);
  fprintf(fasm, "end_or_%d:\n", label);
}
;

logical_and_expr:
equality_expr
| logical_and_expr ANDAND equality_expr {
  fprintf(fasm, "\n\t# &&\n");
  int label = nlabel++;
  fprintf(fasm, "\tcmpq $0, %%%s\n", regStk[top - 1]); 
  fprintf(fasm, "\tje short_circuit_and_%d\n", label);
  top--;
  fprintf(fasm, "\tcmpq $0, %%%s\n", regStk[top - 1]);
  fprintf(fasm, "\tjne short_circuit_true_%d\n", label); 
  fprintf(fasm, "short_circuit_and_%d:\n", label);
  fprintf(fasm, "\tmovq $0, %%%s\n", regStk[top - 1]); 
  fprintf(fasm, "\tjmp end_and_%d\n", label);
  fprintf(fasm, "short_circuit_true_%d:\n", label);
  fprintf(fasm, "\tmovq $1, %%%s\n", regStk[top - 1]);
  fprintf(fasm, "end_and_%d:\n", label);
}
;


equality_expr:
relational_expr
| equality_expr EQUALEQUAL relational_expr {
  fprintf(fasm, "\n\t# =\n");
  fprintf(fasm, "\tmovq $0, %%rax\n");
  fprintf(fasm, "\tcmpq %%%s, %%%s\n", regStk[top-1], regStk[top-2]);
  fprintf(fasm, "\tsete %%al\n");
  fprintf(fasm, "\tmovq %%rax, %%%s\n", regStk[top-2]);
  top--;

}
| equality_expr NOTEQUAL relational_expr {
  fprintf(fasm, "\n\t# !=\n");
  fprintf(fasm, "\tmovq $0, %%rax\n");
  fprintf(fasm, "\tcmpq %%%s, %%%s\n", regStk[top-1], regStk[top-2]);
  fprintf(fasm, "\tsetne %%al\n");
  fprintf(fasm, "\tmovq %%rax, %%%s\n", regStk[top-2]);
  top--;
}
;

relational_expr:
additive_expr
| relational_expr LESS additive_expr {
  fprintf(fasm, "\n\t# <\n");
  fprintf(fasm, "\tmovq $0, %%rax\n");
  fprintf(fasm, "\tcmpq %%%s, %%%s\n", regStk[top-1], regStk[top-2]);
  fprintf(fasm, "\tsetl %%al\n");
  fprintf(fasm, "\tmovq %%rax, %%%s\n", regStk[top-2]);
  top--;

}
| relational_expr GREAT additive_expr {
  fprintf(fasm, "\n\t# >\n");
  fprintf(fasm, "\tmovq $0, %%rax\n");
  fprintf(fasm, "\tcmpq %%%s, %%%s\n", regStk[top-1], regStk[top-2]);
  fprintf(fasm, "\tsetg %%al\n");
  fprintf(fasm, "\tmovq %%rax, %%%s\n", regStk[top-2]);
  top--;
}
| relational_expr LESSEQUAL additive_expr {
  fprintf(fasm, "\n\t# <=\n");
  fprintf(fasm, "\tmovq $0, %%rax\n");
  fprintf(fasm, "\tcmpq %%%s, %%%s\n", regStk[top-1], regStk[top-2]);
  fprintf(fasm, "\tsetle %%al\n");
  fprintf(fasm, "\tmovq %%rax, %%%s\n", regStk[top-2]);
  top--;
}
| relational_expr GREATEQUAL additive_expr {
  fprintf(fasm, "\n\t# >=\n");
  fprintf(fasm, "\tmovq $0, %%rax\n");
  fprintf(fasm, "\tcmpq %%%s, %%%s\n", regStk[top-1], regStk[top-2]);
  fprintf(fasm, "\tsetge %%al\n");
  fprintf(fasm, "\tmovq %%rax, %%%s\n", regStk[top-2]);
  top--;
}
;

additive_expr:
multiplicative_expr
| additive_expr PLUS multiplicative_expr {
  fprintf(fasm,"\n\t# +\n");
  if (top<nregStk) {
    fprintf(fasm, "\taddq %%%s,%%%s\n", regStk[top-1], regStk[top-2]);
    top--;
  }
}
| additive_expr MINUS multiplicative_expr {
  fprintf(fasm,"\n\t# -\n");
  if (top < nregStk) {
    fprintf(fasm, "\tsubq %%%s,%%%s\n", regStk[top-1], regStk[top-2]);
    top--;
  }
}
;

multiplicative_expr:
primary_expr
| multiplicative_expr TIMES primary_expr {
  fprintf(fasm,"\n\t# *\n");
  if (top<nregStk) {
    fprintf(fasm, "\timulq %%%s,%%%s\n", regStk[top-1], regStk[top-2]);
    top--;
  }
}
| multiplicative_expr DIVIDE primary_expr {
  fprintf(fasm,"\n\t# /\n");
  if (top < nregStk) {
    fprintf(fasm, "\tmovq %%%s, %%rax\n", regStk[top - 2]);
    fprintf(fasm, "\txorq %%rdx, %%rdx\n");
    fprintf(fasm, "\tidivq %%%s\n", regStk[top - 1]);
    fprintf(fasm, "\tmovq %%rax, %%%s\n", regStk[top - 2]);
    top--;
  }
}
| multiplicative_expr PERCENT primary_expr {
  fprintf(fasm,"\n\t# %%\n");
  if (top < nregStk) {
    fprintf(fasm, "\tmovq %%%s, %%rax\n", regStk[top - 2]);
    fprintf(fasm, "\txorq %%rdx, %%rdx\n");
    fprintf(fasm, "\tidivq %%%s\n", regStk[top - 1]);
    fprintf(fasm, "\tmovq %%rdx, %%%s\n", regStk[top - 2]);
    top--;
  }
}
;
primary_expr:
STRING_CONST {
  // Add string to string table.
  // String table will be produced later
  string_table[nstrings]=$<string_val>1;
  fprintf(fasm, "\t#top=%d\n", top);
  fprintf(fasm, "\n\t# push string %s top=%d\n",
      $<string_val>1, top);
  if (top<nregStk) {
    fprintf(fasm, "\tmovq $string%d, %%%s\n", 
        nstrings, regStk[top]);
    //fprintf(fasm, "\tmovq $%s,%%%s\n", 
    //$<string_val>1, regStk[top]);
    top++;
  }
  nstrings++;
}
| call
| WORD {
  // Assume it is a global variable
  // TODO: Implement also local variables
  char * id = $<string_val>1;

  //check if word is a local or global variable
  int localvar = -1;
  for (int i = 0; i < nlocals; i++) {
    if (strcmp(id, local_vars_table[i]) == 0) {
      localvar = i;
      break;
    }
  }
  if (localvar != -1) {
    // saving localvar into a register
    fprintf(fasm, "\tmovq %d(%%rsp), %%%s\n", 8 * (MAX_LOCALS-localvar), regStk[top]);
  }
  else {
    // saving global into a register
    fprintf(fasm, "\tmovq %s,%%%s\n", id, regStk[top]);
  }
  top++; //increment to next register on the register stack 
}
| WORD LBRACE expression RBRACE {
  // Lookup local var
  int localvar = -1;
  char * id = $<string_val>1;

  for (int i = 0; i < nlocals; i++) {
    if (strcmp(local_vars_table[i], id) == 0) {
      localvar = i;
      break;
    }
  }

  int type;
  if (localvar >= 0) {
    type = local_vars_type[localvar];
  } else {
    int globalvar;
    for (int i = 0; i < nglobals; i++) {
      if (strcmp(global_vars_table[i], id) == 0) {
        globalvar = i;
        break;
      }
    }
    type = global_vars_type[globalvar];
  }

  if(type == CHARSTAR)
  {
    fprintf(fasm, "\t#Multiply the index by 1\n");
    fprintf(fasm, "\tmovq $1, %%rax\n");
  }
  else 
  {
    fprintf(fasm, "\t#Multiply the index by 8\n");
    fprintf(fasm, "\tmovq $8, %%rax\n");
  }

  fprintf(fasm, "\timulq %%rax, %%%s\n", regStk[top-1]);

  if (localvar>=0) {
    // local var
    fprintf(fasm, "\tmovq %d(%%rsp), %%%s\n", 8*(MAX_LOCALS-localvar), regStk[top]);
    top++;
  }
  else {
    // global var
    fprintf(fasm, "\tmovq %s, %%%s\n", id, regStk[top]);
    top++;
  }

  fprintf(fasm, "\taddq %%%s, %%%s\n", regStk[top-1], regStk[top-2]);
  top--;

  //dereference
  fprintf(fasm, "\tmovq (%%%s), %%%s\n", regStk[top-1], regStk[top-1]);

  if(type == CHARSTAR)
  {
    fprintf(fasm, "\tmovb %%%s, %%bpl\n", byteStack[top-1]);
    fprintf(fasm, "\txor %%%s, %%%s\n", regStk[top-1], regStk[top-1]);
    fprintf(fasm, "\tmovb %%bpl, %%%s\n", byteStack[top-1]);

  }



}
| AMPERSAND WORD {
  int localvar = -1;
  char * id = $<string_val>2;

  for (int i = 0; i < nlocals; i++) {
    if (strcmp(id, local_vars_table[i]) == 0) {
      localvar = i;
      break;
    }
  }
  if (localvar >= -1) {
    // local array
    fprintf(fasm, "\tleaq %d(%%rsp), %%%s\n", 8*(MAX_LOCALS-localvar), regStk[top]);
    top++;
  }
  else {
    // global array
    fprintf(fasm, "\tleaq %s, %%%s\n", id, regStk[top]);
    top++;
  }

}
| INTEGER_CONST {
  fprintf(fasm, "\n\t# push %s\n", $<string_val>1);
  if (top<nregStk) {
    fprintf(fasm, "\tmovq $%s,%%%s\n",  $<string_val>1, regStk[top]);
    top++;
  }
}
| LPARENT expression RPARENT
;

compound_statement:
LCURLY statement_list RCURLY
;

statement_list:
statement_list statement
| /*empty*/
;

local_var:
var_type local_var_list SEMICOLON;

local_var_list: WORD {
  char *id = $1;
  assert(nlocals < MAX_LOCALS);
  local_vars_table[nlocals] = id;
  local_vars_type[nlocals] = current_type;
  nlocals++;
}
| local_var_list COMA WORD {
  char *id = $3;
  assert(nlocals < MAX_LOCALS);
  local_vars_table[nlocals] = id;
  local_vars_type[nlocals] = current_type;
  nlocals++;
}
;

statement:
assignment SEMICOLON
| call SEMICOLON {
  top = 0; /* Reset register stack */
}
| local_var
| compound_statement
| IF LPARENT expression RPARENT {
  $<my_nlabel>1 = nlabel++;
  fprintf(fasm, "# start if statement %d\n", $<my_nlabel>1 );
  fprintf(fasm, "\tcmpq $0, %%%s\n", regStk[top-1]);
  fprintf(fasm, "\tje if_end_%d\n", $<my_nlabel>1);
  top--;
} statement {
  fprintf(fasm, "\tjmp if_abs_end_%d\n", $<my_nlabel>1);
  fprintf(fasm, "if_end_%d:\n", $<my_nlabel>1);
} else_optional {
  fprintf(fasm, "if_abs_end_%d:\n", $<my_nlabel>1);
}
| WHILE LPARENT {
  track_loop[track_loop_top++] = nlabel++;
  fprintf(fasm, "\n\t# start WHILE loop\n");
  fprintf(fasm, "loop_continue_%d:\n", track_loop[track_loop_top-1]); 
}
expression RPARENT {
  fprintf(fasm, "\tcmpq $0, %%%s\n", regStk[top-1]);
  fprintf(fasm, "\tje loop_end_%d\n", track_loop[track_loop_top-1]); 
  top--;
}
statement {
  fprintf(fasm, "\tjmp loop_continue_%d\n", track_loop[track_loop_top-1]); 
  fprintf(fasm, "loop_end_%d:\n", track_loop[track_loop_top-1]);
  track_loop_top--;
}
| DO {
  track_loop[track_loop_top++] = nlabel++; 
  fprintf(fasm, "\n\t# start DO/WHILE loop\n");
  fprintf(fasm, "loop_continue_%d:\n", track_loop[track_loop_top-1]);
}
statement WHILE LPARENT expression {
  fprintf(fasm, "\tcmpq $0, %%%s\n", regStk[top-1]);
  fprintf(fasm, "\tjne loop_continue_%d\n", track_loop[track_loop_top-1]);
  top--;
}
RPARENT SEMICOLON {
  fprintf(fasm, "loop_end_%d:\n", track_loop[track_loop_top-1]);
  track_loop_top--;
}
| FOR LPARENT assignment SEMICOLON {
  fprintf(fasm, "# \tstart for loop_%di\n", nlabel);
  track_loop[track_loop_top++] = nlabel++;
  fprintf(fasm, "loop_start_%d:\n", track_loop[track_loop_top-1]);
}
expression SEMICOLON {
  fprintf(fasm, "\tcmpq $0, %%%s\n", regStk[top-1]);
  fprintf(fasm, "\tje loop_end_%d\n", track_loop[track_loop_top-1]);
  fprintf(fasm, "\tjne loop_body_start_%d\n", track_loop[track_loop_top-1]);
  top--;
  fprintf(fasm, "loop_continue_%d:\n", track_loop[track_loop_top-1]);
} 
assignment RPARENT{
  fprintf(fasm, "\tjmp loop_start_%d\n", track_loop[track_loop_top-1]);
  fprintf(fasm, "loop_body_start_%d:\n", track_loop[track_loop_top-1]);
}
statement {
  fprintf(fasm, "\tjmp loop_continue_%d\n", track_loop[track_loop_top-1]);
  fprintf(fasm, "loop_end_%d:\n", track_loop[track_loop_top-1]);
  track_loop_top--;
}

| jump_statement
;

else_optional:
ELSE  statement 
| /* empty */ 
;

jump_statement:
CONTINUE SEMICOLON {
  fprintf(fasm, "\n\t# CONTINUE\n");
  fprintf(fasm, "\tjmp loop_continue_%d\n", track_loop[track_loop_top - 1]);
}
| BREAK SEMICOLON {
  fprintf(fasm, "\n\t# BREAK\n");
  fprintf(fasm, "\tjmp loop_end_%d\n", track_loop[track_loop_top - 1]);
}
| RETURN expression SEMICOLON {
  fprintf(fasm, "\n\t# RETURN\n");
  fprintf(fasm, "\tmovq %%rbx, %%rax\n");
  top = 0;

  fprintf(fasm, "\taddq $%d,%%rsp\n", 8*MAX_LOCALS);
  fprintf(fasm, "# Restore registers\n");
  fprintf(fasm, "\tpopq %%r15\n");
  fprintf(fasm, "\tpopq %%r14\n");
  fprintf(fasm, "\tpopq %%r13\n");
  fprintf(fasm, "\tpopq %%r10\n");
  fprintf(fasm, "\tpopq %%rbx\n");
  fprintf(fasm, "\tret\n");

}
;

%%

void yyset_in (FILE *  in_str );

  int
yyerror(const char * s)
{
  fprintf(stderr,"%s:%d: %s\n", input_file, line_number, s);
}


  int
main(int argc, char **argv)
{
  printf("-------------WARNING: You need to implement global and local vars ------\n");
  printf("------------- or you may get problems with top------\n");

  // Make sure there are enough arguments
  if (argc <2) {
    fprintf(stderr, "Usage: simple file\n");
    exit(1);
  }

  // Get file name
  input_file = strdup(argv[1]);

  int len = strlen(input_file);
  if (len < 2 || input_file[len-2]!='.' || input_file[len-1]!='c') {
    fprintf(stderr, "Error: file extension is not .c\n");
    exit(1);
  }

  // Get assembly file name
  asm_file = strdup(input_file);
  asm_file[len-1]='s';

  // Open file to compile
  FILE * f = fopen(input_file, "r");
  if (f==NULL) {
    fprintf(stderr, "Cannot open file %s\n", input_file);
    perror("fopen");
    exit(1);
  }

  // Create assembly file
  fasm = fopen(asm_file, "w");
  if (fasm==NULL) {
    fprintf(stderr, "Cannot open file %s\n", asm_file);
    perror("fopen");
    exit(1);
  }

  // Uncomment for debugging
  //fasm = stderr;

  // Create compilation file
  // 
  yyset_in(f);
  yyparse();

  // Generate string table
  int i;
  for (i = 0; i<nstrings; i++) {
    fprintf(fasm, "string%d:\n", i);
    fprintf(fasm, "\t.string %s\n\n", string_table[i]);
  }

  fclose(f);
  fclose(fasm);

  return 0;
}
