PDFLATEX = pdflatex -halt-on-error -file-line-error -interaction=nonstopmode
BIBTEX = bibtex

# -nosafe needed for opacity: https://tex.stackexchange.com/a/473911
ASYMPOTE = asy -nosafe

FIGURES = figures/normal.pdf figures/overlap.pdf figures/quote.pdf

zipbomb.pdf: zipbomb.tex zipbomb.bib $(FIGURES)

%.pdf: %.tex
	rm -f "$*.aux" "$*.bbl"
	$(PDFLATEX) -draftmode "$*"
	$(BIBTEX) "$*"
	$(PDFLATEX) -draftmode "$*"
	$(PDFLATEX) "$*"

figures/%.pdf: figures/%.asy figures/common.asy
	$(ASYMPOTE) -f pdf -cd "$(dir $<)" "$(notdir $<)"

.PHONY: clean
clean:
	rm -rf $(addprefix zipbomb,.aux .ent .log .pdf .bbl .blg .out)
