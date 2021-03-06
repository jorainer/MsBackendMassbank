
#' @include hidden_aliases.R
NULL

#' @title MS data backend for mgf files
#'
#' @aliases MsBackendMassbank-class
#'
#' @description
#'
#' The `MsBackendMassbank` class supports import of MS/MS spectra data from
#' MS/MS spectrum data from [Massbank](https://github.com/MassBank/MassBank-data)
#' files. After initial import, the full MS data is kept in
#' memory. `MsBackendMassbank` extends the [MsBackendDataFrame()] backend
#' directly and supports thus the [applyProcessing()] function to make
#' data manipulations persistent. The backend does however not
#' support export to mgf files yet.
#'
#' New objects are created with the `MsBackendMassbank` function. The
#' `backendInitialize` method has to be subsequently called to
#' initialize the object and import MS/MS data from (one or more) mgf
#' files.  Optional parameter `nonStop` allows to specify whether the
#' import returns with an error if one of the xml files lacks required
#' data, such as `mz` and `intensity` values (default `nonStop =
#' FALSE`), or whether only affected file(s) is(are) skipped and a
#' warning is shown (`nonStop = TRUE`). Note that any other error
#' (such as xml import error) will abort import regardless of
#' parameter `nonStop`.
#'
#' @param object Instance of `MsBackendMassbank` class.
#'
#' @param file for `export`: `character(1)` defining the output file.
#'
#' @param files `character` with the (full) file name(s) of the mgf file(s)
#'     from which MS/MS data should be imported.
#'
#' @param format for `spectraVariableMapping`: `character(1)` defining the
#'     format to be used. Currently only `format = "Massbank"` is supported.
#'
#' @param mapping for `export`: named `character` vector
#'     allowing to specify how fields from the Massbank file should be renamed.
#'     Names are supposed to be the spectra variable name and values of the
#'     vector the field names in the Massbank file. See output of
#'     `spectraVariableMapping()` for the expected format.
#'
#' @param metaBlocks `data.frame` data frame indicating which metadata shall
#'     be read Default is [metaDataBlocks()].
#'
#' @param nonStop `logical(1)` whether import should be stopped if an
#'     xml file does not contain all required fields. Defaults to
#'     `nonStop = FALSE`.
#'
#' @param BPPARAM Parameter object defining the parallel processing
#'     setup to import data in parallel. Defaults to `BPPARAM =
#'     bpparam()`. See [bpparam()] for more information.
#'
#' @param x [Spectra()] object that should be exported.
#'
#' @param ... Currently ignored.
#'
#' @author Michael Witting
#'
#' @importClassesFrom Spectra MsBackendDataFrame
#'
#' @exportClass MsBackendMassbank
#'
#' @name MsBackendMassbank
#'
#' @examples
#'
#' ## Create an MsBackendMassbank backend and import data from test xml files.
#' fls <- dir(system.file("extdata", package = "MsBackendMassbank"),
#'     full.names = TRUE, pattern = "txt$")
#' be <- backendInitialize(MsBackendMassbank(), fls)
#' be
#'
#' be$msLevel
#' be$intensity
#' be$mz
NULL

setClass("MsBackendMassbank",
         contains = "MsBackendDataFrame",
         prototype = prototype(spectraData = DataFrame(),
                               readonly = FALSE,
                               version = "0.1"))

#' @importMethodsFrom Spectra backendInitialize spectraData<- $<- $
#'
#' @importFrom BiocParallel bpparam
#'
#' @importMethodsFrom BiocParallel bplapply
#'
#' @importFrom methods validObject
#'
#' @exportMethod backendInitialize
#'
#' @rdname MsBackendMassbank
setMethod("backendInitialize", signature = "MsBackendMassbank",
          function(object, files, metaBlocks = metaDataBlocks(),
                   nonStop = FALSE, ..., BPPARAM = bpparam()) {

            if (missing(files) || !length(files)) {

              stop("Parameter 'files' is mandatory for ", class(object))

            }

            if (!is.character(files)) {

              stop("Parameter 'files' is expected to be a character vector",
                   " with the files names from where data should be",
                   " imported")

            }

            files <- normalizePath(files)

            if (any(!file.exists(files))) {

              stop("file(s) ",
                   paste(files[!file.exists(files)], collapse = ", "),
                   " not found")

            }

            ## Import data and rbind.
            message("Start data import from ", length(files), " files ... ",
                    appendLF = FALSE)

            res <- bplapply(files, FUN = .read_massbank, metaBlocks = metaBlocks,
                            nonStop = nonStop, BPPARAM = BPPARAM)

            message("done")

            res <- do.call(rbind, res)

            if (nonStop && length(files) > nrow(res)) {

              warning("Import failed for ", length(files) - nrow(res),
                      " files")

            }

            spectraData(object) <- res
            object$dataStorage <- "<memory>"
            #object$centroided <- TRUE
            validObject(object)

            object

          })

