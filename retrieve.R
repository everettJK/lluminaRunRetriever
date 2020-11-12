library(dplyr)
library(lubridate)

# write.table(read.csv('SampleSheet.csv.org'), sep = ',', file = 'SampleSheet.csv', quote = FALSE, row.names = FALSE, col.names = FALSE)

bs <- '~/ext/bs'

# Min. date of run to retrieve 
minDate <- ymd('200517')

# Output dir
outputDir <- './out'
if(! dir.exists('out')) dir.create('out')

# Obtain a list of runs already archived on the system.
d <- system("ssh microb120 ls /media/sequencing/Illumina", intern = TRUE)

write(date(), file = 'log')

r <- bind_rows(lapply(strsplit(system('~/ext/bs list runs', intern = TRUE), '\n'), function(x){
       s <- unlist(strsplit(x, '\\s*\\|\\s*'))
       if(length(s) >= 3){
         #if(grepl('200707_M03249_0073_000000000-G5JLD', x)) browser()
         if(nchar(s[2]) > 5 & nchar(s[3]) > 5 & nchar(s[5]) > 5){
           return(tibble(runName = s[2], runID = s[3], date = ymd(unlist(strsplit(s[2], '_'))[1]), 
                         include = date >=  minDate & s[5] %in% c('Analyzing', 'Complete', 'Needs Attention')))
         } else {
           return(tibble())
         } 
       } else {
         return(tibble())
       }
     }))

r <- r[! r$runName %in% d & r$include == TRUE,]

f <- invisible(lapply(1:nrow(r), function(x){
  x <- r[x,]
  write(paste0('Retrieving ... ', x$runName), file = 'log', append = TRUE)
  if(file.exists(file.path(outputDir, x$runName))){
    write(' run directory already exists, skipping.\n', file = 'log', append = TRUE)
    return(0)
  }
  system(paste0(bs, ' download run -q --id ', x$runID, ' -o ', file.path(outputDir, x$runName)))
  system(paste0('bcl2fastq --create-fastq-for-index-reads -R ', file.path(outputDir, x$runName), ' -o ',  file.path(outputDir, x$runName, 'Data/Intensities/BaseCalls')))
  if(file.exists(file.path(outputDir, x$runName, 'Data', 'Intensities', 'BaseCalls', 'Undetermined_S0_L001_R1_001.fastq.gz'))){
    write(' FASTQ created.\n', file = 'log', append = TRUE)
  } else {
    write(' FASTQ generation failed.\n', file = 'log', append = TRUE)
  }
 }))

