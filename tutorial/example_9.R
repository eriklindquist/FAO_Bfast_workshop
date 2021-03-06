# Example 9: ####
source("~/wur_bfast_workshop/R-scripts/tutorial_0.R")
source("~/wur_bfast_workshop/R-scripts/accuracy_assessment.R")
example_title <- 9
results_directory <- file.path(results_directory,paste0("example_",example_title))
dir.create(results_directory)
log_filename <- file.path(results_directory, paste0(format(Sys.time(), "%Y-%m-%d-%H-%M-%S"), "_example_", example_title, ".log"))
start_time <- format(Sys.time(), "%Y/%m/%d %H:%M:%S")

result <- file.path(results_directory, paste0("example_", example_title, ".grd"))
time <- system.time(bfmSpatial(ndmiStack, start = c(2010, 1),
                               formula = response ~ harmon,
                               order = 1, history = "all",
                               filename = result,
                               mc.cores = detectCores()))

write(paste0("This process started on ", start_time,
             " and ended on ",format(Sys.time(),"%Y/%m/%d %H:%M:%S"),
             " for a total time of ", time[[3]]/60," minutes"), log_filename, append=TRUE)

## Post-processing ####
bfm_ndvi <- brick(result)
#### Change
change <- raster(bfm_ndvi,1)
plot(change, col=rainbow(7),breaks=c(2010:2016))

#### Magnitude
magnitude <- raster(bfm_ndvi,2)
magn_bkp <- magnitude
magn_bkp[is.na(change)] <- NA
plot(magn_bkp,breaks=c(-5:5*1000),col=rainbow(length(c(-5:5*1000))))
plot(magnitude, breaks=c(-5:5*1000),col=rainbow(length(c(-5:5*1000))))

#### Error
error <- raster(bfm_ndvi,3)
plot(error)

#### Detect deforestation
def_ndvi <- magn_bkp
def_ndvi[def_ndvi>0]=NA
plot(def_ndvi)
plot(def_ndvi,col="black", main="NDVI_deforestation")
writeRaster(def_ndvi,filename = file.path(results_directory,paste0("example_",example_title,"_deforestation_magnitude.grd")),overwrite=TRUE)

def_years <- change
def_years[is.na(def_ndvi)]=NA

years <- c(2010,2011,2012,2013,2014,2015,2016,2017)
plot(def_years, col=rainbow(length(years)),breaks=years, main="Detecting deforestation after 2010")
writeRaster(def_ndvi,filename = file.path(results_directory,paste0("example_",example_title,"_deforestation_dates.grd")),overwrite=TRUE)

#### Accuracy Assessment
Forest_mask <- raster(file.path(workshop_folder,"data/Fmask_2010_Peru.tif"))
validation_forest_map <- raster(file.path(workshop_folder,"data/Validation_forest_2016.tif"))

sample_size <- calcSampleSize(def_years,Forest_mask,c(0.9,0.7),0.01)
samples <- extractRandomSamples(def_years,Forest_mask,sample_size,results_directory,"samples")
val_sample <- extractValidationValues(validation_forest_map, samples, Forest_mask)
conf_matrix <- assessAcuracy(samples,val_sample)
conf_matrix
