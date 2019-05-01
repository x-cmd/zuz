library(data.table)
library(ggplot2)
library(grid)

output_filename <- commandArgs(trailingOnly=TRUE)[[1]]

data <- fread("compressed_size.csv")
data.max <- data[, .(max_uncompressed_size=max(uncompressed_size)), .(engine, compressed_size)]

# Don't show bzip2 on this graph.
data.max <- data.max[engine != "bzip2"]
# Info-ZIP and zlib are exactly coincident over their shared domain. Assert
# that it is so, because the labels down below make that assumption.
(function() {
	shared_domain <- intersect(data.max[engine == "infozip"]$compressed_size, data.max[engine == "infozip"]$compressed_size)
	infozip <- data.max[engine == "infozip" & compressed_size %in% shared_domain]$max_uncompressed_size
	zlib <- data.max[engine == "zlib" & compressed_size %in% shared_domain]$max_uncompressed_size
	if (!all(infozip == zlib)) {
		stop("infozip and zlib not equal")
	}
})()
data.max <- data.max[engine != "infozip"]

xmin <- 21080
xmax <- 21100
ymin <- 21710000
ymax <- 21760000

p <- ggplot(data.max, aes(compressed_size, max_uncompressed_size, color=engine))
p <- p + geom_point()
p <- p + scale_x_continuous(limits=c(xmin, xmax), minor_breaks=NULL)
p <- p + scale_y_continuous(limits=c(ymin, ymax))
p <- p + scale_color_manual(values=c(bulk_deflate="black", zopfli="slateblue", zlib="dodgerblue"))
p <- p + labs(x="size of DEFLATE stream", y="maximum uncompressed size")
p <- p + theme_minimal()
p <- p + theme(legend.position="none")

# We need to figure out the aspect ratio of just the panel, in order to compute
# the rotation angle for the labels.
# https://stackoverflow.com/questions/16422847/save-plot-with-a-given-aspect-ratio
output.width <- 4
output.height <- 4
# Workaround to prevent ggplot_build from creating an empty Rplots.pdf file.
# https://github.com/tidyverse/ggplot2/issues/809
# https://github.com/tidyverse/ggplot2/issues/1042
pdf(file="/dev/null")
g <- ggplot_gtable(ggplot_build(p))
panel.width <- output.width - convertWidth(sum(g$widths), "in", valueOnly=TRUE)
panel.height <- output.height - convertWidth(sum(g$heights), "in", valueOnly=TRUE)

# The slope of the lines in data space is 1032/1.
angle <- atan2(1032*panel.height/(ymax-ymin), 1*panel.width/(xmax-xmin)) * (180/pi)
p <- p + annotate("text", x=21085, y=data.max[engine == "bulk_deflate" & compressed_size==21085]$max_uncompressed_size, label="bulk_deflate", angle=angle, hjust=0, vjust=-1)
p <- p + annotate("text", x=21085, y=data.max[engine == "zopfli" & compressed_size==21085]$max_uncompressed_size, label="zopfli", angle=angle, hjust=0, vjust=-1)
p <- p + annotate("text", x=21085, y=data.max[engine == "zlib" & compressed_size==21085]$max_uncompressed_size, label="zlib and Info-ZIP", angle=angle, hjust=0, vjust=-1)

ggsave(output_filename, p, width=4, height=4, dpi=300)
