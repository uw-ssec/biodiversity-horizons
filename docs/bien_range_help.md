---
editor_options: 
  markdown: 
    wrap: 72
---

# Guide to using the BIEN Ranges

The BIEN Ranges dataset is are a set of ranges for around 300,000 plant
species. Cory Merow produced the ranges as part of the [Botanical
Information and Ecology Network](https://bien.nceas.ucsb.edu/bien/)

The ranges are represented with tif files. Each species is associated
with 10 tif files—a present-day range plus three future scenarios, each
with three time steps. However, `point` ranges (see below) do not have
future ranges.

Cory produced the ranges using an approach that differs by the number of
available presences. Species with many presences use a maxent/point
process approach (`mod_type=ppm`). Those with more limited presences use
range bagging (`mod_type=rangebag`). Species that have very limited
presences (e.g., \< 5) can't be modeled and instead use just the presence
points (`mod_type=point`).

### Range archives

I have organized the ranges so they can easily be searched and loaded.
Inside the main folder containing the ranges (e.g, oct18_10k; see
below), there are two folders: `manifest` and `tifs`. the `manifest`
folder contains one or more parquet files that act as an index to the
files. The files are stored in the tifs folder, under folders
corresponding to the timestep, scenario, and modeling method. For
example, the species *Aa mathewsii* for scenario ssp1.26 and at year
2011 is stored in `tifs/2611/ppm`.

#### Manifest

You can use the manifest to select and load subsets of the rasters using
any package that can query parquet files. The manifest has the following
fields.

| Field | Description |
|----|----|
| spp | The species name. e.g. *Aa mathewsii* |
| rcp | The rcp scenario. Can be 26, 70, 85 |
| year | Can be 2011, 2041, 2071 |
| scenario | A combination of rcp and year. e.g. 2611 is rcp 26 in 2011. |
| mod_type | The approach used to create the range. Can be ppm, rangebag, points |
| path | The path to the tif, relative to the `tifs` folder |

For example, here is code to load all future rasters for a given species
into a list column.

``` r
    manf <- open_dataset(file.path(.rangesP,'manifest'))
    
    futRngs <- manf %>%
      filter(spp==.x & scenario != 'present') %>%
      collect %>%
      mutate(rast=map(path,~rast(file.path(rangesTfs,.x)))) %>%
      select(-c(spp,path)) %>%
      arrange(rcp,year)
```

## Formatting the ranges

Species ranges are often stored as binary rasters, where 1 represents
presence (or, more accurately, suspected presence or even merely suitable
habitat), and 0 or NA represents absence (or unsuitable habitat).

As distributed, the BIEN ranges have a lot of extra information,
so they need to be converted into binary rasters before downstream
processing. The presence and future ranges are stored in different
formats.

### Presence ranges

You can convert the presence rasters into binary form using the
following code.

``` r
    pres <- rast(mypath) - 4
    pres <- ifel(pres >=2,1,NaN)
    names(pres) <- 'present'
```

### Future ranges

Here is how to convert future ranges to binary format

``` r
    binRange <- function(rng,full_domain=FALSE) {
    
      rng1 <- rng[[2]]
      if(full_domain) {
        rng1 <- abs(rng1)
      }
      rng1 <- ifel(rng1 >= 3,1,NaN)
      
      return(rng1)
    }
    
    futRngs <- futRngs %>%
      rowwise %>%
      mutate(rast=list({

        rng <- binRange(rast
        names(rng) <- glue('rcp{rcp}_{year}') #layer name
        
        rng # Note, can't do return here, this is an anonymous block not a function
      })) %>%
      ungroup # remove rowwise mode
```

You can then create a raster stack in terra like this

``` r
        rngs <- rast(fut$rast)
        
        # add present day to the stack and trim
        rngs <- trim(c(pres,rngs))
```

## oct18_10k range archive

This is a range archive of 10k species, all of which were modeled using
the ppm approach. The data set is creatively called Oct 18 because that
is the day Cory released it.
