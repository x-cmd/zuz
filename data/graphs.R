library(data.table)
library(ggplot2)
library(grid)

column.width <- (7.0 - 0.33) / 2


## max_uncompressed_size.pdf

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
p <- p + theme(text=element_text(size=10, family="Times"), legend.position="none")

# We need to figure out the aspect ratio of just the panel, in order to compute
# the rotation angle for the labels.
# https://stackoverflow.com/questions/16422847/save-plot-with-a-given-aspect-ratio
output.width <- column.width
output.height <- 3
# Workaround to prevent ggplot_build from creating an empty Rplots.pdf file.
# https://github.com/tidyverse/ggplot2/issues/809
# https://github.com/tidyverse/ggplot2/issues/1042
cairo_pdf(filename="/dev/null")
g <- ggplot_gtable(ggplot_build(p))
panel.width <- output.width - convertWidth(sum(g$widths), "in", valueOnly=TRUE)
panel.height <- output.height - convertWidth(sum(g$heights), "in", valueOnly=TRUE)

# The slope of the lines in data space is 1032/1.
angle <- atan2(1032*panel.height/(ymax-ymin), 1*panel.width/(xmax-xmin)) * (180/pi)
p <- p + annotate("text", x=21085, y=data.max[engine == "bulk_deflate" & compressed_size==21085]$max_uncompressed_size, label="bulk_deflate", angle=angle, hjust=0, vjust=-0.6, family="Times")
p <- p + annotate("text", x=21085, y=data.max[engine == "zopfli" & compressed_size==21085]$max_uncompressed_size, label="Zopfli", angle=angle, hjust=0, vjust=-0.6, family="Times")
p <- p + annotate("text", x=21085, y=data.max[engine == "zlib" & compressed_size==21085]$max_uncompressed_size, label="zlib and Info-ZIP", angle=angle, hjust=0, vjust=-0.6, family="Times")

ggsave("max_uncompressed_size.pdf", p, width=output.width, height=output.height, device=cairo_pdf)


## zipped_size.pdf

data <- read.csv("zipped_size.csv")
data <- data.table(data)

byte_breaks <- 1000^(0:6)
byte_breaks_minor <- c(byte_breaks*10, byte_breaks*100)
byte_labels <- c("1 B", "1 kB", "1 MB", "1 GB", "1 TB", "1 PB", "1 EB")

xmin <- min(data$zipped_size, data$unzipped_size)
xmax <- 1000^3
ymin <- min(data$zipped_size, data$unzipped_size)
ymax <- 1000^6

data <- data[(class %in% c(
	"quoted_deflate",
	"quoted_deflate_zip64",
	"none_deflate_zip64",
	"none_bzip2_zip64",
	"42_nonrec",
	"42_rec"
))]

palette <- c(
	full_bzip2="pink",
	full_bzip2_zip64="pink",
	full_deflate="pink",
	full_deflate_zip64="pink",
	none_bzip2="pink",
	none_bzip2_zip64="tomato",
	none_deflate="pink",
	none_deflate_zip64="salmon",
	quoted_deflate="slateblue",
	quoted_deflate_zip64="dodgerblue",
	"42_nonrec"="red",
	"42_rec"="red"
)

p <- ggplot(data)
# p <- p + geom_hline(yintercept=281470681677825, size=0.5, linetype=2, color="gray")
p <- p + geom_abline(slope=1, intercept=0, size=0.2, linetype=3)
# p <- p + geom_point(data=data[class %in% c("42_nonrec", "42_rec")], aes(zipped_size, unzipped_size, color=class))
p <- p + geom_line(size=0.4, aes(zipped_size, unzipped_size, color=class))
p <- p + scale_color_manual(values=palette)
p <- p + scale_x_log10(breaks=byte_breaks, labels=byte_labels, minor_breaks=byte_breaks_minor)
p <- p + scale_y_log10(breaks=byte_breaks, labels=byte_labels, minor_breaks=byte_breaks_minor)
p <- p + coord_fixed(xlim=c(xmin, xmax), ylim=c(ymin, ymax))
p <- p + labs(x="zipped size", y="unzipped size")
p <- p + theme_minimal()
p <- p + theme(text=element_text(size=10, family="Times"), legend.position="none")

angle_label_at_sub <- function(at, x, y, angle, label, vjust) {
	i <- findInterval(at, x) + 1
	annotate("text", x=x[[i]], y=y[[i]], angle=angle, label=label, hjust=0, vjust=vjust, size=3, family="Times")
}

angle_label_at <- function(at, df, angle, label, vjust) {
	df <- df[order(df$zipped_size)]
	angle_label_at_sub(at, df$zipped_size, df$unzipped_size, angle, label, vjust)
}

p <- p + angle_label_at(10^6.5, data[class=="none_deflate_zip64"], label="DEFLATE", angle=45, -0.5)
p <- p + angle_label_at(4000, data[class=="none_bzip2_zip64"], label="bzip2", angle=45, -0.5)
p <- p + angle_label_at(2000, data[class=="quoted_deflate"], label="quoted DEFLATE", angle=atan2(2, 1)*180/pi, -0.5)
p <- p + angle_label_at(20000000, data[class=="quoted_deflate_zip64"], label="quoted DEFLATE (Zip64)", angle=atan2(2, 1)*180/pi, -0.5)

points <- data.frame(
	x=c(42374*10^1.5, 9893524*10^-1.5, 45876952*10^0.5, 42374*10^0.6, 42374),
	y=c(5461307620*10^-1.1, 281395456244934*10^-0.5, 4507981427706459/100, 558432*10^-0.6, 4507981343026016*10),
	xend=c(42374, 9893524, 45876952, 42374, 42374),
	yend=c(5461307620, 281395456244934, 4507981427706459, 558432, 4507981343026016),
	nudge_h=c(0.1, -0.1, 0.0, 0.1, 0.0),
	nudge_v=c(-0.05, -0.05, -0.1, -0.1, 0.12),
	label=c("zbsm.zip", "zblg.zip", "zbxl.zip", "42.zip (non-recursive)", "42.zip (recursive)"),
	class=c("quoted_deflate", "quoted_deflate", "quoted_deflate_zip64", "42_nonrec", "42_rec")
)
p <- p + geom_segment(data=points, aes(x=x, y=y, xend=xend, yend=yend), size=0.2, alpha=0.5, position=position_nudge(points$nudge_h, points$nudge_v), arrow=arrow(length=unit(0.2, "cm")))
p <- p + geom_point(data=points, aes(x=xend, y=yend, color=class), size=1)
p <- p + geom_text(data=points, aes(x=x, y=y, label=label), alpha=0.5, position=position_nudge(points$nudge_h, points$nudge_v), size=3, hjust=0.5*(1.0-sign(points$nudge_h)), vjust=0.5*(1.0-sign(points$nudge_v)), family="Times")

ggsave("zipped_size.pdf", p, width=column.width, height=6.5, device=cairo_pdf)
