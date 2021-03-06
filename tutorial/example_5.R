# Example 5: ####
source("~/wur_bfast_workshop/R-scripts/tutorial_0.R")
source("~/wur_bfast_workshop/R-scripts/accuracy_assessment.R")
example_title <- 5
results_directory <- file.path(results_directory,paste0("example_",example_title))
dir.create(results_directory)
log_filename <- file.path(results_directory, paste0(format(Sys.time(), "%Y-%m-%d-%H-%M-%S"), "_example_", example_title, ".log"))
start_time <- format(Sys.time(), "%Y/%m/%d %H:%M:%S")

result <- file.path(results_directory, paste0("example_", example_title, ".grd"))
bfmSpatialSq <- function(start, end, timeStack, outdir, ...){
  bfm_seq <- lapply(start:end,
                    function(year){
                      outfl <- paste0(outdir, "/bfm_NDMI_", year, ".grd")
                      bfm_year <- bfmSpatial(timeStack, start = c(year, 1), monend = c(year + 1, 1),
                                             formula = response~harmon,
                                             order = 1, history = "all", filename = outfl, ...)
                      outfl
                    })
}
time <- system.time(bfmSpatialSq(2010,2016,ndmiStack,results_directory, mc.cores = detectCores()))

calcDefSeqYears2 <- function(outdir,outfile,start,end,parameter_value){
  bfast_result_fnames <- list.files(outdir, pattern=glob2rx('*.grd'), full.names=TRUE)
  yearly_def <- lapply(bfast_result_fnames,function(file_name){
    bfm_year <- brick(file_name)
    bfm_year[[1]][bfm_year[[2]]>0] <- NA
    bfm_year[[2]][is.na(bfm_year[[1]])] <- NA
    bfm_year
  })
  bfm_summary <- yearly_def[[length(yearly_def)]]
  for (i in (length(yearly_def)-1):1) {
    bfm_summary[!is.na(yearly_def[[i]][[1]])] <- yearly_def[[i]][!is.na(yearly_def[[i]][[1]])]
  }
  writeRaster(bfm_summary,file.path(outfile))
}

def_years_2005 <- calcDefSeqYears2(results_directory,result,2010,2016,2005)

write(paste0("This process started on ", start_time,
             " and ended on ",format(Sys.time(),"%Y/%m/%d %H:%M:%S"),
             " for a total time of ", time[[3]]/60," minutes"), log_filename, append=TRUE)

## Post-processing ####
bfm_ndmi <- brick(result)
#### Change
change <- raster(bfm_ndmi,1)
plot(change, col=rainbow(7),breaks=c(2010:2016))

#### Magnitude
magnitude <- raster(bfm_ndmi,2)
magn_bkp <- magnitude
magn_bkp[is.na(change)] <- NA
plot(magn_bkp,breaks=c(-5:5*1000),col=rainbow(length(c(-5:5*1000))))
plot(magnitude, breaks=c(-5:5*1000),col=rainbow(length(c(-5:5*1000))))

#### Error
error <- raster(bfm_ndmi,3)
plot(error)

#### Detect deforestation
def_ndmi <- magn_bkp
def_ndmi[def_ndmi>0]=NA
plot(def_ndmi)
plot(def_ndmi,col="black", main="NDMI_deforestation")
writeRaster(def_ndmi,filename = file.path(results_directory,paste0("example_",example_title,"_deforestation_magnitude.grd")),overwrite=TRUE)

def_years <- change
def_years[is.na(def_ndmi)]=NA

years <- c(2010,2011,2012,2013,2014,2015,2016,2017)
plot(def_years, col=rainbow(length(years)),breaks=years, main="Detecting deforestation after 2010")
writeRaster(def_ndmi,filename = file.path(results_directory,paste0("example_",example_title,"_deforestation_dates.grd")),overwrite=TRUE)

#### Accuracy Assessment
Forest_mask <- raster(file.path(workshop_folder,"data/Fmask_2010_Peru.tif"))
validation_forest_map <- raster(file.path(workshop_folder,"data/Validation_forest_2016.tif"))

sample_size <- calcSampleSize(def_years,Forest_mask,c(0.9,0.7),0.01)
samples <- extractRandomSamples(def_years,Forest_mask,sample_size,results_directory,"samples")
val_sample <- extractValidationValues(validation_forest_map, samples, Forest_mask)
conf_matrix <- assessAcuracy(samples,val_sample)
conf_matrix
