setenv WORKDIR `pwd`
source $WORKDIR/scripts/env//env.cshrc
source $WORKDIR/scripts/env/setup.cshrc
alias setup " pushd . ; cdw ; source env/setup* ; popd"
alias cp cp -f
alias precmd 'echo -n "\033]0;${HOST}:$cwd\007"'

