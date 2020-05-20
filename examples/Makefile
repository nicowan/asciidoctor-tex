exemple.tex: exemple.adoc
	asciidoctor-latex exemple.adoc

exemple.pdf: exemple.tex images/*
	xelatex -shell-escape exemple.tex

clean:
	rm -f *.aux *.bcf *.fls *.idx *.ind *.lof *.lot *.out \
		  *.toc *.fdb_latexmk *.log *synctex.gz newEnvironments.tex
	rm -Rf _minted-*