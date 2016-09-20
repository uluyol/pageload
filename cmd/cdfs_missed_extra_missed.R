#!/usr/bin/env Rscript

library(scales)
library(ggplot2)
library(RColorBrewer)

args <- commandArgs(trailingOnly=TRUE)

output_pdf <- args[1]
xaxis.label <- args[2]
xaxis.breaks.str <- args[3]

xaxis.breaks <- waiver()
if (xaxis.breaks.str != '') {
	split <- strsplit(xaxis.breaks.str, ",")
	xaxis.breaks <- as.numeric(split[[1]])
}

data <- data.frame(Kind=c(), Value=c())
for (p in args[c(-1, -2, -3)]) {
	subdata <- read.csv(p, header=FALSE)
	colnames(subdata) <- c("Value")
	subdata$Kind <- rep.int(basename(p), length(subdata$Value))
	data <- rbind(data, subdata)
}

pdf(output_pdf, height=5, width=8)

# Below gives the warning
# Removed XXXX rows containing non-finite values (stat_ecdf).
# because we bound the data and ggplot produces infinite values
# outside of that range. Since this is safe, suppress it so we
# don't worry about it.
options(warn = -1)
	ggplot(data, aes(x=Value, color=Kind, linetype=Kind)) +
		stat_ecdf(size=1.1) +
		scale_x_continuous(breaks=xaxis.breaks, limits=c(NA, tail(xaxis.breaks, 1))) +
		xlab(xaxis.label) +
		ylab("CDF") +
		scale_color_brewer(palette="Dark2", breaks=c("online", "hybrid", "offline")) +
		scale_linetype_discrete(breaks=c("online", "hybrid", "offline")) +
		theme_bw() +
		theme(legend.title=element_blank())
options(warn = 0)

junk <- dev.off()
