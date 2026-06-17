$out_dir = 'build';

@default_files = ('main.tex');

$pdflatex = 'pdflatex -synctex=1 -interaction=nonstopmode %O %S';

$clean_ext = 'aux bbl blg fdb_latexmk fls log run.xml synctex.gz toc';