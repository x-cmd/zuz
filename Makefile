PDFLATEX = pdflatex -halt-on-error -file-line-error -interaction=nonstopmode
BIBTEX = bibtex

GRAPHS =

zipbomb.pdf: zipbomb.tex zipbomb.bib $(GRAPHS)

%.pdf %.bbl: %.tex
	$(PDFLATEX) $*
	$(BIBTEX) $*
	$(PDFLATEX) $*
	$(PDFLATEX) $*

.PHONY: clean
clean:
	rm -rf $(addprefix zipbomb,.aux .ent .log .pdf .bbl .blg .out)