#' @rdname MsBackendMassbank
#'
#' @importFrom methods new
#'
#' @export MsBackendMassbank
MsBackendMassbank <- function() {
  new("MsBackendMassbank")
}

#' @export
#'
#' @rdname MsBackendMassbank
spectraVariableMapping <- function(format = c("Massbank")) {
  ## In future eventually define that in a text file and import upon package
  ## init.
  switch(match.arg(format),
         "Massbank" = c(
           # minimal information
           accession = "ACCESSION:",
           name = "CH$NAME:",
           smiles = "CH$SMILES:",
           exactmass = "CH$EXACT_MASS:",
           formula = "CH$FORMULA:",
           inchi = "CH$IUPAC:",
           cas = "CH$LINK: CAS",
           inchikey = "CH$LINK: INCHIKEY",
           collisionEnergy = "AC$MASS_SPECTROMETRY: COLLISION_ENERGY",
           precursorMz = "MS$FOCUSED_ION: PRECURSOR_M/Z",
           precursorIntensity = "MS$FOCUSED_ION: PRECURSOR_INT",
           adduct = "MS$FOCUSED_ION: PRECURSOR_TYPE",
           rtime = "AC$CHROMATOGRAPHY: RETENTION_TIME",
           polarity = "AC$MASS_SPECTROMETRY: ION_MODE",
           splash = "PK$SPLASH:",
           title = "RECORD_TITLE:",

           # instrument information
           instrument = "AC$INSTRUMENT:",
           instrument_type = "AC$INSTRUMENT_TYPE:",

           # ms information
           ms_ms_type = "AC$MASS_SPECTROMETRY: MS_TYPE",
           ms_cap_voltage = "AC$MASS_SPECTROMETRY: CAPILLARY_VOLTAGE",
           ms_col_gas = "AC$MASS_SPECTROMETRY: COLLISION_GAS",
           ms_desolv_gas_flow = "AC$MASS_SPECTROMETRY: DESOLVATION_GAS_FLOW",
           ms_desolv_temp = "AC$MASS_SPECTROMETRY: DESOLVATION_TEMPERATURE",
           ms_ionization = "AC$MASS_SPECTROMETRY: IONIZATION",
           ms_ionization_energy = "AC$MASS_SPECTROMETRY: IONIZATION_ENERGY",
           ms_laser = "AC$MASS_SPECTROMETRY: LASER",
           ms_matrix = "AC$MASS_SPECTROMETRY: MATRIX",
           ms_mass_accuracy = "AC$MASS_SPECTROMETRY: MASS_ACCURACY",
           ms_mass_range = "AC$MASS_SPECTROMETRY: MASS_RANGE_MZ",
           ms_reagent_gas = "AC$MASS_SPECTROMETRY: REAGENT_GAS",
           ms_resolution = "AC$MASS_SPECTROMETRY: RESOLUTION",
           ms_scan_setting = "AC$MASS_SPECTROMETRY: SCANNING_SETTING",
           ms_source_temp = "AC$MASS_SPECTROMETRY: SOURCE_TEMPERATURE",
           ms_frag_mode = "AC$MASS_SPECTROMETRY: FRAGMENTATION_MODE",

           # ms information part II
           focus_base_peak = "MS$FOCUSED_ION: BASE_PEAK",
           focus_derivative_form = "MS$FOCUSED_ION: DERIVATIVE_FORM",
           focus_derivative_mass = "MS$FOCUSED_ION: DERIVATIVE_MASS",
           focus_derivative_type = "MS$FOCUSED_ION: DERIVATIVE_TYPE",
           focus_ion_type = "MS$FOCUSED_ION: ION_TYPE",

           # data processing information
           data_processing_comment = "MS$DATA_PROCESSING: COMMENT",
           data_processing_deprofile = "MS$DATA_PROCESSING: DEPROFILE",
           data_processing_find = "MS$DATA_PROCESSING: FIND_PEAK",
           data_processing_reanalyze = "MS$DATA_PROCESSING: REANALYZE",
           data_processing_recalibrate = "MS$DATA_PROCESSING: RECALIBRATE",
           data_processing_whole = "MS$DATA_PROCESSING: WHOLE",

           # chromatography information
           chrom_carrier_gas = "AC$CHROMATOGRAPHY: CARRIER_GAS",
           chrom_column = "AC$CHROMATOGRAPHY: COLUMN_NAME",
           chrom_column_temp = "AC$CHROMATOGRAPHY: COLUMN_TEMPERATURE",
           chrom_column_temp_gradient = "AC$CHROMATOGRAPHY: COLUMN_TEMPERATURE_GRADIENT",
           chrom_flow_gradient = "AC$CHROMATOGRAPHY: FLOW_GRADIENT",
           chrom_flow_rate = "AC$CHROMATOGRAPHY: FLOW_RATE",
           chrom_inj_temp = "AC$CHROMATOGRAPHY: INJECTION_TEMPERATURE",
           chrom_inj_temp_gradient = "AC$CHROMATOGRAPHY: INJECTION_TEMPERATURE_GRADIENT",
           chrom_rti_kovats = "AC$CHROMATOGRAPHY: KOVATS_RTI",
           chrom_rti_lee = "AC$CHROMATOGRAPHY: LEE_RTI",
           chrom_rti_naps = "AC$CHROMATOGRAPHY: NAPS_RTI",
           chrom_rti_uoa = "AC$CHROMATOGRAPHY: UOA_RTI",
           chrom_rti_uoa_pred = "AC$CHROMATOGRAPHY: UOA_PREDICTED_RTI",
           chrom_rt = "AC$CHROMATOGRAPHY: RETENTION_TIME",
           chrom_solvent = "AC$CHROMATOGRAPHY: SOLVENT",
           chrom_transfer_temp = "AC$CHROMATOGRAPHY: TRANSFERLINE_TEMPERATURE",

           # chemical information
           compound_class = "CH$COMPOUND_CLASS:",
           link_cayman = "CH$LINK: CAYMAN",
           link_chebi = "CH$LINK: CHEBI",
           link_chembl = "CH$LINK: CHEMBL",
           link_chempdb = "CH$LINK: CHEMPDB",
           link_chemspider = "CH$LINK: CHEMSPIDER",
           link_comptox = "CH$LINK: COMPTOX",
           link_hmdb = "CH$LINK: HMDB",
           link_kappaview = "CH$LINK: KAPPAVIEW",
           link_kegg = "CH$LINK: KEGG",
           link_knapsack = "CH$LINK: KNAPSACK",
           link_lipidbank = "CH$LINK: LIPIDBANK",
           link_lipidmaps = "CH$LINK: LIPIDMAPS",
           link_nikkaji = "CH$LINK: NIKKAJI",
           link_pubchem = "CH$LINK: PUBCHEM",
           link_zinc = "CH$LINK: ZINC",

           # sample information
           scientific_name = "SP$SCIENTIFIC_NAME:",
           lineage = "SP$LINEAGE:",
           link = "SP$LINK:",
           sample = "SP$SAMPLE:",

           # record information
           deprecated = "DEPRECATED:",
           date = "DATE:",
           authors = "AUTHORS:",
           license = "LICENSE:",
           copyright = "COPYRIGHT:",
           publication = "PUBLICATION:",
           project = "PROJECT:",

           # peak information
           pknum = "PK$NUM_PEAK:"
         )
  )
}

#' @importMethodsFrom Spectra export
#'
#' @exportMethod export
#'
#' @rdname MsBackendMassbank
setMethod("export", "MsBackendMassbank", function(object, x, file = tempfile(),
                                                  mapping = spectraVariableMapping(),
                                             ...) {
  .export_massbank(x = x, con = file, mapping = mapping)
})
