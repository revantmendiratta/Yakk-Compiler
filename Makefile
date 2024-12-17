#
# CS250
#
# simple.l: simple parser for the simple "C" language
#
#

all: git-commit scc 

scc: simple.l simple.y
        lex simple.l
        yacc -d simple.y
        gcc -g -o scc lex.yy.c y.tab.c
        echo "To run tests type \"cd tests; ./testall\"" 

clean:
        rm -f scc lex.yy.c y.tab.c y.tab.h *.out *.output *.s *.scc *.gcc tests/*.out tests/*.s tests/*.scc tests/*.gcc test1 test2 test3 test4 test5

.PHONY: git-commit
git-commit:
        git checkout master >> .local.git.out || echo
        git add *.l *.y *.c  tests/total.txt >> .local.git.out  || echo
        git commit -a -m 'Commit' >> .local.git.out || echo
        git push origin master
