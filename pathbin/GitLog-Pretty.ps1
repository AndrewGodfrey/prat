# .SYNOPSIS
# 'Pretty' one-line git log
#
# Alias: glp
git log --pretty="%C(auto)%as: %<(18,trunc)%an %h  %Cgreen%s%Creset" $args
